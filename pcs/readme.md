### `generate_and_deploy_pcs.sh`

```bash
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
CLUSTER_NAME=$(prompt_input "Enter the cluster name (e.g., HArmadillium)")
CLUSTER_NODES=$(prompt_input "Enter the cluster nodes (space-separated, e.g., armadillium01 armadillium02 armadillium03 armadillium04)")

# Initialize and start the cluster
echo "Initializing the cluster..."
sudo pcs cluster setup "$CLUSTER_NAME" $CLUSTER_NODES

echo "Starting the cluster on all nodes..."
sudo pcs cluster start --all

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

# Enable the cluster on all nodes
echo "Enabling the cluster on all nodes..."
sudo pcs cluster enable --all

echo "PCS cluster setup completed successfully."
```

### Explanation
1. **Package Installation**: Checks if `pcs` and `pcsd` are installed, and installs them if missing.
2. **Start pcsd Service**: Enables and starts the `pcsd` service.
3. **Cluster Initialization**: Prompts the user for cluster name and nodes, then sets up and starts the cluster.
4. **Disable STONITH and Configure Policies**: Sets `stonith-enabled=false` and `no-quorum-policy=ignore`.
5. **Resource Creation**: Creates resources for a webserver (`nginx`) and a floating IP.
6. **Constraints**: Adds constraints for resource colocation and ordering.
7. **Enable Cluster**: Enables the cluster on all nodes to start automatically.

### How to Use
1. Save the script as `generate_and_deploy_pcs.sh`.
2. Make it executable:
   ```bash
   chmod +x generate_and_deploy_pcs.sh
   ```
3. Run the script:
   ```bash
   ./generate_and_deploy_pcs.sh
   ```
4. Follow the prompts to input required information for the cluster setup.
