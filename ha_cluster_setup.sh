#!/usr/bin/env bash
#
# HArmadillium HA Bootstrap Script
# --------------------------------
# Purpose:
#   Educational / sandbox bootstrap for a single node that prepares packages and
#   baseline services commonly used in High Availability environments.
#
# What this script DOES:
#   - Installs Corosync, Pacemaker, PCS, UFW, HAProxy, Fail2Ban, Nginx, Apache2
#   - Writes a netplan static-IP config (optionally applies it)
#   - Configures baseline firewall rules
#   - Generates self-signed SSL certificates for Nginx and Apache2
#   - Configures simple Nginx and Apache HTTPS listeners
#   - Enables core supporting services
#
# What this script DOES NOT do:
#   - Build a complete HA cluster
#   - Generate corosync.conf
#   - Authenticate cluster nodes with pcs
#   - Configure quorum, STONITH/fencing, or cluster resources
#   - Safely migrate all existing network/firewall layouts for every environment
#
# Safe-by-default behavior:
#   - Does NOT run apt upgrade unless RUN_APT_UPGRADE=yes
#   - Does NOT apply netplan unless APPLY_NETWORK=yes
#   - Does NOT reset UFW unless RESET_FIREWALL=yes
#
# Optional environment variables:
#   STATIC_IP=192.168.1.100
#   SUBNET_MASK=255.255.255.0
#   GATEWAY=192.168.1.1
#   DNS_SERVERS=1.1.1.1,8.8.8.8
#   APPLY_NETWORK=yes
#   RESET_FIREWALL=yes
#   RUN_APT_UPGRADE=yes
#   SKIP_APACHE=no
#   SKIP_NGINX=no
#   SKIP_HAPROXY=no
#   SKIP_FAIL2BAN=no
#
# Example:
#   sudo STATIC_IP=192.168.1.100 \
#        SUBNET_MASK=255.255.255.0 \
#        GATEWAY=192.168.1.1 \
#        DNS_SERVERS=1.1.1.1,8.8.8.8 \
#        APPLY_NETWORK=no \
#        ./ha_cluster_setup.sh
#
# License: MIT

set -euo pipefail

SCRIPT_NAME="$(basename "$0")"
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
TIMESTAMP="$(date +%Y%m%d-%H%M%S)"

NETPLAN_FILE="/etc/netplan/99-harmadillium.yaml"
NGINX_SSL_DIR="/etc/nginx/ssl"
APACHE_SSL_DIR="/etc/apache2/ssl"
SSL_CONFIG_PATH="$SCRIPT_DIR/ssl/distinguished.cnf"

RUN_APT_UPGRADE="${RUN_APT_UPGRADE:-no}"
APPLY_NETWORK="${APPLY_NETWORK:-no}"
RESET_FIREWALL="${RESET_FIREWALL:-no}"
SKIP_APACHE="${SKIP_APACHE:-no}"
SKIP_NGINX="${SKIP_NGINX:-no}"
SKIP_HAPROXY="${SKIP_HAPROXY:-no}"
SKIP_FAIL2BAN="${SKIP_FAIL2BAN:-no}"

STATIC_IP="${STATIC_IP:-}"
SUBNET_MASK="${SUBNET_MASK:-}"
GATEWAY="${GATEWAY:-}"
DNS_SERVERS="${DNS_SERVERS:-}"

CHANGES=()
WARNINGS=()

log()   { echo "[INFO] $*"; }
warn()  { echo "[WARN] $*" >&2; WARNINGS+=("$*"); }
error() { echo "[ERROR] $*" >&2; exit 1; }

record_change() {
    CHANGES+=("$*")
}

command_exists() {
    command -v "$1" >/dev/null 2>&1
}

backup_file_if_exists() {
    local file="$1"
    if [[ -f "$file" ]]; then
        local backup="${file}.bak.${TIMESTAMP}"
        cp -a "$file" "$backup"
        log "Backed up $file -> $backup"
        record_change "Backup created: $backup"
    fi
}

