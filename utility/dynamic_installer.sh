#!/usr/bin/env bash
set -euo pipefail

echo "=========================================================="
echo " HArmadillium Core High-Availability Cluster Installer    "
echo "=========================================================="

log()  { echo "[$(date '+%Y-%m-%d %H:%M:%S')] [INFO] $*"; }
warn() { echo "[$(date '+%Y-%m-%d %H:%M:%S')] [WARN] $*" >&2; }
die()  { echo "[$(date '+%Y-%m-%d %H:%M:%S')] [ERROR] $*" >&2; exit 1; }

command_exists() { command -v "$1" >/dev/null 2>&1; }

validate_ipv4() {
  local ip="$1"
  [[ "$ip" =~ ^([0-9]{1,3}\.){3}[0-9]{1,3}$ ]] || return 1
  IFS='.' read -r a b c d <<< "$ip"
  for o in "$a" "$b" "$c" "$d"; do (( o >= 0 && o <= 255 )) || return 1; done
  return 0
}

require_cmds() {
  local req=(ip awk grep sed ss systemctl sudo ssh pcs mktemp openssl)
  for c in "${req[@]}"; do command_exists "$c" || die "Missing required command: $c"; done
}

normalize_csv() {
  echo "$1" | awk -F',' '{
    out="";
    for(i=1;i<=NF;i++){
      gsub(/^[ \t]+|[ \t]+$/, "", $i);
      if($i!=""){ out=(out=="" ? $i : out","$i); }
    }
    print out
  }'
}

