#!/bin/bash

# ===============================================================
# Script Name: generate_and_deploy_corosync.sh
# Description: Automates the generation and deployment of the Corosync 
#              configuration file (corosync.conf) for setting up an HA cluster.
#
# Enhanced for `totem` configuration with additional parameters:
# - cluster_name, transport, interface, nodelist, logging, and service sections.
#
# Usage:
#   ./generate_and_deploy_corosync.sh
#
# Prerequisites:
# - Corosync must be installed on all nodes.
# - SSH access must be configured between nodes.
# ===============================================================

# Variables
OUTPUT_CONF="corosync.conf"                     # Output configuration file name
LOG_FILE="corosync_setup.log"                   # Log file for debugging
CLUSTER_NODES=()
PRIMARY_NODE=""
SSH_USER=""
CLUSTER_NAME="HArmadillium"
TRANSPORT="udpu"
BINDNETADDR=""
MCASTPORT="5405"
LOGFILE="/var/log/corosync/corosync.log"

# Function to log messages
log_message() {
    local MESSAGE="$1"
    echo "$(date '+%Y-%m-%d %H:%M:%S') - $MESSAGE" | tee -a "$LOG_FILE"
}

# Function to check prerequisites
check_prerequisites() {
    log_message "Checking prerequisites..."
    command -v scp >/dev/null 2>&1 || { log_message "Error: 'scp' command not found."; exit 1; }
    command -v ssh >/dev/null 2>&1 || { log_message "Error: 'ssh' command not found."; exit 1; }
    log_message "All prerequisites are met."
}

# Step 1: Prompt the User for Input
prompt_user_input() {
    log_message "Prompting user for input..."

    # Prompt for bindnetaddr
    while true; do
        echo "Enter the bindnetaddr (e.g., 192.168.1.140):"
        read -r BINDNETADDR
        if [[ -n "$BINDNETADDR" ]]; then
            break
        else
            echo "Invalid input. Please try again."
        fi
    done

    # Prompt for cluster nodes
    while true; do
        echo "Enter the cluster nodes (comma-separated, e.g., 192.168.1.141,192.168.1.142,...):"
        read -r CLUSTER_NODES_INPUT
        if [[ -n "$CLUSTER_NODES_INPUT" ]]; then
            IFS=',' read -r -a CLUSTER_NODES <<< "$CLUSTER_NODES_INPUT"
            break
        else
            echo "Invalid input. Please try again."
        fi
    done

    log_message "User input received. Cluster nodes: ${CLUSTER_NODES[*]}, bindnetaddr: $BINDNETADDR"
}

# Step 2: Generate corosync.conf
generate_corosync_conf() {
    log_message "Generating corosync.conf..."

    cat > "$OUTPUT_CONF" <<EOL
totem {
  version: 2
  cluster_name: ${CLUSTER_NAME}
  transport: ${TRANSPORT}
  interface {
    ringnumber: 0
    bindnetaddr: ${BINDNETADDR}
    broadcast: yes
    mcastport: ${MCASTPORT}
  }
}
nodelist {
EOL

    # Add each cluster node to the nodelist
    NODE_ID=1
    for node in "${CLUSTER_NODES[@]}"; do
        echo "  node {" >> "$OUTPUT_CONF"
        echo "    ring0_addr: ${node}" >> "$OUTPUT_CONF"
        echo "    name: armadillium0${NODE_ID}" >> "$OUTPUT_CONF"
        echo "    nodeid: ${NODE_ID}" >> "$OUTPUT_CONF"
        echo "  }" >> "$OUTPUT_CONF"
        NODE_ID=$((NODE_ID + 1))
    done

    cat >> "$OUTPUT_CONF" <<EOL
}
logging {
  to_logfile: yes
  logfile: ${LOGFILE}
  to_syslog: yes
  timestamp: on
}
service {
  name: pacemaker
  ver: 1
}
EOL

    log_message "Corosync configuration file generated: ${OUTPUT_CONF}"
}

# Step 3: Deploy corosync.conf to the remote node
deploy_corosync_conf() {
    log_message "Deploying corosync.conf..."
    while true; do
        echo "Please specify the SSH username (e.g., root, ubuntu):"
        read -r SSH_USER
        if [[ -n "$SSH_USER" ]]; then
            break
        else
            echo "Invalid input. Please try again."
        fi
    done

    while true; do
        echo "Please specify the remote node (hostname or IP, e.g., node2 or 192.168.1.2):"
        read -r REMOTE_NODE
        if [[ -n "$REMOTE_NODE" ]]; then
            break
        else
            echo "Invalid input. Please try again."
        fi
    done

    if scp "$OUTPUT_CONF" "${SSH_USER}@${REMOTE_NODE}:/etc/corosync/corosync.conf"; then
        log_message "Configuration file successfully copied to $REMOTE_NODE."
        if ssh "${SSH_USER}@${REMOTE_NODE}" "sudo systemctl restart corosync && sudo systemctl enable corosync"; then
            log_message "Corosync service restarted and enabled on $REMOTE_NODE."
        else
            log_message "Error: Failed to restart Corosync service on $REMOTE_NODE."
            exit 1
        fi
    else
        log_message "Error: Failed to copy configuration file to $REMOTE_NODE."
        exit 1
    fi
}

# Main Execution
main() {
    log_message "Starting Corosync configuration setup..."
    check_prerequisites
    prompt_user_input
    generate_corosync_conf
    deploy_corosync_conf
    log_message "Corosync configuration setup completed successfully."
}

main
