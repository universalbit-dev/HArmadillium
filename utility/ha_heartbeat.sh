#!/usr/bin/env bash
set -euo pipefail

# ==============================================================================
# HArmadillium HA Heartbeat Monitor (sanitized)
# - Dynamic peer checks from --nodes
# - ICMP + optional TCP + optional UDP
# - Optional local PCS/Corosync snapshots
# - JSONL output for dashboards
# - Secure log permissions
# ==============================================================================

# ---------------------------
# Defaults
# ---------------------------
NODES=""
SELF_IP=""
INTERVAL=3
TIMEOUT=2
FAIL_THRESHOLD=5

CHECK_ICMP=true
CHECK_TCP=false
CHECK_UDP=false
CHECK_PCS=false
CHECK_COROSYNC=false

TCP_PORTS="22,2224"
UDP_PORTS="5404,5405"

LOG_FILE="/var/log/ha_heartbeat.log"
RAW_OUT="/var/log/ha_heartbeat.raw.jsonl"
VERBOSE=false
SUMMARY_EVERY=10

# Optional external action (disabled by default)
FAILOVER_CMD=""

# Internal state
LOOP_COUNT=0
declare -A FAIL_COUNT=()
declare -A LAST_STATE=()
declare -A LAST_REASON=()
declare -A LAST_RTT_MS=()

PCS_OK=null
PCS_SUMMARY=""
COR_OK=null
COR_SUMMARY=""

# ---------------------------
# Helpers
# ---------------------------
print_help() {
  cat <<'EOF'
ha_heartbeat.sh - dynamic HA peer monitor

Required:
  --nodes "IP1,IP2,IP3"

Core options:
  --self-ip IP                  Override local IP auto-detection
  --interval N                  Seconds between loops (default: 3)
  --timeout N                   Probe timeout seconds (default: 2)
  --fail-threshold N            Consecutive misses before DOWN (default: 5)

Checks:
  --no-icmp                     Disable ICMP checks (enabled by default)
  --check-tcp                   Enable TCP checks
  --tcp-ports "22,2224"         TCP port list
  --check-udp                   Enable UDP send checks (best effort)
  --udp-ports "5404,5405"       UDP port list
  --check-pcs                   Include local pcs status snapshot
  --check-corosync              Include local corosync-cfgtool snapshot

Output:
  --log-file PATH               Human log (default: /var/log/ha_heartbeat.log)
  --raw-out PATH                JSONL output (default: /var/log/ha_heartbeat.raw.jsonl)
  --verbose                     Print successful peer checks too
  --summary-every N             Summary loop cadence (default: 10)

Action:
  --failover-cmd "COMMAND"      Optional command on threshold breach
EOF
}

command_exists() { command -v "$1" >/dev/null 2>&1; }
now_iso() { date -u +"%Y-%m-%dT%H:%M:%SZ"; }

log() {
  local level="$1"; shift
  local msg="$*"
  local ts
  ts="$(date '+%Y-%m-%d %H:%M:%S')"
  echo "[$ts] [$level] $msg" | tee -a "$LOG_FILE" >/dev/null
}

die() {
  log "ERROR" "$*"
  exit 1
}

json_escape() {
  local s="${1:-}"
  s="${s//\\/\\\\}"
  s="${s//\"/\\\"}"
  s="${s//$'\n'/\\n}"
  s="${s//$'\r'/\\r}"
  s="${s//$'\t'/\\t}"
  printf '%s' "$s"
}

emit_raw_line() {
  local json="$1"
  echo "$json" >> "$RAW_OUT"
}

detect_self_ip() {
  ip route get 1.1.1.1 2>/dev/null | awk '{for(i=1;i<=NF;i++) if($i=="src"){print $(i+1); exit}}'
}

parse_rtt_ms() {
  awk -F'time=' '/time=/{split($2,a," "); print a[1]; exit}'
}

tcp_probe() {
  local ip="$1" port="$2" t="$3"
  timeout "$t" bash -c "cat < /dev/null > /dev/tcp/$ip/$port" >/dev/null 2>&1
}

udp_probe() {
  local ip="$1" port="$2" t="$3"
  timeout "$t" bash -c "echo -n hb > /dev/udp/$ip/$port" >/dev/null 2>&1
}

run_failover() {
  if [[ -z "$FAILOVER_CMD" ]]; then
    log "WARN" "Threshold reached but no failover command configured."
    return 0
  fi
  log "CRITICAL" "Executing failover command."
  bash -c "$FAILOVER_CMD"
}

