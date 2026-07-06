# HArmadillium Core Utilities

📦 **Core Stack Tools**
[![Installer](https://img.shields.io/badge/Utility-dynamic__installer.sh-blue?style=flat-flat&logo=gnu-bash&logoColor=white)](./dynamic_installer.sh)
[![Firewall](https://img.shields.io/badge/Security-ha__rules.sh-success?style=flat-flat&logo=linux&logoColor=white)](./ha_rules.sh)
[![Crypto](https://img.shields.io/badge/Crypto-make__certs.sh-blueviolet?style=flat-flat&logo=openssl&logoColor=white)](./make_certs.sh)

🚀 **System Status & Architecture**
[![Platform](https://img.shields.io/badge/Ubuntu-24.04%20LTS-orange?style=flat-flat&logo=ubuntu&logoColor=white)](https://ubuntu.com)
[![Cluster manager](https://img.shields.io/badge/HA-Pacemaker%20%2B%20Corosync-red?style=flat-flat)](https://clusterlabs.org)
[![Firewall Engine](https://img.shields.io/badge/Firewall-UFW%20Optimized-darkgreen?style=flat-flat)](https://launchpad.net/ufw)

---

## 🛠️ Script Overview

This directory contains the core automation and security orchestration scripts for managing high-availability clusters.

*   **`dynamic_installer.sh`**: Automates package installation (`corosync`, `pacemaker`, `pcs`, `ufw`, `fail2ban`) and configures cluster pairing or automated node-joining workflows.
*   **`ha_rules.sh`**: Orchestrates strict UFW firewall boundaries, dynamically mapping out all active nodes in the cluster matrix to protect communication channels.
*   **`make_certs.sh`**: Generates 2048-bit RSA self-signed TLS/SSL credentials validating internal cluster host configurations and IP mappings.

---

## 📊 Deployment Pipeline Diagram

```text
==========================================================================================
                      THIN CLIENT HA SETUP PIPELINE (Ubuntu 24.04 LTS) 
==========================================================================================

 [THIN CLIENT 01: GENESIS MASTER]
    ├── 1. Onboard Status: Ubuntu 24.04 LTS Ready
    ├── 2. git clone repository
    ├── 3. cd HArmadillium/utility
    ├── 4. Run ./dynamic_installer.sh  ---> (Select: 'y' to initialize cluster)
    ├── 5. Run ./make_certs.sh         ---> (Generates cluster-wide TLS assets)
    └── 6. Run ./ha_rules.sh           ---> (Applies secure master UFW rules)
            │
            │  Orchestrate Peer Clones over Network
            ▼
[THIN CLIENT 02 to N: PEER JOINERS]
    ├── 1. SSH into target node (Ubuntu 24.04 LTS Onboard)
    ├── 2. git clone repository
    ├── 3. cd HArmadillium/utility
    ├── 4. Run ./dynamic_installer.sh  ---> (Select: 'n' -> script auto-detects local IP -> enter <MASTER_IP> when prompted)
    └── 5. Run ./ha_rules.sh           ---> (Execute: ./ha_rules.sh <MASTER_IP> <LOCAL_IP>)

==========================================================================================
                    [Strict Mesh Network / Unlimited Development]

```

---

## 🚀 Execution & Step-by-Step Guide

Ensure all utility scripts have executable permissions before deployment:

```bash
chmod +x *.sh

```

### 🟢 Phase A: Initializing the Genesis Master Node (`Thin Client 01`)

1. **Clone & Navigate:** Jump into your clean onboard Ubuntu environment, pull the cluster configuration engine, and move to the target path:
```bash
git clone https://github.com/universalbit-dev/HArmadillium.git
cd HArmadillium/utility

```


2. **Launch Node Base:** Execute the primary installer framework:
```bash
./dynamic_installer.sh

```


Choose `y` when prompted if this is your Genesis Master node. The engine clears previous tokens, spins up the `pcsd` backend daemon, assigns local administrative credentials, and forces an isolated single-node architecture cluster configuration.
3. **Generate TLS Certs:** Run the cryptographic certificate generator:
```bash
./make_certs.sh

```


This automatically reads the primary LAN routing table, creates a dynamic configuration, and outputs secure cluster key chains to a local `certs/` folder.
4. **Lock Down Access:** Secure the master network boundaries by executing the rule framework using your Master IP for both arguments:
```bash
./ha_rules.sh <MASTER_IP> <MASTER_IP>

```


This wipes default configurations, guarantees standard management paths on Port 22, and drops unauthenticated synchronization packets.

---

### 🔵 Phase B: Scaling Peer Joiner Nodes (Thin Client 02 to N)

1. **Access Peer Target:** Establish an SSH session into your clean destination thin client.
2. **Pull Workspace:** Duplicate the exact core suite code:

```bash
git clone https://github.com/universalbit-dev/HArmadillium.git
cd HArmadillium/utility

```

3. **Execute Cluster Join:** Launch the setup script:

```bash
./dynamic_installer.sh

```

Choose **no** when asked if this is a master node. Enter the static IP address belonging to **Thin Client 01 (Genesis Master)**. The machine will clean its local ecosystem, authenticate mutually with the parent node, and pass secure remote onboarding commands over SSH to insert itself directly into the cluster grid.

4. **Synchronize Firewalls (Thin Client 02 example):** Tie the new node safely into the existing network matrix by providing the master address followed explicitly by the peer's own local identity:


```bash
./ha_rules.sh <MASTER_IP_OF_THINCLIENT_01> <LOCAL_IP_OF_THINCLIENT_02>

```


The engine contacts the master dynamically to gather active node identities, configures a shared communication pool, and shields the Corosync mesh to maintain cluster quorum health safely.
