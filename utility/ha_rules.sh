#!/bin/bash
#
# HArmadillium Dynamic HA Firewall Component
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
echo " HArmadillium Dynamic HA Firewall Component               "
echo "=========================================================="

MASTER_IP=$1
DETECTED_IP=$2

# Extract current running local user dynamically
CURRENT_USER=$(whoami)
USER_HOME=$HOME

# Safe Fallback: Use 3rd argument if provided, otherwise default to the active local user
SSH_USER=${3:-$CURRENT_USER}

# 1. Parameter Validation & Subnet-Hidden Help Text
if [ -z "$MASTER_IP" ] || [ -z "$DETECTED_IP" ]; then
    echo "❌ Error: Missing parameters."
    echo "Usage:   ./ha_rules.sh <MASTER_IP> <LOCAL_IP> [SSH_USER]"
    echo "Example: ./ha_rules.sh 192.168.1.141 192.168.1.142 armadillium01"
    exit 1
fi

# Function to validate standard IPv4 format
validate_ip() {
    if [[ ! $1 =~ ^[0-9]{1,3}\.[0-9]{1,3}\.[0-9]{1,3}\.[0-9]{1,3}$ ]]; then
        echo "❌ Error: Invalid IP address format: $1"
        exit 1
    fi
}

validate_ip "$MASTER_IP"
validate_ip "$DETECTED_IP"

# 2. Fix local SSH ownership obstacles using generic paths
echo "🔧 Polishing local secure environment permissions for user: $CURRENT_USER..."
sudo chown -R "${CURRENT_USER}:${CURRENT_USER}" "$USER_HOME/.ssh" || true
chmod 700 "$USER_HOME/.ssh" || true
if [ -f "$USER_HOME/.ssh/known_hosts" ]; then
    chmod 600 "$USER_HOME/.ssh/known_hosts" || true
fi

# 3. Pre-flight SSH Connectivity Verification
echo "📡 Verifying SSH access to Master node (${SSH_USER}@${MASTER_IP})..."
if ! ssh -o StrictHostKeyChecking=no -o ConnectTimeout=5 -o BatchMode=yes "${SSH_USER}@${MASTER_IP}" "true" 2>/dev/null; then
    echo "⚠️ Warning: Non-interactive SSH test failed."
    echo "Please ensure your SSH public keys are exchanged before continuing."
    echo "Attempting standard connection (may prompt for password)..."
fi

echo "🔍 Parsing master cluster blueprints via ${SSH_USER}@${MASTER_IP}..."
CONFIG_IPS=$(ssh -o StrictHostKeyChecking=no -o ConnectTimeout=5 "${SSH_USER}@${MASTER_IP}" \
    "grep -E 'ring._addr:' /etc/corosync/corosync.conf 2>/dev/null" | awk '{print $2}' | grep -E '^[0-9.]+$' || true)

# Combine blueprint targets, Master IP, and this new local node's detected IP into a unique grid
NODES=($(echo -e "${CONFIG_IPS}\n${MASTER_IP}\n${DETECTED_IP}" | sort -u))
echo "🛡️ Hardened Cluster Node Grid Discovered: ${NODES[*]}"

# 4. Firewall Reset and Initialization
echo "🧱 Resetting and optimizing local UFW rules..."
sudo ufw --force reset
sudo ufw default deny incoming
sudo ufw default allow outgoing

# Open global management pathways
echo "🔓 Allowing incoming infrastructure management (SSH: Port 22)..."
sudo ufw allow 22/tcp comment 'HArmadillium Management SSH'

# 5. Apply strict IP isolation mapping to core cluster backends
echo "🔒 Enforcing mesh isolation loops across node matrix..."
for NODE_IP in "${NODES[@]}"; do
    if [ -n "$NODE_IP" ]; then
        echo "   -> Trusting Node IP: $NODE_IP"
        sudo ufw allow from "$NODE_IP" to any port 2224 proto tcp comment "HA Cluster Mesh: PCSD from $NODE_IP"
        sudo ufw allow from "$NODE_IP" to any port 3121 proto tcp comment "HA Cluster Mesh: Pacemaker CRM from $NODE_IP"
        sudo ufw allow from "$NODE_IP" to any port 5404:5405 proto udp comment "HA Cluster Mesh: Totem Ring from $NODE_IP"
        sudo ufw allow from "$NODE_IP" to any port 9929 comment "HA Cluster Mesh: Corosync/QNetd from $NODE_IP"
    fi
done

sudo ufw --force enable
echo "=========================================================="
echo " ✅ SUCCESS: Firewall optimization completed successfully!"
echo "=========================================================="
