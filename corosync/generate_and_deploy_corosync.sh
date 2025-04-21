#!/bin/bash

# ===============================================================
# Script Name: generate_and_deploy_corosync.sh
# Description: This script automates the generation and deployment
#              of the Corosync configuration file (corosync.conf)
#              for setting up a High Availability (HA) cluster.
# 
# Functionality:
# 1. Prompts the user for cluster details (nodes, primary node, etc.).
# 2. Dynamically generates the corosync.conf file using a template.
# 3. Deploys the generated configuration file to a remote node.
# 4. Restarts the Corosync service on the remote node to apply changes.
#
# Usage:
# Run the script and follow the prompts:
#   ./generate_and_deploy_corosync.sh
#
# Prerequisites:
# - Corosync must be installed on all nodes.
# - SSH access must be configured between nodes.
# - A template file (corosync-template.conf) must exist in the same directory.
#
# Repository: https://github.com/universalbit-dev/HArmadillium
# ===============================================================

# Variables
COROSYNC_CONF_TEMPLATE="corosync-template.conf" # Template file for generating corosync.conf
OUTPUT_CONF="corosync.conf"                     # Output configuration file name
SSH_USER="your-ssh-user"                        # Default SSH username (can be overridden in the script)

# Step 1: Prompt the User for Input
prompt_user_input() {
    # Ask the user to define the cluster nodes
    echo "Please define the cluster nodes (comma-separated, e.g., node1,node2,node3,node4):"
    read -r CLUSTER_NODES_INPUT
    IFS=',' read -r -a CLUSTER_NODES <<< "$CLUSTER_NODES_INPUT" # Convert the input to an array

    # Ask the user to define the primary node
    echo "Please define the primary node (e.g., node1):"
    read -r PRIMARY_NODE

    # Display the inputs back to the user for confirmation
    echo "Cluster nodes: ${CLUSTER_NODES[@]}"
    echo "Primary node: $PRIMARY_NODE"
}

# Step 2: Generate corosync.conf
generate_corosync_conf() {
    echo "Generating corosync.conf for the cluster..."
    # Copy the template file to create the output configuration file
    cp ${COROSYNC_CONF_TEMPLATE} ${OUTPUT_CONF}

    # Add each cluster node to the configuration file
    for node in "${CLUSTER_NODES[@]}"; do
        echo "Adding node: $node to corosync.conf"
        sed -i "/{{NODES}}/a\\
        node {\\
            ring0_addr: $node\\
        }" ${OUTPUT_CONF} # Append the node details in the configuration
    done

    # Remove the placeholder {{NODES}} from the configuration file
    sed -i "/{{NODES}}/d" ${OUTPUT_CONF}

    echo "Corosync configuration file generated: ${OUTPUT_CONF}"
}

# Step 3: Deploy corosync.conf to the remote node
deploy_corosync_conf() {
    # Prompt the user for SSH username and the remote node's hostname or IP
    echo "Please specify the SSH username (e.g., root, ubuntu):"
    read -r SSH_USER

    echo "Please specify the remote node (hostname or IP, e.g., node2 or 192.168.1.2):"
    read -r REMOTE_NODE

    echo "Deploying corosync.conf to $REMOTE_NODE as $SSH_USER..."
    # Securely copy the configuration file to the remote node
    scp ${OUTPUT_CONF} ${SSH_USER}@${REMOTE_NODE}:/etc/corosync/corosync.conf

    # Restart the Corosync service on the remote node
    echo "Restarting Corosync service on $REMOTE_NODE..."
    ssh ${SSH_USER}@${REMOTE_NODE} "sudo systemctl restart corosync && sudo systemctl enable corosync"

    echo "Deployment to $REMOTE_NODE completed successfully."
}

# Main Execution
# Call the functions in the appropriate order
prompt_user_input
generate_corosync_conf
deploy_corosync_conf
