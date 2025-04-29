#### SSH Connection Overview

##### From `armadillium01` to Other Nodes:
- **To `armadillium02`:**
  ```bash
  ssh armadillium02@192.168.1.142
  sudo apt install corosync pacemaker fence-agents crmsh pcs* cluster-glue ufw nginx haveged heartbeat openssh-server
  ```

- **To `armadillium03`:**
  ```bash
  ssh armadillium03@192.168.1.143
  sudo apt install corosync pacemaker fence-agents crmsh pcs* cluster-glue ufw nginx haveged heartbeat openssh-server
  ```

- **To `armadillium04`:**
  ```bash
  ssh armadillium04@192.168.1.144
  sudo apt install corosync pacemaker fence-agents crmsh pcs* cluster-glue ufw nginx haveged heartbeat openssh-server
  ```
  
#### Additional Notes
- Ensure all nodes have SSH installed and configured properly.
- Use appropriate credentials when connecting between nodes.

---
