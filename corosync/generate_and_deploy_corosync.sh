#!/bin/bash

# Variables
COROSYNC_CONF_TEMPLATE="corosync-template.conf" # Template file
OUTPUT_CONF="corosync.conf"
SSH_USER="your-ssh-user"

# Step 1: Prompt the User for Input
prompt_user_input() {
    echo "Please define the cluster nodes (comma-separated, e.g., node1,node2,node3,node4):"
    read -r CLUSTER_NODES_INPUT
    IFS=',' read -r -a CLUSTER_NODES <<< "$CLUSTER_NODES_INPUT" # Convert to array

    echo "Please define the primary node (e.g., node1):"
    read -r PRIMARY_NODE

    echo "Cluster nodes: ${CLUSTER_NODES[@]}"
    echo "Primary node: $PRIMARY_NODE"
}

# Step 2: Generate corosync.conf
generate_corosync_conf() {
    echo "Generating corosync.conf for the cluster..."
    cp ${COROSYNC_CONF_TEMPLATE} ${OUTPUT_CONF}

    # Add cluster nodes to the configuration
    for node in "${CLUSTER_NODES[@]}"; do
        echo "Adding node: $node to corosync.conf"
        sed -i "/{{NODES}}/a\\
        node {\\
            ring0_addr: $node\\
        }" ${OUTPUT_CONF}
    done

    # Remove placeholder
    sed -i "/{{NODES}}/d" ${OUTPUT_CONF}

    echo "Corosync configuration file generated: ${OUTPUT_CONF}"
}

# Step 3: Deploy corosync.conf to the remote node
deploy_corosync_conf() {
    # Prompt the user for SSH username and remote node (hostname or IP)
    echo "Please specify the SSH username (e.g., root, ubuntu):"
    read -r SSH_USER

    echo "Please specify the remote node (hostname or IP, e.g., node2 or 192.168.1.2):"
    read -r REMOTE_NODE

    echo "Deploying corosync.conf to $REMOTE_NODE as $SSH_USER..."
    # Use scp to copy the configuration file to the remote node
    scp ${OUTPUT_CONF} ${SSH_USER}@${REMOTE_NODE}:/etc/corosync/corosync.conf

    # Restart Corosync service on the remote node
    echo "Restarting Corosync service on $REMOTE_NODE..."
    ssh ${SSH_USER}@${REMOTE_NODE} "sudo systemctl restart corosync && sudo systemctl enable corosync"

    echo "Deployment to $REMOTE_NODE completed successfully."
}

# Main Execution
prompt_user_input
generate_corosync_conf
deploy_corosync_conf
