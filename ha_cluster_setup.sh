#!/bin/bash
#
# HA Cluster Setup Script (HArmadillium)
# --------------------------------------
# Purpose:
#   This script automates the setup of a High Availability (HA) cluster using
#   Corosync, Pacemaker, and other supporting tools. It also includes the setup
#   and configuration of firewall (ufw), HAProxy, Fail2Ban, Nginx, and Apache2
#   with example configurations for port bindings. SSL certificates are created
#   using the `HArmadillium/ssl/distinguished.cnf` file for HTTPS.
#
# Usage:
#   Before running the script, ensure the HArmadillium project is cloned and the
#   ssl/distinguished.cnf file exists within the cloned directory.
#   
#   Permission: chmod a+x ha_cluster_setup.sh
#   Run: ./ha_cluster_setup.sh
#
# Author:
#   UniversalBit Development Team (https://github.com/universalbit-dev)
#
# Version:
#   1.4.0
#
#   - Ubuntu 24.04 or compatible Linux distribution
#   - Required packages: corosync, pacemaker, pcs, ufw, haproxy, fail2ban, nginx, apache2
#
# License: MIT 
#
# Notes:
#
#   - This script requires sudo privileges.
#

# Step 1: Update system and install dependencies
echo "Updating system and installing required packages..."
sudo apt update && sudo apt upgrade -y
sudo apt install -y corosync pacemaker pcs ufw haproxy fail2ban nginx apache2

# Step 2: Define Static IP Address
echo "Configuring static IP for this node..."

read -p "Enter the static IP address for this node (e.g., 192.168.1.100): " static_ip
read -p "Enter the subnet mask (e.g., 255.255.255.0): " subnet_mask
read -p "Enter the gateway address (e.g., 192.168.1.1): " gateway
read -p "Enter DNS nameservers (comma-separated, e.g., 8.8.8.8,8.8.4.4): " dns_servers

# Validate the static IP address format
while [[ ! "$static_ip" =~ ^([0-9]{1,3}\.){3}[0-9]{1,3}$ ]]; do
    echo "Invalid IP address format. Please enter a valid IPv4 address."
    read -p "Enter the static IP address for this node: " static_ip
done

# Provide instructions for configuring the static IP
echo "Creating netplan configuration for static IP..."
cat <<EOF | sudo tee /etc/netplan/99-static-ip.yaml
network:
  version: 2
  ethernets:
    $(ip -o -4 route show to default | awk '{print $5}'): # Detect the active network interface
      addresses:
        - $static_ip/24
      routes:
        - to: default
          via: $gateway
      nameservers:
        addresses: [${dns_servers//,/ }]
EOF


# Apply the netplan configuration
echo "Applying static IP configuration..."
sudo chmod 600 /etc/netplan/99-static-ip.yaml
sudo netplan apply


# Verify the IP address
echo "Verifying the static IP configuration..."
ip addr show
echo "Static IP address configured: $static_ip"

# Step 3: Enable UFW
echo "Enabling UFW..."
sudo ufw enable  --force
echo "Firewall (UFW) has been enabled."

# Step 4: Configure and start HAProxy
echo "Configuring HAProxy..."
sudo systemctl enable haproxy
sudo systemctl start haproxy

# Step 5: Generate SSL Certificates using `HArmadillium/ssl/` folder
echo "Generating SSL certificates..."
export DYNAMIC_CN=$(hostname)  # Dynamically set the CN using the server's hostname
SSL_CONFIG_PATH="HArmadillium/ssl/distinguished.cnf"

# Check if the SSL configuration file exists
if [ ! -f "$SSL_CONFIG_PATH" ]; then
    echo "Error: SSL configuration file not found at $SSL_CONFIG_PATH."
    echo "Ensure you have cloned the HArmadillium repository and the file exists."
    exit 1
fi

# Generate self-signed certificate for Nginx
sudo mkdir -p /etc/nginx/ssl
sudo openssl req -x509 -nodes -days 365 -newkey rsa:2048 \
    -keyout /etc/nginx/ssl/host.key -out /etc/nginx/ssl/host.cert \
    -config "$SSL_CONFIG_PATH"

# Generate self-signed certificate for Apache2
sudo mkdir -p /etc/apache2/ssl
sudo openssl req -x509 -nodes -days 365 -newkey rsa:2048 \
    -keyout /etc/apache2/ssl/host.key -out /etc/apache2/ssl/host.cert \
    -config "$SSL_CONFIG_PATH"

# Step 6: Configure Nginx with specified ports
echo "Configuring Nginx with HTTPS redirection..."
sudo rm /etc/nginx/sites-enabled/default
cat <<EOF | sudo tee /etc/nginx/sites-enabled/default
server {
    listen 80;
    server_name localhost;

    # Redirect all HTTP traffic to HTTPS
    return 301 https://\$host\$request_uri;
}

server {
    listen 443 ssl;
    server_name localhost;

    ssl_certificate /etc/nginx/ssl/host.cert;
    ssl_certificate_key /etc/nginx/ssl/host.key;

    location / {
        root /var/www/html;
        index index.html;
    }
}
EOF
sudo systemctl restart nginx

# Step 7: Configure Apache2 with specified ports
echo "Configuring Apache2 with HTTPS redirection..."
cat <<EOF | sudo tee /etc/apache2/ports.conf
Listen 8080
Listen 4433
EOF

cat <<EOF | sudo tee /etc/apache2/sites-enabled/000-default.conf
<VirtualHost *:8080>
    # Redirect all HTTP traffic to HTTPS
    Redirect permanent / https://localhost:4433/
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
sudo systemctl restart apache2

# Step 8: Configure and start Fail2Ban
echo "Configuring Fail2Ban..."
sudo systemctl enable fail2ban
sudo systemctl start fail2ban

# Final Step: Display service status
echo "Service status:"
sudo systemctl status nginx --no-pager || echo "Nginx service is not active."
sudo systemctl status apache2 --no-pager || echo "Apache2 service is not active."
sudo systemctl status haproxy --no-pager || echo "HAProxy service is not active."
sudo systemctl status fail2ban --no-pager || echo "Fail2Ban service is not active."

echo "HA Cluster setup with web server configurations and SSL completed successfully!"
