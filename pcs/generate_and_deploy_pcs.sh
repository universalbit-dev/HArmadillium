#!/bin/bash

# Function to check if a package is installed
check_and_install_package() {
  PACKAGE_NAME=$1
  if ! dpkg -l | grep -q "$PACKAGE_NAME"; then
    echo "$PACKAGE_NAME is not installed. Installing..."
    sudo apt update
    sudo apt install -y "$PACKAGE_NAME"
  else
    echo "$PACKAGE_NAME is already installed."
  fi
}

# Function to prompt user input
prompt_input() {
  read -p "$1: " user_input
  echo $user_input
}

# Check and install pcs and pcsd
check_and_install_package "pcs"
check_and_install_package "pcsd"

# Start pcsd service
echo "Starting pcsd service..."
sudo systemctl enable pcsd
sudo systemctl start pcsd

# Set hacluster password and authenticate localhost
echo "Setting hacluster password..."
sudo passwd hacluster

echo "Authenticating localhost..."
sudo pcs client local-auth

# Prompt for cluster nodes
PRIMARY_NODE=$(prompt_input "Enter the primary node (e.g., armadillium01)")
CLUSTER_NODES=$(prompt_input "Enter the cluster nodes (comma-separated, e.g., armadillium01,armadillium02,armadillium03,armadillium04)")

# Authenticate cluster nodes
echo "Authenticating cluster nodes..."
sudo pcs host auth $CLUSTER_NODES

# Disable STONITH and set no-quorum policy
echo "Disabling STONITH and setting no-quorum policy..."
sudo pcs property set stonith-enabled=false
sudo pcs property set no-quorum-policy=ignore

# Create WebServer Resource
echo "Installing resource-agents-extra..."
sudo apt install -y resource-agents-extra

echo "Creating WebServer Resource..."
sudo pcs resource create webserver ocf:heartbeat:nginx configfile=/etc/nginx/nginx.conf op monitor timeout="5s" interval="5s"

# Create Floating IP Resource
FLOATING_IP=$(prompt_input "Enter the floating IP (e.g., 192.168.1.140)")
CIDR_NETMASK=$(prompt_input "Enter the CIDR netmask (e.g., 32)")

echo "Creating Floating IP Resource..."
sudo pcs resource create virtual_ip ocf:heartbeat:IPaddr2 ip=$FLOATING_IP cidr_netmask=$CIDR_NETMASK op monitor interval=30s

# Add Constraints
echo "Adding constraints..."
sudo pcs constraint colocation add webserver with virtual_ip INFINITY
sudo pcs constraint order webserver then virtual_ip

# Start and enable the cluster
echo "Starting and enabling the cluster on all nodes..."
sudo pcs cluster start --all
sudo pcs cluster enable --all

echo "Cluster setup complete."
