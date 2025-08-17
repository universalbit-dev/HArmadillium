#!/bin/bash
#
# HA Cluster Setup Script (HArmadillium)
# --------------------------------------
# Purpose:
#   Non-interactive setup of a High Availability (HA) cluster using Corosync, Pacemaker, and supporting tools.
#   Configures firewall (ufw), HAProxy, Fail2Ban, Nginx, and Apache2 with port bindings.
#   SSL certificates are created using the `ssl/distinguished.cnf` file for HTTPS.
#
# Usage:
#   Set the following environment variables before running:
#     STATIC_IP        - static IPv4 address for this node (e.g., 192.168.1.100)
#     SUBNET_MASK      - subnet mask (e.g., 255.255.255.0)
#     GATEWAY          - gateway address (e.g., 192.168.1.1)
#     DNS_SERVERS      - comma-separated DNS servers (e.g., 8.8.8.8,8.8.4.4)
#
#   Example:
#     STATIC_IP=192.168.1.100 SUBNET_MASK=255.255.255.0 GATEWAY=192.168.1.1 DNS_SERVERS=8.8.8.8,8.8.4.4 ./ha_cluster_setup.sh
#
# Author: UniversalBit Development Team
# Version: 1.4.0 (Automation edition)
# License: MIT

set -e

# --- Functions ---
netmask_to_cidr() {
    local mask=$1
    local IFS=.
    local -a octets=($mask)
    local cidr=0
    for octet in "${octets[@]}"; do
        case $octet in
            255) ((cidr+=8));;
            254) ((cidr+=7));;
            252) ((cidr+=6));;
            248) ((cidr+=5));;
            240) ((cidr+=4));;
            224) ((cidr+=3));;
            192) ((cidr+=2));;
            128) ((cidr+=1));;
            0);;
            *) echo "Invalid netmask: $mask"; exit 1;;
        esac
    done
    echo "$cidr"
}

# --- Parameter Validation ---
STATIC_IP="${STATIC_IP:-}"
SUBNET_MASK="${SUBNET_MASK:-}"
GATEWAY="${GATEWAY:-}"
DNS_SERVERS="${DNS_SERVERS:-}"

if [[ -z "$STATIC_IP" || ! "$STATIC_IP" =~ ^([0-9]{1,3}\.){3}[0-9]{1,3}$ ]]; then
    echo "Error: STATIC_IP must be set to a valid IPv4 address."
    exit 1
fi
if [[ -z "$SUBNET_MASK" || ! "$SUBNET_MASK" =~ ^([0-9]{1,3}\.){3}[0-9]{1,3}$ ]]; then
    echo "Error: SUBNET_MASK must be set to a valid subnet mask."
    exit 1
fi
if [[ -z "$GATEWAY" || ! "$GATEWAY" =~ ^([0-9]{1,3}\.){3}[0-9]{1,3}$ ]]; then
    echo "Error: GATEWAY must be set to a valid IPv4 address."
    exit 1
fi
if [[ -z "$DNS_SERVERS" ]]; then
    echo "Error: DNS_SERVERS must be set to at least one DNS IP."
    exit 1
fi

CIDR=$(netmask_to_cidr "$SUBNET_MASK")

if [[ $EUID -ne 0 ]]; then
    echo "Please run this script as root."
    exit 1
fi

echo "Updating system and installing required packages..."
apt update && apt upgrade -y
apt install -y corosync pacemaker pcs ufw haproxy fail2ban nginx apache2

echo "Configuring static IP for this node..."

# Detect active network interface
NETIF=$(ip -o -4 route show to default | awk '{print $5}')
if [[ -z "$NETIF" ]]; then
    echo "Error: Could not detect active network interface."
    exit 1
fi

cat <<EOF > /etc/netplan/99-static-ip.yaml
network:
  version: 2
  ethernets:
    $NETIF:
      addresses:
        - $STATIC_IP/$CIDR
      routes:
        - to: default
          via: $GATEWAY
      nameservers:
        addresses: [${DNS_SERVERS//,/ }]
EOF

chmod 600 /etc/netplan/99-static-ip.yaml
netplan apply

echo "Verifying static IP configuration..."
ip addr show
echo "Static IP address configured: $STATIC_IP/$CIDR"

echo "Enabling UFW..."
yes | ufw enable
echo "Firewall (UFW) has been enabled."

echo "Configuring HAProxy..."
systemctl enable haproxy
systemctl start haproxy

echo "Generating SSL certificates..."
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
SSL_CONFIG_PATH="$SCRIPT_DIR/ssl/distinguished.cnf"
export DYNAMIC_CN=$(hostname)

if [ ! -f "$SSL_CONFIG_PATH" ]; then
    echo "Error: SSL configuration file not found at $SSL_CONFIG_PATH."
    exit 1
fi

mkdir -p /etc/nginx/ssl
openssl req -x509 -nodes -days 365 -newkey rsa:2048 \
    -keyout /etc/nginx/ssl/host.key -out /etc/nginx/ssl/host.cert \
    -config "$SSL_CONFIG_PATH"

mkdir -p /etc/apache2/ssl
openssl req -x509 -nodes -days 365 -newkey rsa:2048 \
    -keyout /etc/apache2/ssl/host.key -out /etc/apache2/ssl/host.cert \
    -config "$SSL_CONFIG_PATH"

echo "Configuring Nginx with HTTPS redirection..."
rm -f /etc/nginx/sites-enabled/default
cat <<EOF > /etc/nginx/sites-enabled/default
server {
    listen 80;
    server_name $STATIC_IP;

    # Redirect all HTTP traffic to HTTPS
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
systemctl restart nginx

echo "Configuring Apache2 with HTTPS redirection..."
cat <<EOF > /etc/apache2/ports.conf
Listen 8080
Listen 4433
EOF

cat <<EOF > /etc/apache2/sites-enabled/000-default.conf
<VirtualHost *:8080>
    # Redirect all HTTP traffic to HTTPS
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
systemctl restart apache2

echo "Configuring Fail2Ban..."
fail2ban_main_config="/etc/fail2ban/fail2ban.conf"
if grep -q "^#allowipv6 = auto" "$fail2ban_main_config"; then
    echo "Uncommenting allowipv6 = auto in Fail2Ban main configuration..."
    sed -i 's/^#allowipv6 = auto/allowipv6 = auto/' "$fail2ban_main_config"
fi

systemctl enable fail2ban
systemctl start fail2ban

echo "Service status:"
for svc in nginx apache2 haproxy fail2ban; do
    if systemctl is-active --quiet $svc; then
        echo "$svc is running."
    else
        echo "Error: $svc failed to start."
    fi
done

echo "HA Cluster setup with web server configurations and SSL completed successfully!"
