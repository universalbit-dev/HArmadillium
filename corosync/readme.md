

# HArmadillium

High Availability Clusters: Development requires a digital working environment. Create your Software, Application, WebPage, static, and dynamic content.

## Features
This repository supports the configuration and management of High Availability Clusters using tools like **PCS** and **Corosync**.

---

## Corosync

[Corosync](https://packages.debian.org/sid/corosync) is a Cluster Engine Daemon and Utility that plays a critical role in implementing high availability clusters. Below is a summary of Corosync's features and setup.

### Overview
The Corosync Cluster Engine is a Group Communication System that provides:
- **Process Group Communication**: Virtual synchrony guarantees for creating replicated state machines.
- **Availability Management**: Restarts the application process upon failure.
- **Configuration and Statistics Database**: An in-memory database for managing cluster data.
- **Quorum System**: Notifies applications when quorum is achieved or lost.

### Configuration Steps
1. **Create Configuration File**:
   Edit the Corosync configuration file on all cluster nodes:
   ```bash
   sudo nano /etc/corosync/corosync.conf
   ```

2. **Example Configuration**:
   Below is an example configuration for the node `armadillium01`. Repeat similar configurations for other nodes:
   ```bash
   totem {
     version: 2
     cluster_name: HArmadillium
     transport: udpu
     interface {
       ringnumber: 0
       bindnetaddr: 192.168.1.140
       broadcast: yes
       mcastport: 5405
     }
   }
   nodelist {
     node {
       ring0_addr: 192.168.1.141
       name: armadillium01
       nodeid: 1
     }
     node {
       ring0_addr: 192.168.1.142
       name: armadillium02
       nodeid: 2
     }
     node {
       ring0_addr: 192.168.1.143
       name: armadillium03
       nodeid: 3
     }
     node {
       ring0_addr: 192.168.1.144
       name: armadillium04
       nodeid: 4
     }
   }
   logging {
     to_logfile: yes
     logfile: /var/log/corosync/corosync.log
     to_syslog: yes
     timestamp: on
   }
   service {
     name: pacemaker
     ver: 1
   }
   ```

3. **Authentication Setup**:
   - On `armadillium01`, generate an authentication key:
     ```bash
     sudo corosync-keygen
     ```
   - Securely copy the key to each node:
     ```bash
     sudo scp /etc/corosync/authkey armadillium02@192.168.1.142:/tmp
     sudo scp /etc/corosync/authkey armadillium03@192.168.1.143:/tmp
     sudo scp /etc/corosync/authkey armadillium04@192.168.1.144:/tmp
     ```
   - Move the key to the Corosync directory on each node and set appropriate permissions:
     ```bash
     sudo mv /tmp/authkey /etc/corosync
     sudo chown root: /etc/corosync/authkey
     sudo chmod 400 /etc/corosync/authkey
     ```

### Notes
- Ensure all nodes have consistent configurations.
- Verify that the `authkey` file permissions prevent unauthorized access.

---
