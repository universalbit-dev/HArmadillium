#!/bin/bash
#
# HArmadillium Cryptographic Certificate Engine
# Copyright (C) 2026 universalbit-dev
#
# This program is free software: you can redistribute it and/or modify
# it under the terms of the GNU General Public License as published by
# the Free Software Foundation, either version 3 of the License, or
# (at your option) any later version.
#
# This program is distributed in the hope that it will be useful,
# but WITHOUT ANY WARRANTY; without even the implied warranty of
# MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
# GNU General Public License for more details.
#
# You should have received a copy of the GNU General Public License
# along with this program.  If not, see <https://www.gnu.org/licenses/>.
#
set -e

echo "=========================================================="
echo " HArmadillium Cryptographic Certificate Engine            "
echo "=========================================================="

# 1. Target Directory Setup
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
TARGET_CERT_DIR="$SCRIPT_DIR/certs"
mkdir -p "$TARGET_CERT_DIR"

# 2. Dynamic IP and Hostname Discovery for SSL SAN validation
DETECTED_IP=$(ip route get 1 2>/dev/null | awk '{print $7;exit}')

# If the system cannot detect the IP automatically, prompt the user
if [ -z "$DETECTED_IP" ]; then
    echo "⚠️ Warning: Could not detect your wired IP address automatically."
    echo "Please enter the static IP address of this thin client"
    read -r DETECTED_IP
fi

CURRENT_HOST=$(hostname)

echo "Generating assets for Host: $CURRENT_HOST ($DETECTED_IP)"
echo "Output Target Directory: $TARGET_CERT_DIR"

# 3. Create a clean OpenSSL configuration file with Subject Alternative Names (SAN)
CONFIG_PATH="$TARGET_CERT_DIR/openssl_dynamic.cnf"

cat <<EOF > "$CONFIG_PATH"
[req]
distinguished_name = req_distinguished_name
x509_extensions = v3_req
prompt = no

[req_distinguished_name]
C = XZ
O = HArmadillium Open Source Node
CN = $DETECTED_IP

[v3_req]
keyUsage = critical, digitalSignature, keyEncipherment
extendedKeyUsage = serverAuth
subjectAltName = @alt_names

[alt_names]
IP.1 = $DETECTED_IP
IP.2 = 127.0.0.1
DNS.1 = $CURRENT_HOST
DNS.2 = localhost
EOF

# 4. Generate the 2048-bit RSA Private Key and Self-Signed Certificate Chain
echo "Compiling SSL/TLS credentials..."
openssl req -x509 -nodes -days 365 -newkey rsa:2048 \
    -keyout "$TARGET_CERT_DIR/cluster.key" \
    -out "$TARGET_CERT_DIR/cluster.crt" \
    -config "$CONFIG_PATH"

# Enforce strict private key file security permissions
chmod 600 "$TARGET_CERT_DIR/cluster.key"

# 5. Backup assignments matching classic root script filenames
cp "$TARGET_CERT_DIR/cluster.key" "$TARGET_CERT_DIR/host.key"
cp "$TARGET_CERT_DIR/cluster.crt" "$TARGET_CERT_DIR/host.cert"
chmod 600 "$TARGET_CERT_DIR/host.key"

# Clean up temporary configuration file
rm -f "$CONFIG_PATH"

echo "----------------------------------------------------------"
echo " Cryptographic keys securely generated and deployed:"
echo " -> Key:  $TARGET_CERT_DIR/cluster.key"
echo " -> Cert: $TARGET_CERT_DIR/cluster.crt"
echo "=========================================================="
