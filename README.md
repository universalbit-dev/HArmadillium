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

Welcome to **HArmadillium**, an open-source educational and production-ready framework designed to streamline the deployment, optimization, and hardening of High-Availability Linux clusters using Pacemaker, Corosync, PCS, and hardened reverse-proxy service layers.

---

## 🗺️ The HArmadillium Learning Roadmap

HArmadillium is architected to support users at different stages of their High Availability journey.

```text
  [ Node ]
         │
         ├──► 1: Propedeutic Sandbox (ha_cluster_setup.sh)
         │    └─ Learn local network dependencies, SSL, proxying, and basic security inline.
         │
         ├──► 2: Automated Production Grid (utility/)
         │    └─ Bootstrap cluster membership, authentication, and node roles dynamically.
         │
         └──► 3: Extended Per-Node Service Configuration (nginx/, apache/, ssl/)
              └─ Apply the final node-specific webserver and certificate configuration.
```

---

## 🎯 Stage 1: The Propedeutic Sandbox (`ha_cluster_setup.sh`)

For users approaching clustering for the first time who cannot study all component complexities simultaneously, this script serves as a structured monolithic environment builder.

* **Auto-Discovery:** Automatically fingerprints active network interfaces, local IPs, and gateways to ensure successful onboarding with zero hardcoding.
* **Inline Visualization:** Helps explain how Netplan, UFW firewall boundaries, self-signed SSL, and reverse-proxy loops fit together on a single machine before scaling outward.
* **Learning First:** Best suited for understanding the architecture before moving into a multi-node deployment.

---

## 🚀 Stage 2: The Decoupled Utility Suite (`utility/`)

Once the baseline architecture is understood, users can transition to production-oriented utilities for multi-node orchestration.

* `dynamic_installer.sh`: Handles modular cluster assembly, node handshakes, and role mappings (Genesis Master vs Joiner Peer).
* `ha_rules.sh`: Implements zero-trust security mesh isolation filters across the cluster node grid.
* `make_certs.sh`: Automates generation of secure Subject Alternative Name (SAN) certificate chains.

### What Stage 2 does
Stage 2 is designed to reduce the most confusing early steps of a cluster deployment, including:

- required package installation
- interface and IP discovery
- local and remote `pcsd` authentication
- cluster bootstrap on the Genesis Master node
- secure join workflow for peer nodes

### What Stage 2 does not replace
Stage 2 does **not** replace the final per-node service configuration.  
After cluster bootstrap, each node still needs its extended webserver configuration.

---

## 🌐 Stage 3: Extended Per-Node Service Configuration

Stage 3 is the missing final service layer that completes the deployment.

After running the utility scripts, apply the node-specific webserver configuration for the machine you are configuring. This includes:

- installing and enabling the webserver layer
- generating or installing SSL certificates
- applying the correct node-specific configuration file
- validating the configuration
- starting the service and integrating it with the HA resource design

### NGINX node configurations

Use the configuration file that matches your node identity:

- Node 01: `nginx/01/default`
- Node 02: `nginx/02/default`
- Node 03: `nginx/03/default`
- Node 04: `nginx/04/default`

Example for **Node 01**:

```bash
sudo apt install openssl nginx git -y
sudo mkdir -p /etc/nginx/ssl
sudo rm -f /etc/nginx/sites-enabled/default
sudo cp nginx/01/default /etc/nginx/sites-enabled/default
sudo nginx -t
sudo systemctl restart nginx
```

If needed, generate the SSL assets from the repository `ssl/` directory before starting NGINX.

### Apache node configurations

As an alternative to NGINX, you can use the Apache node-specific files:

- Node 01: `apache/01/000-default.conf`
- Node 02: `apache/02/000-default.conf`
- Node 03: `apache/03/000-default.conf`
- Node 04: `apache/04/000-default.conf`

### Stage 3 summary

In short:

1. **Stage 1** teaches and prepares the local environment.
2. **Stage 2** bootstraps the cluster and node relationships.
3. **Stage 3** applies the final node-specific service configuration.

This means `utility/dynamic_installer.sh` is intended to simplify bootstrap, while `nginx/01/default`, `nginx/02/default`, `nginx/03/default`, and `nginx/04/default` provide the complete extended configuration for each node.

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

---

#### 🟦 Step B: Scaling and Attaching Joiner Nodes (Thin Client 02 to N)

1. Establish an SSH session to your destination target machine.

2. Clone the core repository suite onto the new system:
```bash
git clone https://github.com/universalbit-dev/HArmadillium.git
cd HArmadillium/utility
```

3. Run the automated installer:
```bash
sudo ./dynamic_installer.sh
```

4. Choose **no** when prompted if this node is a master. Enter the static IP address belonging to **Thin Client 01 (Genesis Master)**. The machine will authenticate with the parent node and join the cluster.

5. Re-synchronize the secure firewall mesh matrix across your nodes by providing the Master IP followed by the new peer node's local identity:
```bash
sudo ./ha_rules.sh <MASTER_IP_THIN_CLIENT_01> <LOCAL_IP_THIN_CLIENT_02>
```

---

### 🧩 Phase 3: Apply the Extended Node Configuration

After cluster bootstrap is complete, apply the correct node-specific configuration for the service layer.

For example, on **Node 01**:

```bash
cd HArmadillium
sudo cp nginx/01/default /etc/nginx/sites-enabled/default
sudo nginx -t
sudo systemctl restart nginx
```

Repeat using the matching file for Node 02, Node 03, or Node 04 as needed.

---

## 📚 Technical Documentation & External Resources

##### Core System Operations

* [HArmadillium Core Architecture Wiki](HArmadillium.md)
* [Nginx Load Balancing and Configuration Guide](HArmadillium.md#nginx-configuration)
* [Apache Virtual Host Port Bindings Reference](HArmadillium.md#webserver)

##### High Availability & Security Infrastructure

* [Pacemaker & Corosync Clusterlabs Home](https://clusterlabs.org)
* [HAProxy Load Balancing Concepts](https://www.digitalocean.com/community/tutorials/an-introduction-to-haproxy-and-load-balancing-concepts)
* [UFW Firewall Administration Reference](https://manpages.ubuntu.com/manpages/bionic/en/man8/ufw.8.html)
* [Fail2Ban Intrusion Defensive Repositories](https://github.com/fail2ban/fail2ban)
* [Cryptographic Implementations with OpenSSL SAN](HArmadillium.md#self-signed-certificate-https-with-openssl)

##### Basic Security Containment (Optional Advanced Inspection)

* [SELKS is NOW Clear NDR - Community](https://www.stamus-networks.com/selks-archive)