require_root() {
    [[ "${EUID}" -eq 0 ]] || error "Please run this script as root."
}

require_commands() {
    local required=(ip awk sed grep openssl systemctl apt)
    for cmd in "${required[@]}"; do
        command_exists "$cmd" || error "Required command not found: $cmd"
    done
}

is_yes() {
    [[ "${1,,}" == "yes" || "${1,,}" == "true" || "${1}" == "1" ]]
}

valid_ipv4() {
    local ip="$1"
    [[ "$ip" =~ ^([0-9]{1,3}\.){3}[0-9]{1,3}$ ]] || return 1

    IFS='.' read -r o1 o2 o3 o4 <<< "$ip"
    for octet in "$o1" "$o2" "$o3" "$o4"; do
        [[ "$octet" -ge 0 && "$octet" -le 255 ]] || return 1
    done
    return 0
}

validate_dns_servers() {
    local dns="$1"
    local item
    IFS=',' read -ra dns_items <<< "$dns"
    [[ "${#dns_items[@]}" -gt 0 ]] || return 1
    for item in "${dns_items[@]}"; do
        item="$(echo "$item" | xargs)"
        valid_ipv4 "$item" || return 1
    done
    return 0
}

netmask_to_cidr() {
    local mask="$1"
    local IFS=.
    local -a octets=($mask)
    local cidr=0

    [[ "${#octets[@]}" -eq 4 ]] || return 1

    for octet in "${octets[@]}"; do
        case "$octet" in
            255) ((cidr+=8)) ;;
            254) ((cidr+=7)) ;;
            252) ((cidr+=6)) ;;
            248) ((cidr+=5)) ;;
            240) ((cidr+=4)) ;;
            224) ((cidr+=3)) ;;
            192) ((cidr+=2)) ;;
            128) ((cidr+=1)) ;;
            0) ;;
            *) return 1 ;;
        esac
    done
    echo "$cidr"
}

detect_default_interface() {
    ip -o -4 route show to default | awk '{print $5}' | head -n1
}

detect_current_ipv4() {
    local iface="$1"
    ip -o -4 addr show dev "$iface" | awk '{print $4}' | cut -d/ -f1 | head -n1
}

detect_default_gateway() {
    ip route | awk '/default/ {print $3; exit}'
}

detect_dns_servers() {
    awk '/^nameserver/ {print $2}' /etc/resolv.conf | paste -sd, -
}

detect_prefix_from_interface() {
    local iface="$1"
    ip -o -4 addr show dev "$iface" | awk '{print $4}' | cut -d/ -f2 | head -n1
}

cidr_to_netmask() {
    local cidr="$1"
    local mask=""
    local full_octets=$((cidr / 8))
    local partial_octet=$((cidr % 8))
    local i val

    for ((i=0; i<4; i++)); do
        if (( i < full_octets )); then
            val=255
        elif (( i == full_octets && partial_octet > 0 )); then
            val=$((256 - 2**(8 - partial_octet)))
        else
            val=0
        fi
        mask+="${val}"
        [[ $i -lt 3 ]] && mask+="."
    done
    echo "$mask"
}

detect_wireless_interface() {
    local iface="$1"
    [[ -d "/sys/class/net/$iface/wireless" ]]
}

validate_network_inputs() {
    [[ -n "$STATIC_IP" ]] || error "STATIC_IP must be set or auto-detected."
    [[ -n "$SUBNET_MASK" ]] || error "SUBNET_MASK must be set or derived."
    [[ -n "$GATEWAY" ]] || error "GATEWAY must be set or auto-detected."
    [[ -n "$DNS_SERVERS" ]] || error "DNS_SERVERS must be set or auto-detected."

    valid_ipv4 "$STATIC_IP" || error "STATIC_IP is invalid: $STATIC_IP"
    valid_ipv4 "$SUBNET_MASK" || error "SUBNET_MASK is invalid: $SUBNET_MASK"
    valid_ipv4 "$GATEWAY" || error "GATEWAY is invalid: $GATEWAY"
    validate_dns_servers "$DNS_SERVERS" || error "DNS_SERVERS must be a comma-separated list of valid IPv4 addresses."

    CIDR="$(netmask_to_cidr "$SUBNET_MASK")" || error "SUBNET_MASK is not convertible to CIDR: $SUBNET_MASK"
}

