### How the Script [generate_and_deploy_corosync.sh]() Works
1. **Prompting User Input**:
   - The script asks the user to define:
     - The cluster nodes (comma-separated, e.g., `node1,node2,node3,node4`).
     - The primary node (e.g., `node1`).
     - The SSH username (e.g., `root`, `ubuntu`).
     - The remote node (hostname or IP, e.g., `node2` or `192.168.1.2`).

2. **Generating `corosync.conf`**:
   - The script uses a template file (`corosync-template.conf`) and dynamically updates it with the cluster nodes provided by the user.
   - The `sed` command inserts the node details into the `{{NODES}}` placeholder in the template.

3. **Copying the Configuration**:
   - After generating the `corosync.conf`, the script uses `scp` to securely copy the file to the remote node's `/etc/corosync/` directory.

4. **Restarting Corosync**:
   - Once the `corosync.conf` file is deployed, the script uses `ssh` to connect to the remote node and restart the Corosync service to apply the new configuration.

---

### Why This is Useful
- **Dynamic Cluster Setup**:
  - The script allows flexibility in defining the cluster nodes and primary node at runtime, making it reusable for different setups.
  
- **Centralized Management**:
  - The script runs on a single node (e.g., the primary node) and manages the configuration and deployment for other nodes in the cluster.

- **Automation**:
  - Automating the generation and deployment of `corosync.conf` reduces manual errors and speeds up the setup process.

- **Scalability**:
  - The script can be easily extended to handle more nodes or additional configuration steps.

---

### Example Workflow
1. Run the script:
   ```bash
   ./generate_and_deploy_corosync.sh
   ```

2. Provide the required inputs:
   ```
   Please define the cluster nodes (comma-separated, e.g., node1,node2,node3,node4):
   node1,node2,node3,node4

   Please define the primary node (e.g., node1):
   node1

   Please specify the SSH username (e.g., root, ubuntu):
   ubuntu

   Please specify the remote node (hostname or IP, e.g., node2 or 192.168.1.2):
   192.168.1.2
   ```

3. The script will:
   - Generate a `corosync.conf` file with the specified cluster nodes.
   - Copy the file to `/etc/corosync/` on the remote node (`192.168.1.2`).
   - Restart the Corosync service on the remote node.

---

### Verification
After running the script, verify on the remote node:
1. Check the contents of `/etc/corosync/corosync.conf` to confirm the file was copied correctly.
   ```bash
   cat /etc/corosync/corosync.conf
   ```

2. Check the status of the Corosync service:
   ```bash
   sudo systemctl status corosync
   ```

---
