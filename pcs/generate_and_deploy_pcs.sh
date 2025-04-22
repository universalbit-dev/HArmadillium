#!/bin/bash
#===============================================================================
# Title: generate_and_deploy_pcs.sh
# Description: Automates part of the High Availability (HA) cluster setup using 
#              pcs and pcsd, with validation for proper configuration and 
#              graceful error handling.
# Author: universalbit-dev
# Date: 2025-04-22
# Version: 1.3
# Usage: ./generate_and_deploy_pcs.sh
# Notes: Ensure corosync.conf is correctly configured with the remote nodes.
#===============================================================================

# Exit immediately on any error
set -e

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

# Function to gracefully handle errors
graceful_exit() {
  echo "An error occurred. Gracefully shutting down..."
  exit 1
}

# Trap any error and execute graceful_exit
trap graceful_exit ERR

# Function to validate hostnames and IP addresses
validate_hosts_and_ips() {
  local hosts=()
  local ips=()
  local retries=3
  local valid_input=false

  while [[ $retries -gt 0 && $valid_input == false ]]; do
    echo "Enter the hostnames (comma-separated, e.g., armadillium01,armadillium02,armadillium03,armadillium04):"
    read -r hostnames
    echo "Enter the corresponding IP addresses (comma-separated, e.g., 192.168.1.141,192.168.1.142,192.168.1.143,192.168.1.144):"
    read -r ip_addresses

    # Convert input to arrays
    IFS=',' read -r -a hosts <<< "$hostnames"
    IFS=',' read -r -a ips <<< "$ip_addresses"

    # Validate array lengths match
    if [[ ${#hosts[@]} -ne ${#ips[@]} ]]; then
      echo "Error: The number of hostnames does not match the number of IP addresses. Please try again."
      ((retries--))
      continue
    fi

    # Validate IP addresses format
    local invalid_ip=false
    for ip in "${ips[@]}"; do
      if ! [[ $ip =~ ^([0-9]{1,3}\.){3}[0-9]{1,3}$ ]]; then
        echo "Error: Invalid IP format detected: $ip. Please try again."
        invalid_ip=true
        break
      fi
    done

    if [[ $invalid_ip == true ]]; then
      ((retries--))
      continue
    fi

    # All validations passed
    valid_input=true
  done

  if [[ $valid_input == false ]]; then
    echo "Error: Invalid input after 3 retries. Exiting."
    exit 1
  fi

  echo "Validated hostnames and IP addresses successfully."
  REQUIRED_HOSTS=("${hosts[@]}")
  REQUIRED_IPS=("${ips[@]}")
}

# Prompt user for hostnames and IP addresses
echo "Configure cluster nodes:"
validate_hosts_and_ips

# Ensure pcs and pcsd are installed
check_and_install_package "pcs"
check_and_install_package "pcsd"

# Start pcsd service
echo "Starting pcsd service..."
sudo systemctl enable pcsd
sudo systemctl start pcsd

# Validate corosync configuration
echo "Validating corosync.conf..."
COROSYNC_CONFIG_FILE="/etc/corosync/corosync.conf"
if [[ ! -f "$COROSYNC_CONFIG_FILE" ]]; then
  echo "Error: corosync.conf not found at $COROSYNC_CONFIG_FILE."
  exit 1
fi

for i in "${!REQUIRED_HOSTS[@]}"; do
  if ! grep -q "${REQUIRED_HOSTS[$i]}" "$COROSYNC_CONFIG_FILE" || ! grep -q "${REQUIRED_IPS[$i]}" "$COROSYNC_CONFIG_FILE"; then
    echo "Error: Missing configuration for ${REQUIRED_HOSTS[$i]} (${REQUIRED_IPS[$i]}) in corosync.conf."
    exit 1
  fi
done
echo "corosync.conf is properly configured."

# Set hacluster password and authenticate localhost
echo "Setting hacluster password..."
sudo passwd hacluster

echo "Authenticating localhost..."
sudo pcs client local-auth

# Authenticate cluster nodes
echo "Authenticating cluster nodes..."
sudo pcs host auth "${REQUIRED_HOSTS[@]}"

# Disable STONITH and set no-quorum policy
echo "Disabling STONITH and setting no-quorum policy..."
sudo pcs property set stonith-enabled=false
sudo pcs property set no-quorum-policy=ignore

# Create WebServer Resource
echo "Installing resource-agents-extra..."
check_and_install_package "resource-agents-extra"

echo "Creating WebServer Resource..."
sudo pcs resource create webserver ocf:heartbeat:nginx configfile=/etc/nginx/nginx.conf op monitor timeout="5s" interval="5s"

# Prompt for Floating IP Resource
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

# Notify the user about the specific scope of completion
echo "Finished configuring pcs and pcsd. Additional configurations may be required to complete the HA cluster setup."
