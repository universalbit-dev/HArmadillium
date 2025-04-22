### Introduction to PCS

[PCS](https://packages.debian.org/buster/pcs) (Pacemaker Configuration System) is a tool designed to simplify the management of high-availability clusters. It allows users to easily view, modify, and manage cluster configurations.

---
### [`generate_and_deploy_pcs.sh`](https://github.com/universalbit-dev/HArmadillium/blob/main/pcs/generate_and_deploy_pcs.sh)

### Explanation
1. **Package Installation**: Checks if `pcs` and `pcsd` are installed, and installs them if missing.
2. **Start pcsd Service**: Enables and starts the `pcsd` service.
3. **Validation of Cluster Nodes**: Prompts the user to input hostnames and IP addresses for cluster nodes, validates the input (with up to 3 retries), and ensures `corosync.conf` is properly configured.
4. **Cluster Initialization**: Authenticates the cluster nodes and sets up the cluster.
5. **Disable STONITH and Configure Policies**: Sets `stonith-enabled=false` and `no-quorum-policy=ignore`.
6. **Resource Creation**: Creates resources for a webserver (`nginx`) and a floating IP.
7. **Constraints**: Adds constraints for resource colocation and ordering.
8. **Enable Cluster**: Enables the cluster on all nodes to start automatically.

> **Note**: This script completes the `pcs` and `pcsd` setup. Additional configurations may be required for a fully functional High Availability (HA) cluster.

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
4. Follow the prompts to:
   - Enter the hostnames and corresponding IP addresses for cluster nodes.
   - Provide the floating IP and CIDR netmask.
5. Ensure that `corosync.conf` is pre-configured with the correct settings for your cluster nodes.

---

### Additional Information
For more details on configuring `corosync.conf`, refer to the [official Pacemaker documentation](https://clusterlabs.org/pacemaker/doc/).

Errors during execution will be handled gracefully, and any misconfigurations will prompt retries or exit the script cleanly. Ensure you run the script with `sudo` privileges to avoid permission issues.

