#!/bin/bash

# ===============================================================
# Script Name: generate_and_deploy_corosync.sh
# Description: Automates the generation and deployment of the Corosync 
#              configuration file (corosync.conf) for setting up an HA cluster.
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
    command -v corosync-keygen >/dev/null 2>&1 || { log_message "Error: 'corosync-keygen' command not found."; exit 1; }
    command -v scp >/dev/null 2>&1 || { log_message "Error: 'scp' command not found."; exit 1; }
    command -v ssh >/dev/null 2>&1 || { log_message "Error: 'ssh' command not found."; exit 1; }
    log_message "All prerequisites are met."
}

# Function to handle corosync key generation
generate_corosync_key() {
    log_message "Generating Corosync authentication key..."
    local attempts=0
    local max_attempts=3

    while (( attempts < max_attempts )); do
        corosync-keygen -l
        if [[ $? -eq 0 ]]; then
            log_message "Corosync authentication key generated successfully."
            return 0
        else
            log_message "Failed to generate Corosync authentication key. Attempt $((attempts + 1)) of $max_attempts."
        fi
        ((attempts++))
    done

    log_message "Maximum attempts to generate Corosync authentication key reached. Shutting down gracefully..."
    exit 1
}

# Function to prompt user for input
prompt_user_input() {
    log_message "Prompting user for input..."
    local attempts=0
    local max_attempts=3

    # Prompt for bindnetaddr
    while (( attempts < max_attempts )); do
        echo "Enter the bindnetaddr (e.g., 192.168.1.140):"
        read -r BINDNETADDR
        if [[ -n "$BINDNETADDR" ]]; then
            break
        else
            echo "Invalid input. Please try again."
        fi
        ((attempts++))
    done

    if (( attempts == max_attempts )); then
        log_message "Maximum invalid input attempts reached. Shutting down gracefully..."
        exit 1
    fi

    # Reset attempts for the next input
    attempts=0

    # Prompt for cluster nodes
    while (( attempts < max_attempts )); do
        echo "Enter the cluster nodes (comma-separated, e.g., 192.168.1.141,192.168.1.142,...):"
        read -r CLUSTER_NODES_INPUT
        if [[ -n "$CLUSTER_NODES_INPUT" ]]; then
            IFS=',' read -r -a CLUSTER_NODES <<< "$CLUSTER_NODES_INPUT"
            break
        else
            echo "Invalid input. Please try again."
        fi
        ((attempts++))
    done

    if (( attempts == max_attempts )); then
        log_message "Maximum invalid input attempts reached. Shutting down gracefully..."
        exit 1
    fi

    log_message "User input received. Cluster nodes: ${CLUSTER_NODES[*]}, bindnetaddr: $BINDNETADDR"
}

# Function to generate corosync.conf
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

# Function to deploy corosync.conf to the remote node
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
    echo "Please specify the remote node (hostname or IP, e.g., armadillium01 or 192.168.1.141):"
    read -r REMOTE_NODE
    if [[ -n "$REMOTE_NODE" ]]; then
        echo "You entered: $REMOTE_NODE. Is this correct? (yes/no)"
        read -r CONFIRM
        if [[ "$CONFIRM" == "yes" ]]; then
            break
        else
            echo "Let's try again."
        fi
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

# Function to generate Corosync authentication key and distribute it
generate_and_distribute_corosync_key() {
    log_message "Generating Corosync authentication key on armadillium01..."
    sudo corosync-keygen
    if [[ $? -ne 0 ]]; then
        log_message "Error: Failed to generate Corosync authentication key."
        exit 1
    fi
    log_message "Corosync authentication key generated successfully."

    # Securely copy the authkey to other cluster nodes
    log_message "Distributing Corosync authentication key to other nodes..."
    local nodes=("armadillium02@192.168.1.142" "armadillium03@192.168.1.143" "armadillium04@192.168.1.144")
    for node in "${nodes[@]}"; do
        sudo scp /etc/corosync/authkey "${node}:/tmp"
        if [[ $? -ne 0 ]]; then
            log_message "Error: Failed to copy Corosync authentication key to ${node}."
            exit 1
        else
            log_message "Authentication key successfully copied to ${node}."
        fi
    done
}

# Main Execution
main() {
    log_message "Starting Corosync configuration setup..."
    check_prerequisites
    generate_corosync_key
    generate_and_distribute_corosync_key
    prompt_user_input
    generate_corosync_conf
    deploy_corosync_conf
    log_message "Corosync configuration setup completed successfully."
}

main
