#!/usr/bin/env bash
set -euo pipefail

echo "=========================================================="
echo " HArmadillium Dynamic HA Firewall Component               "
echo "=========================================================="

# Usage:
#   ./ha_rules.sh --nodes <thinclient-IP-01>,<thinclient-IP-02>,<thinclient-IP-N>
# Optional:
#   --ssh-port 22
#   --no-reset

NODES_CSV=""
SSH_PORT="22"
DO_RESET="yes"

while [[ $# -gt 0 ]]; do
  case "$1" in
    --nodes)    NODES_CSV="${2:-}"; shift 2 ;;
    --ssh-port) SSH_PORT="${2:-22}"; shift 2 ;;
    --no-reset) DO_RESET="no"; shift 1 ;;
    *)
      echo "❌ Unknown argument: $1"
      exit 1
      ;;
  esac
done

if [[ -z "$NODES_CSV" ]]; then
  echo "Usage: $0 --nodes <ip1,ip2,ip3[,ip4]> [--ssh-port 22] [--no-reset]"
  exit 1
fi

# Auto-detect local node IP from provided node list
LOCAL_IP="$(hostname -I | tr ' ' '\n' | grep -E '^[0-9]+\.[0-9]+\.[0-9]+\.[0-9]+$' | head -n1 || true)"
if [[ -z "$LOCAL_IP" ]]; then
  echo "❌ Could not detect local IPv4."
  exit 1
fi

IFS=',' read -r -a RAW_NODES <<< "$NODES_CSV"
NODES=()
for ip in "${RAW_NODES[@]}"; do
  ip="$(echo "$ip" | xargs)"
  [[ "$ip" =~ ^[0-9]+\.[0-9]+\.[0-9]+\.[0-9]+$ ]] && NODES+=("$ip")
done

if [[ "${#NODES[@]}" -eq 0 ]]; then
  echo "❌ No valid node IPs parsed from --nodes"
  exit 1
fi

echo "ℹ️ Local IP detected: $LOCAL_IP"
echo "ℹ️ Cluster nodes: ${NODES[*]}"

if [[ "$DO_RESET" == "yes" ]]; then
  echo "🧱 Resetting UFW..."
  sudo ufw --force reset
  sudo ufw default deny incoming
  sudo ufw default allow outgoing
fi

# Public management / edge
sudo ufw allow "${SSH_PORT}/tcp" comment 'HArmadillium Management SSH'
sudo ufw allow 80/tcp   comment 'HArmadillium HTTP Redirect Edge'
sudo ufw allow 443/tcp  comment 'HArmadillium Nginx TLS Edge'
sudo ufw allow 3001/tcp comment 'HArmadillium Custom Dashboard UI'
sudo ufw allow 4433/tcp comment 'HArmadillium Apache2 Secure Backend'

# HA mesh from all declared nodes
for NODE_IP in "${NODES[@]}"; do
  sudo ufw allow from "$NODE_IP" to any port 2224 proto tcp comment "HA Cluster Mesh: PCSD from $NODE_IP"
  sudo ufw allow from "$NODE_IP" to any port 3121 proto tcp comment "HA Cluster Mesh: Pacemaker CRM from $NODE_IP"
  sudo ufw allow from "$NODE_IP" to any port 5404:5405 proto udp comment "HA Cluster Mesh: Totem Ring from $NODE_IP"
  sudo ufw allow from "$NODE_IP" to any port 9929 proto tcp comment "HA Cluster Mesh: Corosync/QNetd from $NODE_IP"
done

# App exposure policy
sudo ufw deny  8000/tcp comment 'Block Direct Unencrypted CNCjs Access'
sudo ufw allow 8443/tcp comment 'UniversalBit CNCjs Secure Proxy'
sudo ufw allow 9443/tcp comment 'GeoLibre secure reverse proxy'

sudo ufw --force enable
echo "✅ Done."
sudo ufw status