auto_detect_missing_network_values() {
    NETIF="$(detect_default_interface)"
    [[ -n "$NETIF" ]] || error "Could not detect active network interface."

    if [[ -z "$STATIC_IP" ]]; then
        STATIC_IP="$(detect_current_ipv4 "$NETIF")"
        [[ -n "$STATIC_IP" ]] || error "Could not auto-detect STATIC_IP."
    fi

    if [[ -z "$GATEWAY" ]]; then
        GATEWAY="$(detect_default_gateway)"
        [[ -n "$GATEWAY" ]] || error "Could not auto-detect GATEWAY."
    fi

    if [[ -z "$DNS_SERVERS" ]]; then
        DNS_SERVERS="$(detect_dns_servers)"
        [[ -n "$DNS_SERVERS" ]] || warn "Could not auto-detect DNS_SERVERS from /etc/resolv.conf."
    fi

    if [[ -z "$SUBNET_MASK" ]]; then
        local prefix
        prefix="$(detect_prefix_from_interface "$NETIF")"
        [[ -n "$prefix" ]] || error "Could not auto-detect subnet prefix."
        SUBNET_MASK="$(cidr_to_netmask "$prefix")"
    fi

    record_change "Detected interface: $NETIF"
}

install_packages() {
    log "Updating package indexes..."
    apt update
    record_change "Ran apt update"

    if is_yes "$RUN_APT_UPGRADE"; then
        log "Running full package upgrade because RUN_APT_UPGRADE=yes..."
        DEBIAN_FRONTEND=noninteractive apt upgrade -y
        record_change "Ran apt upgrade -y"
    else
        warn "Skipping apt upgrade. Set RUN_APT_UPGRADE=yes to enable."
    fi

    local packages=(
        corosync
        pacemaker
        pcs
        ufw
        haproxy
        fail2ban
        nginx
        apache2
        openssl
    )

    log "Installing required packages..."
    DEBIAN_FRONTEND=noninteractive apt install -y "${packages[@]}"
    record_change "Installed packages: ${packages[*]}"
}

write_netplan_config() {
    command_exists netplan || error "netplan is not installed or not available."

    if detect_wireless_interface "$NETIF"; then
        warn "Detected wireless interface: $NETIF"
        warn "Automatic static netplan generation for Wi-Fi may be unsafe without access-point credentials."
        warn "Skipping netplan write for wireless interface."
        return 0
    fi

    backup_file_if_exists "$NETPLAN_FILE"

    local dns_list="${DNS_SERVERS//,/\, }"

    cat > "$NETPLAN_FILE" <<EOF
network:
  version: 2
  ethernets:
    $NETIF:
      dhcp4: false
      addresses:
        - $STATIC_IP/$CIDR
      routes:
        - to: default
          via: $GATEWAY
      nameservers:
        addresses: [$dns_list]
EOF

    chmod 600 "$NETPLAN_FILE"
    record_change "Wrote netplan config: $NETPLAN_FILE"

    if netplan generate; then
        log "netplan generate succeeded."
    else
        error "netplan generate failed. Review $NETPLAN_FILE before continuing."
    fi

    if is_yes "$APPLY_NETWORK"; then
        log "Applying network changes because APPLY_NETWORK=yes..."
        if netplan apply; then
            record_change "Applied network config with netplan apply"
        else
            error "netplan apply failed."
        fi
    else
        warn "Network config was written but not applied. Set APPLY_NETWORK=yes to apply it."
    fi
}