collect_cluster_snapshot() {
  PCS_OK=null; PCS_SUMMARY=""
  COR_OK=null; COR_SUMMARY=""

  if [[ "$CHECK_PCS" == true ]]; then
    if command_exists pcs; then
      local out
      out="$(pcs status 2>&1 || true)"
      if echo "$out" | grep -qiE "Cluster name:|Stack:|Online:"; then PCS_OK=true; else PCS_OK=false; fi
      PCS_SUMMARY="$(echo "$out" | head -n 8)"
    else
      PCS_OK=false
      PCS_SUMMARY="pcs command not found"
    fi
  fi

  if [[ "$CHECK_COROSYNC" == true ]]; then
    if command_exists corosync-cfgtool; then
      local out
      out="$(corosync-cfgtool -s 2>&1 || true)"
      if echo "$out" | grep -qiE "LINK ID|Local node ID|ring 0|transport"; then COR_OK=true; else COR_OK=false; fi
      COR_SUMMARY="$(echo "$out" | head -n 8)"
    else
      COR_OK=false
      COR_SUMMARY="corosync-cfgtool command not found"
    fi
  fi
}

print_summary() {
  local peers=("$@")
  local up=0 down=0 unknown=0
  local details=()

  for p in "${peers[@]}"; do
    local st="${LAST_STATE[$p]:-UNKNOWN}"
    case "$st" in
      UP) up=$((up+1)) ;;
      DOWN) down=$((down+1)) ;;
      *) unknown=$((unknown+1)) ;;
    esac
    details+=("$p=$st(miss=${FAIL_COUNT[$p]:-0})")
  done

  log "INFO" "SUMMARY up=$up down=$down unknown=$unknown | ${details[*]}"
}

