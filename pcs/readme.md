---

### Introduction to PCS

[PCS](https://packages.debian.org/buster/pcs) (Pacemaker Configuration System) is a tool designed to simplify the management of high-availability clusters. It allows users to easily view, modify, and create Pacemaker-based clusters. `PCS` also includes `pcsd`, a GUI and remote server component, which enhances the cluster management experience by providing a more accessible interface for administrators. 

---
### [`generate_and_deploy_pcs.sh`](https://github.com/universalbit-dev/HArmadillium/blob/main/pcs/generate_and_deploy_pcs.sh)

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
