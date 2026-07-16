## 📢 Support the UniversalBit Project
Help us grow and continue innovating!  
- [Support the UniversalBit Project](https://github.com/universalbit-dev/universalbit-dev/tree/main/support)  
- [Learn about Disambiguation](https://en.wikipedia.org/wiki/Wikipedia:Disambiguation)  
- [Bash Reference Manual](https://www.gnu.org/software/bash/manual/)

---

#### Unlimited Digital Development Environment for High Availability Clusters
<p align="center"> <img src="docs/assets/images/Bitto_Ascii.png" alt="Bitto mascotte" width="200" /> </p>

---

# High Availability Clusters with HArmadillium

Welcome to **HArmadillium**, an open-source educational and production-ready framework designed to streamline the deployment, optimization, and hardening of High-Availability Linux clusters using Pacemaker, Corosync, Nginx, Apache2, and UFW.

---

## 🗺️ The HArmadillium Learning Roadmap

HArmadillium is architected to support users at different stages of their High Availability journey, dividing the deployment process into two main learning paradigms:

```
  [ Node ]
         │
         ├──► 1: Propedeutic Sandbox (ha_cluster_setup.sh)
         │    └─ Learn local network dependencies, SSL, proxying, and basic security inline.
         │
         └──► 2: Automated Production Grid (utility/)
              └─ Scale out dynamically across a multi-node cluster with decoupled assets.

```

### 🎯 Stage 1: The Propedeutic Sandbox (`ha_cluster_setup.sh`)

For users approaching clustering for the first time who cannot study all component complexities simultaneously. This script serves as a structured, monolithic environment builder.

* **Auto-Discovery:** Automatically fingerprints active network interfaces, local IPs, and gateways to ensure successful onboarding with zero hardcoding.
* **Inline Visualization:** Demystifies how Netplan, UFW firewall boundaries, local self-signed SSL matrices, and Nginx/Apache reverse-proxy loops stack together safely on a single machine before scaling out.

### 🚀 Stage 2: The Decoupled Utility Suite (`utility/`)

Once the baseline architecture is understood, users transition to production utilities for multi-node orchestrations:

* `dynamic_installer.sh`: Handles modular cluster assembly, node handshakes, and role mappings (Genesis Master vs Joiner Peer).
* `ha_rules.sh`: Implements zero-trust security mesh isolation filters across the cluster node grid.
* `make_certs.sh`: Directs the automated dynamic generation of secure cryptographic Subject Alternative Name (SAN) certificate chains.

---

## 🛠️ Step-by-Step Lab Execution Guide

### 📂 Phase 1: Local Node Groundwork (The Sandbox)

To set up a single thin client sandbox node and study the foundational environment components, execute the educational installer from the root repository directory:

```bash
git clone https://github.com/universalbit-dev/HArmadillium.git
cd HArmadillium
sudo ./ha_cluster_setup.sh

```

*This auto-discovers network vectors, sets safe firewall perimeters, initializes an administrative `pcsd` instance, and configures proxy routing boundaries cleanly.*

---

### 🌐 Phase 2: Building the Production Multi-Node Grid (`utility/`)

#### 🟪 Step A: Deploying the Genesis Master Node (Thin Client 01)

1. Navigate into your dedicated utility workspace:
```bash
cd HArmadillium/utility

```


2. Initialize the cluster setup utility:
```bash
sudo ./dynamic_installer.sh

```


3. Respond **yes** when prompted if this machine will act as the Cluster Genesis Master Node.
4. Establish security isolation rules by passing the master's own IP address twice to form the initial single-node secure perimeter loop:
```bash
sudo ./ha_rules.sh <MASTER_IP> <MASTER_IP>

```



#### 🟦 Step B: Scaling and Attaching Joiner Nodes (Thin Client 02 to N)

1. Establish an SSH session to your destination target machine.
2. Clone the core repository suite onto the new system:
```bash
git clone [https://github.com/universalbit-dev/HArmadillium.git](https://github.com/universalbit-dev/HArmadillium.git)
cd HArmadillium/utility

```


3. Run the automated installer:
```bash
sudo ./dynamic_installer.sh

```


4. Choose **no** when prompted if this node is a master. Enter the static IP address belonging to **Thin Client 01 (Genesis Master)**. The machine will mutually authenticate with the parent node and dynamically add itself to the cluster structure.
5. Re-synchronize the secure firewall mesh matrix across your nodes by providing the Master IP followed by the new peer node's local identity:
```bash
sudo ./ha_rules.sh <MASTER_IP_THIN_CLIENT_01> <LOCAL_IP_THIN_CLIENT_02>

```



---

## 📚 Technical Documentation & External Resources

##### Core System Operations

* [HArmadillium Core Architecture Wiki](https://github.com/universalbit-dev/armadillium/blob/main/HArmadillium.md)
* [HA Cluster Setup Overview](https://www.google.com/search?q=https://github.com/universalbit-dev/HArmadillium/blob/main/HArmadillium.md%23ha-cluster-setup)
* [Nginx Load Balancing and Configuration Guide](https://github.com/universalbit-dev/HArmadillium/blob/main/HArmadillium.md#nginx-configuration)
* [Apache Virtual Host Port Bindings Reference](https://github.com/universalbit-dev/HArmadillium/blob/main/HArmadillium.md#webserver)

##### High Availability & Security Infrastructure

* [Pacemaker & Corosync Clusterlabs Home](https://clusterlabs.org)
* [HAProxy Load Balancing Concepts](https://www.digitalocean.com/community/tutorials/an-introduction-to-haproxy-and-load-balancing-concepts)
* [UFW Firewall Administration Reference](https://manpages.ubuntu.com/manpages/bionic/en/man8/ufw.8.html)
* [Fail2Ban Intrusion Defensive Repositories](https://github.com/fail2ban/fail2ban)
* [Cryptographic Implementations with OpenSSL SAN](https://github.com/universalbit-dev/HArmadillium/blob/main/HArmadillium.md#self-signed-certificate-https-with-openssl)

##### Basic Security Containment (Optional Advanced Inspection)

* [SELKS is NOW Clear NDR - Community](https://www.stamus-networks.com/selks-archive)

```

```