configure_ufw() {
    command_exists ufw || error "ufw not found."

    if is_yes "$RESET_FIREWALL"; then
        log "Resetting firewall because RESET_FIREWALL=yes..."
        ufw --force reset
        record_change "Reset UFW rules"
    else
        warn "Preserving existing UFW rules. Set RESET_FIREWALL=yes to reset firewall."
    fi

    local rules=(
        "OpenSSH"
        "80/tcp"
        "443/tcp"
        "8080/tcp"
        "4433/tcp"
        "2224/tcp"
        "3121/tcp"
        "5404/udp"
        "5405/udp"
    )

    for rule in "${rules[@]}"; do
        ufw allow "$rule" >/dev/null || true
    done

    ufw --force enable
    record_change "Enabled UFW and ensured baseline rules"
}

ensure_ssl_config() {
    mkdir -p "$(dirname "$SSL_CONFIG_PATH")"

    if [[ ! -f "$SSL_CONFIG_PATH" ]]; then
        warn "SSL config not found. Creating fallback OpenSSL config with SAN support."
        cat > "$SSL_CONFIG_PATH" <<EOF
[req]
default_bits = 2048
prompt = no
default_md = sha256
x509_extensions = v3_req
distinguished_name = req_distinguished_name

[req_distinguished_name]
C = XZ
O = HArmadillium Educational Sandbox Node
CN = $STATIC_IP

[v3_req]
subjectAltName = @alt_names

[alt_names]
IP.1 = $STATIC_IP
DNS.1 = $(hostname -f 2>/dev/null || hostname)
DNS.2 = $(hostname)
EOF
        record_change "Created fallback SSL config: $SSL_CONFIG_PATH"
    fi
}

generate_ssl_certificates() {
    ensure_ssl_config

    mkdir -p "$NGINX_SSL_DIR" "$APACHE_SSL_DIR"

    openssl req -x509 -nodes -days 365 -newkey rsa:2048 \
        -keyout "$NGINX_SSL_DIR/host.key" \
        -out "$NGINX_SSL_DIR/host.cert" \
        -config "$SSL_CONFIG_PATH"

    openssl req -x509 -nodes -days 365 -newkey rsa:2048 \
        -keyout "$APACHE_SSL_DIR/host.key" \
        -out "$APACHE_SSL_DIR/host.cert" \
        -config "$SSL_CONFIG_PATH"

    chmod 600 "$NGINX_SSL_DIR/host.key" "$APACHE_SSL_DIR/host.key"
    record_change "Generated self-signed SSL certificates for Nginx and Apache"
}

configure_nginx() {
    if is_yes "$SKIP_NGINX"; then
        warn "Skipping Nginx configuration."
        return 0
    fi

    backup_file_if_exists "/etc/nginx/sites-enabled/default"

    rm -f /etc/nginx/sites-enabled/default
    cat > /etc/nginx/sites-enabled/default <<EOF
server {
    listen 80;
    server_name $STATIC_IP;

    return 301 https://\$host\$request_uri;
}

server {
    listen 443 ssl;
    server_name $STATIC_IP;

    ssl_certificate /etc/nginx/ssl/host.cert;
    ssl_certificate_key /etc/nginx/ssl/host.key;

    location / {
        root /var/www/html;
        index index.html;
    }
}
EOF

    systemctl enable nginx
    systemctl restart nginx
    record_change "Configured and restarted Nginx"
}

configure_apache() {
    if is_yes "$SKIP_APACHE"; then
        warn "Skipping Apache2 configuration."
        return 0
    fi

    backup_file_if_exists "/etc/apache2/ports.conf"
    backup_file_if_exists "/etc/apache2/sites-enabled/000-default.conf"

    a2enmod ssl >/dev/null 2>&1 || true

    cat > /etc/apache2/ports.conf <<EOF
Listen 8080
Listen 4433
EOF

    cat > /etc/apache2/sites-enabled/000-default.conf <<EOF
<VirtualHost *:8080>
    Redirect permanent / https://$STATIC_IP:4433/
</VirtualHost>

<VirtualHost $STATIC_IP:4433>
    SSLEngine on
    SSLCertificateFile /etc/apache2/ssl/host.cert
    SSLCertificateKeyFile /etc/apache2/ssl/host.key

    DocumentRoot /var/www/html
    ErrorLog \${APACHE_LOG_DIR}/error.log
    CustomLog \${APACHE_LOG_DIR}/access.log combined
</VirtualHost>
EOF

    systemctl enable apache2
    systemctl restart apache2
    record_change "Configured and restarted Apache2"
}