main() {
  for c in bash ping ip timeout awk grep sed tee; do
    command_exists "$c" || die "Missing command: $c"
  done

  while [[ $# -gt 0 ]]; do
    case "$1" in
      --nodes) NODES="$2"; shift 2 ;;
      --self-ip) SELF_IP="$2"; shift 2 ;;
      --interval) INTERVAL="$2"; shift 2 ;;
      --timeout) TIMEOUT="$2"; shift 2 ;;
      --fail-threshold) FAIL_THRESHOLD="$2"; shift 2 ;;

      --no-icmp) CHECK_ICMP=false; shift ;;
      --check-tcp) CHECK_TCP=true; shift ;;
      --tcp-ports) TCP_PORTS="$2"; shift 2 ;;
      --check-udp) CHECK_UDP=true; shift ;;
      --udp-ports) UDP_PORTS="$2"; shift 2 ;;
      --check-pcs) CHECK_PCS=true; shift ;;
      --check-corosync) CHECK_COROSYNC=true; shift ;;

      --log-file) LOG_FILE="$2"; shift 2 ;;
      --raw-out) RAW_OUT="$2"; shift 2 ;;
      --verbose) VERBOSE=true; shift ;;
      --summary-every) SUMMARY_EVERY="$2"; shift 2 ;;

      --failover-cmd) FAILOVER_CMD="$2"; shift 2 ;;

      -h|--help) print_help; exit 0 ;;
      *) die "Unknown argument: $1" ;;
    esac
  done

  [[ -n "$NODES" ]] || die "--nodes is required"

  if [[ -z "$SELF_IP" ]]; then
    SELF_IP="$(detect_self_ip || true)"
  fi
  [[ -n "$SELF_IP" ]] || die "Could not detect local IP. Use --self-ip"

  IFS=',' read -r -a INPUT_NODES <<< "$NODES"
  peers=()
  for raw in "${INPUT_NODES[@]}"; do
    n="$(echo "$raw" | xargs)"
    [[ -n "$n" ]] || continue
    [[ "$n" == "$SELF_IP" ]] && continue
    peers+=("$n")
  done
  [[ ${#peers[@]} -gt 0 ]] || die "No peer nodes left after excluding self ($SELF_IP)"

  # secure log creation
  umask 077
  touch "$LOG_FILE" "$RAW_OUT" || die "Cannot write to log outputs"
  chmod 600 "$LOG_FILE" "$RAW_OUT" || true

  for p in "${peers[@]}"; do
    FAIL_COUNT["$p"]=0
    LAST_STATE["$p"]="UNKNOWN"
    LAST_REASON["$p"]="init"
    LAST_RTT_MS["$p"]="null"
  done

  IFS=',' read -r -a TCP_ARR <<< "$TCP_PORTS"
  IFS=',' read -r -a UDP_ARR <<< "$UDP_PORTS"

  log "INFO" "Heartbeat started | self=$SELF_IP peers=${peers[*]} interval=${INTERVAL}s timeout=${TIMEOUT}s threshold=${FAIL_THRESHOLD} icmp=${CHECK_ICMP} tcp=${CHECK_TCP} udp=${CHECK_UDP} pcs=${CHECK_PCS} corosync=${CHECK_COROSYNC}"

  emit_raw_line "{\"ts\":\"$(now_iso)\",\"event\":\"startup\",\"self_ip\":\"$SELF_IP\",\"peer_count\":${#peers[@]},\"interval\":$INTERVAL,\"timeout\":$TIMEOUT,\"fail_threshold\":$FAIL_THRESHOLD,\"icmp\":$CHECK_ICMP,\"tcp\":$CHECK_TCP,\"udp\":$CHECK_UDP,\"pcs\":$CHECK_PCS,\"corosync\":$CHECK_COROSYNC}"

  while true; do
    LOOP_COUNT=$((LOOP_COUNT+1))
    collect_cluster_snapshot

    for p in "${peers[@]}"; do
      ts="$(now_iso)"

      ping_ok=true
      rtt_ms="null"
      if [[ "$CHECK_ICMP" == true ]]; then
        ping_out="$(ping -c 1 -W "$TIMEOUT" "$p" 2>&1 || true)"
        if echo "$ping_out" | grep -q "1 received"; then
          rtt="$(echo "$ping_out" | parse_rtt_ms || true)"
          [[ -n "${rtt:-}" ]] && rtt_ms="$rtt"
          ping_ok=true
        else
          ping_ok=false
        fi
      fi

      tcp_ok=true
      tcp_detail=""
      if [[ "$CHECK_TCP" == true ]]; then
        for port in "${TCP_ARR[@]}"; do
          port="$(echo "$port" | xargs)"
          [[ -n "$port" ]] || continue
          if tcp_probe "$p" "$port" "$TIMEOUT"; then tcp_detail+="${port}:open;"
          else tcp_ok=false; tcp_detail+="${port}:closed;"; fi
        done
      fi

      udp_ok=true
      udp_detail=""
      if [[ "$CHECK_UDP" == true ]]; then
        for port in "${UDP_ARR[@]}"; do
          port="$(echo "$port" | xargs)"
          [[ -n "$port" ]] || continue
          if udp_probe "$p" "$port" "$TIMEOUT"; then udp_detail+="${port}:sent;"
          else udp_ok=false; udp_detail+="${port}:error;"; fi
        done
      fi

      healthy=true
      reason="ok"
      if [[ "$CHECK_ICMP" == true && "$ping_ok" == false ]]; then healthy=false; reason="icmp_unreachable"; fi
      if [[ "$healthy" == true && "$CHECK_TCP" == true && "$tcp_ok" == false ]]; then healthy=false; reason="tcp_probe_failed"; fi
      if [[ "$healthy" == true && "$CHECK_UDP" == true && "$udp_ok" == false ]]; then healthy=false; reason="udp_probe_failed"; fi

      if [[ "$healthy" == true ]]; then
        if [[ "${FAIL_COUNT[$p]}" -gt 0 ]]; then
          log "INFO" "Peer $p recovered (missed=${FAIL_COUNT[$p]})"
        elif [[ "$VERBOSE" == true ]]; then
          log "INFO" "Peer $p OK rtt=${rtt_ms}ms tcp=${tcp_ok} udp=${udp_ok}"
        fi
        FAIL_COUNT["$p"]=0
        LAST_STATE["$p"]="UP"
        LAST_REASON["$p"]="ok"
        LAST_RTT_MS["$p"]="$rtt_ms"
      else
        FAIL_COUNT["$p"]=$((FAIL_COUNT[$p]+1))
        LAST_STATE["$p"]="DOWN"
        LAST_REASON["$p"]="$reason"
        LAST_RTT_MS["$p"]="null"
        log "WARN" "Peer $p missed (${FAIL_COUNT[$p]}/${FAIL_THRESHOLD}) reason=$reason"
        if [[ "${FAIL_COUNT[$p]}" -ge "$FAIL_THRESHOLD" ]]; then
          log "CRITICAL" "Peer $p considered DOWN (threshold reached)"
          run_failover || true
          FAIL_COUNT["$p"]=0
        fi
      fi

      emit_raw_line "$(cat <<JSON
{"ts":"$ts","event":"node_check","self_ip":"$SELF_IP","node_ip":"$p","state":"${LAST_STATE[$p]}","reason":"$(json_escape "${LAST_REASON[$p]}")","fail_count":${FAIL_COUNT[$p]},"fail_threshold":$FAIL_THRESHOLD,"icmp_enabled":$CHECK_ICMP,"ping_ok":$ping_ok,"rtt_ms":${LAST_RTT_MS[$p]},"tcp_enabled":$CHECK_TCP,"tcp_ok":$tcp_ok,"tcp_detail":"$(json_escape "$tcp_detail")","udp_enabled":$CHECK_UDP,"udp_ok":$udp_ok,"udp_detail":"$(json_escape "$udp_detail")","pcs_ok":$PCS_OK,"pcs_summary":"$(json_escape "$PCS_SUMMARY")","corosync_ok":$COR_OK,"corosync_summary":"$(json_escape "$COR_SUMMARY")"}
JSON
)"
    done

    if (( SUMMARY_EVERY > 0 )) && (( LOOP_COUNT % SUMMARY_EVERY == 0 )); then
      print_summary "${peers[@]}"
      emit_raw_line "{\"ts\":\"$(now_iso)\",\"event\":\"summary\",\"self_ip\":\"$SELF_IP\",\"loop\":$LOOP_COUNT}"
    fi

    sleep "$INTERVAL"
  done
}

main "$@"
