#!/bin/bash
#
# HA Cluster Setup Script (HArmadillium - Propedeutic Sandbox)
# -----------------------------------------------------------
# Purpose:
#   An educational introductory setup script for High Availability nodes.
#   Performs automated network type inspection to prevent
#   parsing type mismatches or connection drops.
#
# Usage:
#   Simply run as root: sudo ./ha_cluster_setup.sh
#   (Optional overrides can still be provided as prefix environment variables)
#
# Author: UniversalBit Development Team
# Version: 1.6.0 (Resilient Edition)
# License: MIT

set -e

if [[ $EUID -ne 0 ]]; then
    echo "❌ Error: This script must be executed with root permissions (sudo)."
    exit 1
fi

echo "=========================================================="
echo " HArmadillium Sandbox: Resilient Environment Setup         "
echo "=========================================================="

# 1. RUNTIME NETWORK ENVIRONMENT DISCOVERY
echo "🔍 Analyzing local network architecture..."

# Detect active default outbound interface route
DETECTED_NETIF=$(ip -o -4 route show to default | awk '{print $5}')
if [[ -z "$DETECTED_NETIF" ]]; then
    echo "❌ Error: Could not determine your active default network interface."
    exit 1
fi

# Extract active local interface IP address safely
DETECTED_IP=$(ip route get 1 2>/dev/null | awk '{print $7;exit}')
if [[ -z "$DETECTED_IP" ]]; then
    DETECTED_IP=$(ip -o -4 addr show dev "$DETECTED_NETIF" | awk '{split($4,a,"/"); print a[1]; exit}')
fi

# Detect live gateway destination
DETECTED_GATEWAY=$(ip -o -4 route show to default | awk '{print $3}')

# Fetch subnet prefix bit mask directly from active device allocation
DETECTED_CIDR=$(ip -o -4 addr show dev "$DETECTED_NETIF" | awk '{split($4,a,"/"); print a[2]; exit}')

# Resolve Hostname parameters
DETECTED_HOST=$(hostname)

# Apply configuration evaluation matrix (Use passed variables OR fall back to discovered runtime facts)
NETIF="${NETIF:-$DETECTED_NETIF}"
STATIC_IP="${STATIC_IP:-$DETECTED_IP}"
GATEWAY="${GATEWAY:-$DETECTED_GATEWAY}"
CIDR="${CIDR_PREFIX:-$DETECTED_CIDR}"
DNS_SERVERS="${DNS_SERVERS:-8.8.8.8,8.8.4.4}"

echo "----------------------------------------------------------"
echo "📊 Network Parameters Identified Automatically:"
echo "   -> Operating Interface:  $NETIF"
echo "   -> Assigned IP Address:  $STATIC_IP/$CIDR"
echo "   -> Gateway Routing Target: $GATEWAY"
echo "   -> Machine System Name:  $DETECTED_HOST"
echo "----------------------------------------------------------"

echo "Provisioning standard high availability packages..."
export DEBIAN_FRONTEND=noninteractive
apt update && apt upgrade -y
apt install -y corosync pacemaker pcs ufw haproxy fail2ban nginx apache2

# 2. ANTI-CRASH RESILIENT NETPLAN RENDERING BLOCK
echo "✍️ Writing Netplan baseline configurations dynamically..."
DNS_FORMATTED=$(echo "$DNS_SERVERS" | sed 's/,/, /g')

# Inspect interface properties to determine if the target interface is a wireless device
IS_WIRELESS=false
if [ -d "/sys/class/net/$NETIF/wireless" ] || [[ "$NETIF" == wl* ]]; then
    IS_WIRELESS=true
fi

if [ "$IS_WIRELESS" = true ]; then
    echo "📶 Wireless interface detected ($NETIF). Adapting Netplan layout to 'wifis' format..."
    cat <<EOF > /etc/netplan/99-harmadillium.yaml
network:
  version: 2
  wifis:
    $NETIF:
      dhcp4: false
      addresses:
        - $STATIC_IP/$CIDR
      routes:
        - to: default
          via: $GATEWAY
      nameservers:
        addresses: [$DNS_FORMATTED]
      # Retains connection logic via NetworkManager or wpa_supplicant backend
EOF
else
    echo "🔌 Ethernet/Virtual interface detected ($NETIF). Using standard 'ethernets' layout..."
    cat <<EOF > /etc/netplan/99-harmadillium.yaml
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
        addresses: [$DNS_FORMATTED]
EOF
fi

chmod 600 /etc/netplan/99-harmadillium.yaml

# Safe application wrapper to prevent sudden script crashes if Netplan verification fails
echo "Applying network parameters safely..."
if ! netplan generate 2>/dev/null; then
    echo "⚠️ Warning: Netplan syntax generation failed. Reverting file to protect existing network connection..."
    rm -f /etc/netplan/99-harmadillium.yaml