validate_cluster_password() {
  local pass="$1" user="$2" host="$3"
  [[ ${#pass} -ge 12 ]] || die "Cluster password must be at least 12 chars."
  local lp lu lh
  lp="$(printf '%s' "$pass" | tr '[:upper:]' '[:lower:]')"
  lu="$(printf '%s' "$user" | tr '[:upper:]' '[:lower:]')"
  lh="$(printf '%s' "$host" | tr '[:upper:]' '[:lower:]')"
  [[ "$lp" != *"$lu"* ]] || die "Password must not contain username."
  [[ "$lp" != *"$lh"* ]] || die "Password must not contain hostname."
}

wait_for_pcsd() {
  log "Waiting for pcsd socket initialization (Port 2224)..."
  for _ in {1..20}; do
    if ss -tln | grep -q ":2224"; then
      log "pcsd daemon is listening on 2224."
      return 0
    fi
    sleep 1
  done
  return 1
}

cleanup_cluster_state() {
  log "Shutting down pacemaker/corosync services..."
  sudo systemctl stop pacemaker corosync pcsd 2>/dev/null || true
  log "Killing any remaining services..."
  sudo pkill -f pacemaker 2>/dev/null || true
  sudo pkill -f corosync 2>/dev/null || true
  log "Removing all cluster configuration files..."
  echo "yes" | sudo pcs cluster destroy >/dev/null 2>&1 || true
  sudo rm -f /var/lib/pcsd/pcs_settings.conf /var/lib/pcsd/pcs_known_hosts /var/lib/pcsd/tokens \
             /etc/corosync/corosync.conf /etc/corosync/authkey /etc/pacemaker/authkey
}

restart_pcsd() {
  sudo systemctl daemon-reload
  sudo systemctl enable pcsd
  sudo systemctl restart pcsd
  wait_for_pcsd || die "pcsd failed to bind/listen on port 2224"
}

configure_hacluster_password() {
  local pass="$1"
  [[ -n "$pass" ]] || die "Empty cluster password not allowed"
  log "Setting local hacluster credentials..."
  echo "hacluster:$pass" | sudo chpasswd || die "Failed to set hacluster password"
}

pcs_local_auth() {
  log "Authenticating local PCS client..."
  # interactive prompt avoids password in process args
  sudo pcs client local-auth -u hacluster
}

pcs_host_auth_with_retry() {
  local hosts=("$@")
  local out rc
  out="$(sudo pcs host auth "${hosts[@]}" -u hacluster 2>&1)" && rc=0 || rc=$?
  echo "$out"
  if (( rc == 0 )); then return 0; fi
  if echo "$out" | grep -qi "newer known-hosts"; then
    warn "Known-hosts desync detected; retrying pcs host auth once..."
    sleep 1
    sudo pcs host auth "${hosts[@]}" -u hacluster
    return 0
  fi
  return "$rc"
}

remote_add_node_idempotent() {
  local ssh_user="$1" master_ip="$2" local_ip="$3"

  log "Requesting node add on master (interactive auth may be required on master)..."
  ssh -t "${ssh_user}@${master_ip}" "
set -e
sudo pcs host auth '$local_ip' -u hacluster || true
OUT2=\$(sudo pcs cluster node add '$local_ip' --start --enable 2>&1) || RC=\$?
echo \"\$OUT2\"
if echo \"\$OUT2\" | grep -qiE 'already used|already exists|already a member|is already part'; then exit 0; fi
if [ -n \"\${RC:-}\" ] && [ \"\$RC\" -ne 0 ]; then exit \"\$RC\"; fi
"
}

resolve_heartbeat_script() {
  local script_dir="$1"
  local hb="$script_dir/ha_heartbeat.sh"
  [[ -f "$hb" ]] || return 1
  chmod +x "$hb" || true
  echo "$hb"
}

install_heartbeat_service() {
  local script_dir="$1"
  local hb_script
  hb_script="$(resolve_heartbeat_script "$script_dir")" || die "Missing heartbeat script: $script_dir/ha_heartbeat.sh"

  read -r -p "Enter cluster node IP list (comma-separated, no spaces): " HB_NODES
  [[ -n "$HB_NODES" ]] || die "Node list cannot be empty"

  IFS=',' read -r -a arr <<< "$HB_NODES"
  for ip in "${arr[@]}"; do validate_ipv4 "$ip" || die "Invalid node IP in list: $ip"; done

  sudo tee /etc/systemd/system/ha-heartbeat.service >/dev/null <<EOF
[Unit]
Description=HArmadillium Heartbeat Monitor
After=network-online.target
Wants=network-online.target

[Service]
Type=simple
User=root
WorkingDirectory=$script_dir
ExecStart=$hb_script --nodes "$HB_NODES" --check-tcp --tcp-ports "22,2224" --check-pcs --check-corosync --summary-every 10
Restart=always
RestartSec=2

[Install]
WantedBy=multi-user.target
EOF

  sudo systemctl daemon-reload
  sudo systemctl enable --now ha-heartbeat.service
  log "Heartbeat service installed and started."
}

render_template() {
  local template="$1"
  local output="$2"
  shift 2
  [[ -f "$template" ]] || die "Template not found: $template"

  local tmp
  tmp="$(mktemp)"
  cp "$template" "$tmp"

  for kv in "$@"; do
    local key="${kv%%=*}"
    local val="${kv#*=}"
    local ph="{{${key}}}"
    awk -v ph="$ph" -v rep="$val" '{gsub(ph, rep)}1' "$tmp" > "${tmp}.new"
    mv "${tmp}.new" "$tmp"
  done

  sudo mkdir -p "$(dirname "$output")"
  sudo cp "$tmp" "$output"
  rm -f "$tmp"
}

ensure_nginx_ssl_defaults() {
  local node_name="$1" node_ip="$2"
  local cert="/etc/nginx/ssl/server.crt" key="/etc/nginx/ssl/server.key"

  sudo mkdir -p /etc/nginx/ssl
  sudo chmod 700 /etc/nginx/ssl
  sudo chown root:root /etc/nginx/ssl

  if [[ -d "$REPO_ROOT/ssl" ]]; then
    [[ -f "$REPO_ROOT/ssl/server.crt" ]] && sudo cp -f "$REPO_ROOT/ssl/server.crt" "$cert"
    [[ -f "$REPO_ROOT/ssl/server.key" ]] && sudo cp -f "$REPO_ROOT/ssl/server.key" "$key"
  fi

  if [[ ! -f "$cert" || ! -f "$key" ]]; then
    warn "Default NGINX cert/key missing. Generating self-signed pair..."
    sudo openssl req -x509 -nodes -newkey rsa:2048 -days 365 \
      -keyout "$key" -out "$cert" \
      -subj "/C=US/ST=NA/L=NA/O=HArmadillium/OU=Cluster/CN=${node_name}" \
      -addext "subjectAltName=DNS:${node_name},IP:${node_ip}" >/dev/null 2>&1
  fi

  sudo chown root:root "$cert" "$key"
  sudo chmod 644 "$cert"
  sudo chmod 600 "$key"
}

ensure_apache_ssl_defaults() {
  local node_name="$1" node_ip="$2"
  local cert="/etc/apache2/ssl/server.crt" key="/etc/apache2/ssl/server.key"

  sudo mkdir -p /etc/apache2/ssl
  sudo chmod 700 /etc/apache2/ssl
  sudo chown root:root /etc/apache2/ssl

  if [[ -d "$REPO_ROOT/ssl" ]]; then
    [[ -f "$REPO_ROOT/ssl/server.crt" ]] && sudo cp -f "$REPO_ROOT/ssl/server.crt" "$cert"
    [[ -f "$REPO_ROOT/ssl/server.key" ]] && sudo cp -f "$REPO_ROOT/ssl/server.key" "$key"
  fi

  if [[ ! -f "$cert" || ! -f "$key" ]]; then
    warn "Default Apache cert/key missing. Generating self-signed pair..."
    sudo openssl req -x509 -nodes -newkey rsa:2048 -days 365 \
      -keyout "$key" -out "$cert" \
      -subj "/C=US/ST=NA/L=NA/O=HArmadillium/OU=Cluster/CN=${node_name}" \
      -addext "subjectAltName=DNS:${node_name},IP:${node_ip}" >/dev/null 2>&1
  fi

  sudo chown root:root "$cert" "$key"
  sudo chmod 644 "$cert"
  sudo chmod 600 "$key"
}

run_stage3_nginx_dynamic() {
  local repo_root="$1"
  local template="$repo_root/nginx/default.template"
  [[ -f "$template" ]] || die "Missing template: $template"

  log "Installing NGINX stack..."
  sudo apt update
  sudo apt install -y nginx openssl git

  local node_name node_ip ups
  read -r -p "Enter NODE_NAME (example: thinclient03 or node-05): " node_name
  [[ -n "$node_name" ]] || node_name="$(hostname -s)"

  read -r -p "Enter NODE_IP [${DETECTED_IP}]: " node_ip
  node_ip="${node_ip:-$DETECTED_IP}"
  validate_ipv4 "$node_ip" || die "Invalid NODE_IP: $node_ip"

  read -r -p "Enter upstream backends (comma-separated ip:port): " ups
  ups="$(normalize_csv "$ups")"
  [[ -n "$ups" ]] || die "Upstream backend list cannot be empty"

  local upstream_backends=""
  IFS=',' read -r -a UP_ARR <<< "$ups"
  for u in "${UP_ARR[@]}"; do
    upstream_backends+="server $u max_fails=3 fail_timeout=10s;"
    upstream_backends+=$'\n    '
  done

  ensure_nginx_ssl_defaults "$node_name" "$node_ip"
  local ssl_cert="/etc/nginx/ssl/server.crt" ssl_key="/etc/nginx/ssl/server.key"

  local dst_dir="/etc/nginx/sites-enabled" dst="$dst_dir/default"
  local backup_dir="/etc/nginx/backup-harmadillium-$(date +%Y%m%d-%H%M%S)"

  sudo mkdir -p "$backup_dir"
  if compgen -G "$dst_dir/*" >/dev/null; then sudo cp -a "$dst_dir/." "$backup_dir/" || true; fi

  sudo rm -f "$dst_dir"/default_cp "$dst_dir"/default.bak "$dst_dir"/default.old "$dst_dir"/default-* "$dst_dir"/*~ || true

  log "Rendering template -> $dst"
  render_template "$template" "$dst" \
    "NODE_NAME=$node_name" \
    "NODE_IP=$node_ip" \
    "UPSTREAM_BACKENDS=$upstream_backends" \
    "SSL_CERT=$ssl_cert" \
    "SSL_KEY=$ssl_key"

  if ! sudo nginx -t; then
    warn "NGINX validation failed. Restoring backup..."
    sudo rm -rf "$dst_dir"/*
    if compgen -G "$backup_dir/*" >/dev/null; then sudo cp -a "$backup_dir/." "$dst_dir/"; fi
    sudo nginx -t || true
    die "NGINX config test failed after render. Rolled back."
  fi

  sudo systemctl enable nginx
  sudo systemctl restart nginx
  log "Stage 3 complete: Dynamic NGINX template applied safely."
}

run_stage3_apache_dynamic() {
  local repo_root="$1"
  local template="$repo_root/apache/000-default.conf.template"
  [[ -f "$template" ]] || die "Missing template: $template"

  log "Installing Apache stack..."
  sudo apt update
  sudo apt install -y apache2 openssl git

  local node_name node_ip primary_upstream
  read -r -p "Enter NODE_NAME (example: thinclient03 or node-05): " node_name
  [[ -n "$node_name" ]] || node_name="$(hostname -s)"

  read -r -p "Enter NODE_IP [${DETECTED_IP}]: " node_ip
  node_ip="${node_ip:-$DETECTED_IP}"
  validate_ipv4 "$node_ip" || die "Invalid NODE_IP: $node_ip"

  read -r -p "Enter PRIMARY_UPSTREAM (example 10.0.2.161:3000): " primary_upstream
  [[ -n "$primary_upstream" ]] || die "PRIMARY_UPSTREAM cannot be empty"

  ensure_apache_ssl_defaults "$node_name" "$node_ip"
  local ssl_cert="/etc/apache2/ssl/server.crt" ssl_key="/etc/apache2/ssl/server.key"

  local dst="/etc/apache2/sites-available/000-default.conf"
  local backup="/etc/apache2/sites-available/000-default.conf.bak.$(date +%Y%m%d-%H%M%S)"
  [[ -f "$dst" ]] && sudo cp "$dst" "$backup"

  render_template "$template" "$dst" \
    "NODE_NAME=$node_name" \
    "PRIMARY_UPSTREAM=$primary_upstream" \
    "SSL_CERT=$ssl_cert" \
    "SSL_KEY=$ssl_key"

  sudo a2enmod ssl proxy proxy_http proxy_wstunnel headers rewrite >/dev/null 2>&1 || true
  sudo a2ensite 000-default >/dev/null 2>&1 || true

  if ! sudo apache2ctl configtest; then
    warn "Apache config test failed. Restoring backup..."
    [[ -f "$backup" ]] && sudo cp "$backup" "$dst"
    sudo apache2ctl configtest || true
    die "Apache config test failed after render. Rolled back."
  fi

  sudo systemctl enable apache2
  sudo systemctl restart apache2
  log "Stage 3 complete: Dynamic Apache template applied safely."
}

run_stage3() {
  local repo_root="$1"
  read -r -p "Select stack [1=NGINX, 2=APACHE]: " WEB_CHOICE
  case "$WEB_CHOICE" in
    1) run_stage3_nginx_dynamic "$repo_root" ;;
    2) run_stage3_apache_dynamic "$repo_root" ;;
    *) die "Invalid selection: choose 1 or 2" ;;
  esac
}

require_cmds

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"

NETIF="$(ip -o -4 route show to default | awk '{print $5}' | head -n1 || true)"
DETECTED_IP="$(ip route get 1.1.1.1 2>/dev/null | awk '{for(i=1;i<=NF;i++) if($i=="src"){print $(i+1); exit}}' || true)"

if [[ -z "${DETECTED_IP:-}" ]]; then
  warn "Could not auto-detect local IP."
  read -r -p "Enter this node private IPv4: " DETECTED_IP
fi
validate_ipv4 "$DETECTED_IP" || die "Invalid detected/local IP: $DETECTED_IP"

echo "Target Interface : ${NETIF:-unknown}"
echo "Detected IP      : $DETECTED_IP"
echo "----------------------------------------------------------"
read -r -p "Is this Genesis Master node? (y/n): " IS_MASTER

CURRENT_USER="$(whoami)"
CURRENT_HOST="$(hostname -s)"
read -s -r -p "Enter secure password for hacluster user: " CLUSTER_PASS
echo
[[ -n "$CLUSTER_PASS" ]] || die "Cluster password cannot be empty"
validate_cluster_password "$CLUSTER_PASS" "$CURRENT_USER" "$CURRENT_HOST"

log "Installing cluster dependencies..."
sudo apt update
sudo apt install -y corosync pacemaker pcs ufw fail2ban openssh-client

if [[ "$IS_MASTER" =~ ^[Yy]$ ]]; then
  log "Initializing Genesis Master configuration..."
  cleanup_cluster_state
  restart_pcsd
  configure_hacluster_password "$CLUSTER_PASS"
  sleep 1
  pcs_local_auth
  log "Authorizing local identities..."
  pcs_host_auth_with_retry "$DETECTED_IP" "$(hostname)"
  log "Creating single-node cluster..."
  sudo pcs cluster setup HArmadillium "$DETECTED_IP" --force
  sudo pcs cluster start --all
  sudo pcs cluster enable --all
  sudo pcs property set stonith-enabled=false
  sudo pcs property set no-quorum-policy=ignore
  echo "=========================================================="
  echo "✅ SUCCESS: Genesis Master initialized."
  echo "=========================================================="
else
  log "Preparing to join existing cluster..."
  read -r -p "Enter Genesis Master private IPv4: " MASTER_IP
  validate_ipv4 "$MASTER_IP" || die "Invalid master IP: $MASTER_IP"
  CURRENT_SSH_USER="$(whoami)"
  read -r -p "Enter SSH user for Master [${CURRENT_SSH_USER}]: " INPUT_USER
  SSH_USER="${INPUT_USER:-$CURRENT_SSH_USER}"

  cleanup_cluster_state
  restart_pcsd
  configure_hacluster_password "$CLUSTER_PASS"
  sleep 1
  pcs_local_auth

  log "Authenticating local + master identities (interactive)..."
  pcs_host_auth_with_retry "$MASTER_IP" "$DETECTED_IP" "$(hostname)"

  if remote_add_node_idempotent "$SSH_USER" "$MASTER_IP" "$DETECTED_IP"; then
    log "Join request completed (or node already present)."
  else
    die "Join request failed on master side."
  fi

  sudo systemctl restart pcsd
  sudo pcs cluster enable --all 2>/dev/null || true
  sudo pcs cluster start --all 2>/dev/null || true

  echo "=========================================================="
  echo "✅ SUCCESS: Node join flow completed."
  echo "=========================================================="
fi

echo
read -r -p "Run Stage 3 service configuration now? (y/n): " RUN_STAGE3
[[ "$RUN_STAGE3" =~ ^[Yy]$ ]] && run_stage3 "$REPO_ROOT" || log "Skipping Stage 3."

echo
read -r -p "Install heartbeat monitor as systemd service now? (y/n): " INSTALL_HB
[[ "$INSTALL_HB" =~ ^[Yy]$ ]] && install_heartbeat_service "$SCRIPT_DIR" || log "Skipping heartbeat service installation."

unset CLUSTER_PASS
echo "=========================================================="
echo " HArmadillium installer completed.                        "
echo "=========================================================="
