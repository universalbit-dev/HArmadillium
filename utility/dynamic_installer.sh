#!/bin/bash
#
# HArmadillium Core High-Availability Cluster Installer
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
echo " HArmadillium Core High-Availability Cluster Installer    "
echo "=========================================================="

# 1. Automatic interface and stationary network detection
NETIF=$(ip -o -4 route show to default | awk '{print $5}')
DETECTED_IP=$(ip route get 1 | awk '{print $7;exit}')

# If the system cannot detect the IP automatically, prompt the user
if [ -z "$DETECTED_IP" ]; then
    echo "⚠️ Warning: Could not detect your wired IP address automatically."
    echo "Please enter the static IP address of this thin client:"
    read -r DETECTED_IP
fi

echo "Target Interface: $NETIF"
echo "Detected IP Address: $DETECTED_IP"
echo "----------------------------------------------------------"
echo "Is this your first thin client node (Genesis Master)? (y/n)"
read -r IS_MASTER

# Cluster Passwords passed via Environment or securely inputted
if [ -z "$CLUSTER_PASS" ]; then
    echo "Please enter a secure password for the cluster admin user (hacluster):"
    read -s -r CLUSTER_PASS
    echo ""
fi

# Base package provisioning common to all nodes
echo "Updating packages and verifying cluster components..."
sudo apt update && sudo apt install -y corosync pacemaker pcs ufw fail2ban

# Set script path tracking
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

if [ "$IS_MASTER" = "y" ] || [ "$IS_MASTER" = "Y" ]; then
    echo "Initializing Genesis Configuration..."
    
    # 2. Initialize Single-Node Cluster Architecture (Clean Wiped State)
    echo "Configuring high availability PCS stack..."
    
    # Stop services and force automated cluster cleanup without interactive prompts
    sudo systemctl stop pcsd || true
    echo "yes" | sudo pcs cluster destroy || true
    
    # Wipe the known-hosts and session tokens to clear communication hang-ups
    echo "Purging stale token cache files..."
    sudo rm -f /var/lib/pcsd/pcs_settings.conf
    sudo rm -f /var/lib/pcsd/pcs_known_hosts
    sudo rm -f /var/lib/pcsd/tokens
    
    # Force fresh service start
    sudo systemctl daemon-reload
    sudo systemctl restart pcsd
    sudo systemctl enable pcsd
    
    echo "Waiting for pcsd socket initialization (Port 2224)..."
    for i in {1..15}; do
        if ss -tlnp | grep -q ":2224"; then
            echo "pcsd daemon is alive and listening!"
            break
        fi
        if [ $i -eq 15 ]; then
            echo "❌ Error: pcsd failed to respond on port 2224 within 15 seconds."
            exit 1
        fi
        sleep 1
    done
    
    echo "Setting up local cluster credentials..."
    echo "hacluster:$CLUSTER_PASS" | sudo chpasswd
    
    # Give the system a brief pause to sync the new password into memory
    sleep 1
    
    echo "Authorizing local client and master network identities..."
    sudo pcs client local-auth -u hacluster -p "$CLUSTER_PASS"
    
    # Authenticate BOTH explicit LAN IP and local hostname simultaneously 
    # to safely prime the token store and clear host setup errors
    sudo pcs host auth "$DETECTED_IP" "$(hostname)" -u hacluster -p "$CLUSTER_PASS"
    
    echo "Creating isolated single-node cluster topology..."
    sudo pcs cluster setup HArmadillium $DETECTED_IP --force
    
    echo "Starting cluster engines..."
    sudo pcs cluster start --all
    sudo pcs cluster enable --all
    sudo pcs property set stonith-enabled=false
    sudo pcs property set no-quorum-policy=ignore

    echo "=========================================================="
    echo " SUCCESS: Secure Genesis Node cluster fully initialized!"
    echo " Core cluster communication handling online."
    echo "=========================================================="

else
    # 3. Scalable Onboarding Pipeline for Independent Peer Joiner Nodes
    echo "Preparing to join an existing cluster..."
    echo "Please enter the target IP of your Genesis Master thin client (e.g., 192.168.1.141):"
    read -r MASTER_IP
    
    # Dynamically determine or ask for SSH user instead of hardcoding
    CURRENT_SSH_USER=$(whoami)
    echo "Enter SSH user for target Master node [Default: $CURRENT_SSH_USER]:"
    read -r INPUT_USER
    SSH_USER=${INPUT_USER:-$CURRENT_SSH_USER}

    echo "Configuring cluster authentication layer..."
    sudo systemctl stop pcsd || true
    echo "yes" | sudo pcs cluster destroy || true
    sudo rm -f /var/lib/pcsd/pcs_settings.conf
    sudo rm -f /var/lib/pcsd/pcs_known_hosts
    sudo rm -f /var/lib/pcsd/tokens
    
    sudo systemctl daemon-reload
    sudo systemctl restart pcsd
    sudo systemctl enable pcsd
    
    echo "Waiting for pcsd socket initialization (Port 2224)..."
    for i in {1..15}; do
        if ss -tlnp | grep -q ":2224"; then
            echo "pcsd daemon is alive and listening!"
            break
        fi
        sleep 1
    done
    
    echo "hacluster:$CLUSTER_PASS" | sudo chpasswd
    sleep 1
    
    echo "Authenticating locally..."
    sudo pcs client local-auth -u hacluster -p "$CLUSTER_PASS"
    
    echo "Authenticating mutually with the Genesis Master node ($MASTER_IP)..."
    sudo pcs host auth "$MASTER_IP" "$DETECTED_IP" "$(hostname)" -u hacluster -p "$CLUSTER_PASS"
    
    # Request the master node to add this node to the cluster map securely via SSH
    echo "Requesting cluster membership updates from the Master..."
    ssh -t "${SSH_USER}@${MASTER_IP}" "sudo pcs host auth $DETECTED_IP -u hacluster -p '$CLUSTER_PASS' && (sudo pcs cluster node add $DETECTED_IP --start --enable || true)"
    
    echo "Starting local cluster services..."
    sudo systemctl restart pcsd
    sudo pcs cluster enable --all 2>/dev/null || true
    sudo pcs cluster start --all 2>/dev/null || true
    
    echo "=========================================================="
    echo " SUCCESS: Node added to the HArmadillium cluster!"
    echo "=========================================================="
fi
