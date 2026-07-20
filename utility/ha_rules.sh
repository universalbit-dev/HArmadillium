#!/usr/bin/env bash
set -euo pipefail

echo "=========================================================="
echo " HArmadillium Dynamic HA Firewall Component               "
echo "=========================================================="

log()  { echo "[$(date '+%Y-%m-%d %H:%M:%S')] [INFO] $*"; }
warn() { echo "[$(date '+%Y-%m-%d %H:%M:%S')] [WARN] $*" >&2; }
die()  { echo "[$(date '+%Y-%m-%d %H:%M:%S')] [ERROR] $*" >&2; exit 1; }

validate_ipv4() {
  local ip="$1"
  [[ "$ip" =~ ^([0-9]{1,3}\.){3}[0-9]{1,3}$ ]] || return 1
  IFS='.' read -r a b c d <<< "$ip"
  for o in "$a" "$b" "$c" "$d"; do
    (( o >= 0 && o <= 255 )) || return 1
  done
  return 0
}

command -v ssh >/dev/null 2>&1 || die "ssh command not found"
command -v ssh-keyscan >/dev/null 2>&1 || die "ssh-keyscan command not found"
command -v ufw >/dev/null 2>&1 || die "ufw command not found"

MASTER_IP="${1:-}"
DETECTED_IP="${2:-}"
SSH_USER="${3:-$(whoami)}"

[[ -n "$MASTER_IP" && -n "$DETECTED_IP" ]] || die "Usage: ./ha_rules.sh <MASTER_IP> <LOCAL_IP> [SSH_USER]"
validate_ipv4 "$MASTER_IP"  || die "Invalid MASTER_IP: $MASTER_IP"
validate_ipv4 "$DETECTED_IP" || die "Invalid LOCAL_IP: $DETECTED_IP"

CURRENT_USER="$(whoami)"
USER_HOME="$HOME"
KNOWN_HOSTS="$USER_HOME/.ssh/known_hosts"

# Secure local SSH directory
mkdir -p "$USER_HOME/.ssh"
chmod 700 "$USER_HOME/.ssh"
touch "$KNOWN_HOSTS"
chmod 600 "$KNOWN_HOSTS"
chown -R "${CURRENT_USER}:${CURRENT_USER}" "$USER_HOME/.ssh" || true

# Safe host-key bootstrap: remove old entry then add fresh fingerprint
log "Refreshing SSH known_hosts entry for ${MASTER_IP}..."
ssh-keygen -R "$MASTER_IP" -f "$KNOWN_HOSTS" >/dev/null 2>&1 || true
ssh-keyscan -H -T 5 "$MASTER_IP" >> "$KNOWN_HOSTS" 2>/dev/null || die "Unable to fetch SSH host key from ${MASTER_IP}"

log "Fetching cluster node IPs from master ${SSH_USER}@${MASTER_IP}..."
CONFIG_IPS="$(ssh -o BatchMode=yes -o ConnectTimeout=8 "${SSH_USER}@${MASTER_IP}" \
  "grep -E 'ring[0-9]*_addr:' /etc/corosync/corosync.conf 2>/dev/null | awk '{print \$2}' | grep -E '^[0-9.]+$' || true")" || true

# Build unique node set: discovered + master + local
mapfile -t NODES < <(printf "%s\n%s\n%s\n" "$CONFIG_IPS" "$MASTER_IP" "$DETECTED_IP" \
  | awk 'NF' | sort -u)

if [[ ${#NODES[@]} -eq 0 ]]; then
  die "No valid node IPs discovered."
fi

for ip in "${NODES[@]}"; do
  validate_ipv4 "$ip" || die "Discovered invalid IP: $ip"
done

log "Discovered cluster node grid: ${NODES[*]}"

log "Resetting and applying UFW policy..."
sudo ufw --force reset
sudo ufw default deny incoming
sudo ufw default allow outgoing

# Management access
sudo ufw allow 22/tcp comment 'HArmadillium Management SSH'

# Cluster mesh rules scoped per node IP
for NODE_IP in "${NODES[@]}"; do
