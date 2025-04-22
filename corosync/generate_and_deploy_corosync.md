The `generate_and_deploy_corosync.sh` script operates as follows:

### How the Script Works
1. **Prompting User Input**:
   - The script asks for:
     - Cluster nodes (comma-separated, e.g., `node1,node2,node3,node4`).
     - Primary node (e.g., `node1`).
     - SSH username (e.g., `root`, `ubuntu`).
     - Remote node (hostname or IP, e.g., `node2` or `192.168.1.2`).

2. **Generating `corosync.conf`**:
   - Uses a template (`corosync-template.conf`) and replaces placeholders (e.g., `{{NODES}}`) with user-provided cluster nodes.

3. **Copying the Configuration**:
   - Securely transfers the generated `corosync.conf` to the `/etc/corosync/` directory on the remote node via `scp`.

4. **Restarting Corosync**:
   - Connects to the remote node using `ssh` and restarts the Corosync service to apply the new configuration.

### Why This is Useful
- **Dynamic Cluster Setup**: Customizable cluster definitions at runtime.
- **Centralized Management**: Run from a single node and manage all cluster nodes.
- **Automation**: Reduces manual errors and speeds up setup.
- **Scalability**: Easily extendable to additional nodes or configurations.

### Example Workflow
1. Execute the script:
   ```bash
   ./generate_and_deploy_corosync.sh
   ```
2. Provide inputs as prompted:
   ```
   Define the cluster nodes: node1,node2,node3,node4
   Define the primary node: node1
   SSH username: ubuntu
   Remote node: 192.168.1.2
   ```
3. The script will:
   - Generate `corosync.conf`.
   - Copy it to `/etc/corosync/` on the remote node.
   - Restart the Corosync service on the remote node.

### Verification
1. Check the file on the remote node:
   ```bash
   cat /etc/corosync/corosync.conf
   ```
2. Verify Corosync service status:
   ```bash
   sudo systemctl status corosync
   ```