configure_haproxy() {
    if is_yes "$SKIP_HAPROXY"; then
        warn "Skipping HAProxy setup."
        return 0
    fi

    systemctl enable haproxy
    systemctl restart haproxy || systemctl start haproxy
    record_change "Enabled HAProxy"
}

configure_fail2ban() {
    if is_yes "$SKIP_FAIL2BAN"; then
        warn "Skipping Fail2Ban setup."
        return 0
    fi

    local fail2ban_main_config="/etc/fail2ban/fail2ban.conf"

    if [[ -f "$fail2ban_main_config" ]] && grep -q "^#allowipv6 = auto" "$fail2ban_main_config"; then
        backup_file_if_exists "$fail2ban_main_config"
        sed -i 's/^#allowipv6 = auto/allowipv6 = auto/' "$fail2ban_main_config"
        record_change "Updated Fail2Ban allowipv6 setting"
    fi

    systemctl enable fail2ban
    systemctl restart fail2ban || systemctl start fail2ban
    record_change "Enabled Fail2Ban"
}

enable_cluster_support_services() {
    systemctl enable pcsd
    systemctl restart pcsd || systemctl start pcsd
    record_change "Enabled pcsd"

    warn "Corosync/Pacemaker/PCS packages are installed, but the cluster is NOT configured."
    warn "Manual follow-up is still required for corosync.conf, node auth, quorum, fencing, and resources."
}

show_service_status() {
    log "Service status summary:"
    local services=(nginx apache2 haproxy fail2ban pcsd)
    local svc
    for svc in "${services[@]}"; do
        if systemctl list-unit-files | grep -q "^${svc}\."; then
            if systemctl is-active --quiet "$svc"; then
                echo "  - $svc: running"
            else
                echo "  - $svc: not running"
            fi
        fi
    done
}

show_summary() {
    echo
    echo "============================================================"
    echo " HArmadillium bootstrap completed"
    echo "============================================================"
    echo "Interface : ${NETIF:-unknown}"
    echo "Static IP : ${STATIC_IP:-unknown}"
    echo "Netmask   : ${SUBNET_MASK:-unknown}"
    echo "Gateway   : ${GATEWAY:-unknown}"
    echo "DNS       : ${DNS_SERVERS:-unknown}"
    echo
    echo "Changes made:"
    for item in "${CHANGES[@]}"; do
        echo "  - $item"
    done

    if [[ "${#WARNINGS[@]}" -gt 0 ]]; then
        echo
        echo "Warnings:"
        for item in "${WARNINGS[@]}"; do
            echo "  - $item"
        done
    fi

    echo
    echo "Important:"
    echo "  - This script prepares a node for HA-related experimentation."
    echo "  - It does NOT create a full HA cluster."
    echo "  - You must still configure Corosync/Pacemaker/PCS manually."
    echo "  - Review network/firewall changes before production use."
    echo "============================================================"
}

main() {
    require_root
    require_commands
    auto_detect_missing_network_values
    validate_network_inputs

    log "Starting HArmadillium bootstrap..."
    log "Detected interface: $NETIF"
    log "STATIC_IP=$STATIC_IP"
    log "SUBNET_MASK=$SUBNET_MASK"
    log "GATEWAY=$GATEWAY"
    log "DNS_SERVERS=$DNS_SERVERS"

    install_packages
    write_netplan_config
    configure_ufw
    generate_ssl_certificates
    configure_nginx
    configure_apache
    configure_haproxy
    configure_fail2ban
    enable_cluster_support_services
    show_service_status
    show_summary
}

main "$@"