else
    # Apply changes using a fallback try/catch syntax block
    netplan apply || {
        echo "⚠️ Warning: 'netplan apply' rejected by runtime backend. Preserving active layout..."
    }
fi

# 3. FIREWALL BOUNDARIES
echo "🧱 Hardening Firewall (UFW) boundaries safely..."
ufw --force reset
ufw default deny incoming
ufw default allow outgoing

echo "   -> Allowing SSH management ingress (Port 22)..."
ufw allow 22/tcp comment 'HArmadillium Management SSH'

echo "   -> Allowing edge HTTP/HTTPS ingress (Ports 80 & 443)..."
ufw allow 80/tcp
ufw allow 443/tcp

echo "   -> Allowing secondary sandbox backend targets (Ports 8080 & 4433)..."
ufw allow 8080/tcp
ufw allow 4433/tcp

echo "   -> Pre-opening cluster synchronizers (Ports 2224, 3121, 5404:5405)..."
ufw allow 2224/tcp comment 'PCSD Cluster Control'
ufw allow 3121/tcp comment 'Pacemaker Cluster Resource Manager'
ufw allow 5404:5405/udp comment 'Corosync Token Ring Traffic'

echo "Enabling UFW..."
yes | ufw enable

# 4. CERTIFICATE PRODUCTION & WEB MATRIX STACKS
echo "🛡️ Generating web stack SSL/TLS cryptographic credentials..."
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
SSL_CONFIG_PATH="$SCRIPT_DIR/ssl/distinguished.cnf"

if [ ! -f "$SSL_CONFIG_PATH" ]; then
    echo "⚠️ Info: External certificate blueprint omitted. Compiling inline dynamic target context..."
    SSL_CONFIG_PATH="/tmp/openssl_sandbox.cnf"
    cat <<EOF > "$SSL_CONFIG_PATH"
[req]
distinguished_name = req_distinguished_name
prompt = no
[req_distinguished_name]
C = XZ
O = HArmadillium Educational Sandbox Node
CN = $STATIC_IP
EOF
fi

mkdir -p /etc/nginx/ssl
openssl req -x509 -nodes -days 365 -newkey rsa:2048 \
    -keyout /etc/nginx/ssl/host.key -out /etc/nginx/ssl/host.cert \
    -config "$SSL_CONFIG_PATH"

mkdir -p /etc/apache2/ssl
cp /etc/nginx/ssl/host.key /etc/apache2/ssl/host.key
cp /etc/nginx/ssl/host.cert /etc/apache2/ssl/host.cert

echo "🌐 Structuring Nginx load-handling proxy entry points..."
rm -f /etc/nginx/sites-enabled/default
cat <<EOF > /etc/nginx/sites-enabled/default
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
systemctl restart nginx

echo "🦅 Structuring Apache2 virtual host assignments..."
a2enmod ssl --quiet

cat <<EOF > /etc/apache2/ports.conf
Listen 8080
Listen 4433
EOF

cat <<EOF > /etc/apache2/sites-available/ha-default.conf
<VirtualHost *:8080>
    Redirect permanent / https://$STATIC_IP:4433/
</VirtualHost>

<VirtualHost *:4433>
    SSLEngine on
    SSLCertificateFile /etc/apache2/ssl/host.cert
    SSLCertificateKeyFile /etc/apache2/ssl/host.key

    DocumentRoot /var/www/html
    ErrorLog \${APACHE_LOG_DIR}/error.log
    CustomLog \${APACHE_LOG_DIR}/access.log combined
</VirtualHost>
EOF

# Hardened removal: force un-link or delete regular config files to avoid crashing a2dissite
rm -f /etc/apache2/sites-enabled/000-default.conf
a2dissite 000-default --quiet || true

a2ensite ha-default --quiet
systemctl restart apache2

echo "🔒 Syncing Fail2Ban protection environments..."
fail2ban_main_config="/etc/fail2ban/fail2ban.conf"
if [ -f "$fail2ban_main_config" ] && grep -q "^#allowipv6 = auto" "$fail2ban_main_config"; then
    sed -i 's/^#allowipv6 = auto/allowipv6 = auto/' "$fail2ban_main_config"
fi
systemctl enable fail2ban
systemctl start fail2ban

echo "Starting local cluster administration backends..."
systemctl enable pcsd
systemctl start pcsd

echo "----------------------------------------------------------"
echo "✅ Local service operational integrity audit completed:"
for svc in nginx apache2 haproxy fail2ban pcsd; do
    if systemctl is-active --quiet $svc; then
        echo "  [ ONLINE ] Service '$svc' is tracking normally."
    else
        echo "  [ FAILED ] Service '$svc' is unresponsive."
    fi
done
echo "=========================================================="
echo "🎯 Setup Complete! The host sandbox baseline environment is active."
echo "=========================================================="
