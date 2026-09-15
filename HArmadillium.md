[![Hyperledger](https://img.shields.io/badge/hyperledger-2F3134?style=for-the-badge&logo=hyperledger&logoColor=white)](https://www.lfdecentralizedtrust.org/)
![Debian](https://img.shields.io/badge/Debian-D70A53?style=for-the-badge&logo=debian&logoColor=white)
![Ubuntu](https://img.shields.io/badge/Ubuntu-E95420?style=for-the-badge&logo=ubuntu&logoColor=white)

##### [Support UniversalBit Project](https://github.com/universalbit-dev/universalbit-dev/tree/main/support) -- [Disambiguation](https://en.wikipedia.org/wiki/Wikipedia:Disambiguation) --

---

## 📊 High Availability Cluster Setup 

* **ThinClient Setup:** [Armadillium](https://github.com/universalbit-dev/armadillium)
* **Guide Concept:** [What is High Availability?](https://www.digitalocean.com/community/tutorials/what-is-high-availability)

### Quick Navigation
* [Prerequisites & Package Installation](#prerequisites--package-installation)
* [Network & Node Setup](#network--node-setup)
* [Corosync Engine Configuration](#corosync-engine-configuration)
* [PCS: Pacemaker Configuration System](#pcs-pacemaker-configuration-system)
* [Creating Resources & High Availability IP](#creating-resources--high-availability-ip)
* [Web Server & SSL Setup (Nginx)](#web-server--ssl-setup-nginx)
* [Troubleshooting Guide](#troubleshooting-guide)

---
<div id="prerequisites--package-installation"></div>
## 🛠️ Prerequisites & Package Installation

This document complements the `ha_cluster_setup.sh` script by detailing the manual configurations needed to complete the HA cluster configuration process.

### Python 3
* **Note:** Deadsnakes **PPA** supports Ubuntu 24.04 (Noble).
```bash
sudo add-apt-repository ppa:deadsnakes/ppa
sudo apt update
sudo apt install python3.11 python3-pip

```

### Required Cluster Packages (Ubuntu 24.04 LTS)

Run the following command on **every node** in the cluster:

```bash
sudo apt install --no-install-recommends corosync pacemaker fence-agents crmsh pcs cluster-glue ufw nginx haveged heartbeat openssh-server openssh-client resource-agents-extra -y

```

---
<div id="network--node-setup"></div>
## 🌐 Network & Node Setup

### 1. Static IP Address

Ensure that each node is configured with a static IP address following the [FreeCodeCamp Static IP Guide](https://www.freecodecamp.org/news/setting-a-static-ip-in-ubuntu-linux-ip-address-tutorial/).

* **Assigned Node IPs:** `192.168.1.141` through `192.168.1.144`
* **Virtual/Floating IP (VIP):** `192.168.1.140` *(must be outside your static DHCP range)*

### 2. UFW Firewall Rules for Each Node

Allow internal cluster traffic and secure shell access:

```bash
sudo ufw allow from 192.168.1.141
sudo ufw allow from 192.168.1.142
sudo ufw allow from 192.168.1.143
sudo ufw allow from 192.168.1.144
sudo ufw allow ssh
sudo ufw enable

```

---

<div id="corosync-engine-configuration"></div>
## ⚙️ Corosync Engine Configuration

The Corosync Cluster Engine provides group communication and membership tracking for High Availability.

### 1. Configuration File Setup (`/etc/corosync/corosync.conf`)

Replace the configuration file on **each node**. *(Note: `bindnetaddr` targets the local subnet interface, **not** the VIP address).*

```bash
sudo rm /etc/corosync/corosync.conf
sudo nano /etc/corosync/corosync.conf

```

```text
totem {
  version: 2
  cluster_name: HArmadillium
  transport: udpu
  interface {
    ringnumber: 0
    bindnetaddr: 192.168.1.0
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

### 2. Generate and Distribute Cryptographic Authentication Keys

Run these steps **only on `armadillium01**`:

```bash
sudo corosync-keygen

# Secure copy the authkey to the other nodes /tmp directory
sudo scp /etc/corosync/authkey armadillium02@192.168.1.142:/tmp/
sudo scp /etc/corosync/authkey armadillium03@192.168.1.143:/tmp/
sudo scp /etc/corosync/authkey armadillium04@192.168.1.144:/tmp/

```

Move and secure the keys on **nodes 02, 03, and 04**:

```bash
sudo mv /tmp/authkey /etc/corosync/
sudo chown root:root /etc/corosync/authkey
sudo chmod 400 /etc/corosync/authkey

```

---
<div id="pcs-pacemaker-configuration-system"></div>
## 🧩 PCS: Pacemaker Configuration System

### 1. Start the PCS Daemon & Set Passwords

On **all nodes**, enable and start `pcsd`:

```bash
sudo systemctl enable --now pcsd
sudo systemctl enable --now corosync
sudo systemctl enable --now pacemaker

```

Create a password for the `hacluster` user on **`armadillium01`**:

```bash
sudo passwd hacluster

```

### 2. Authenticate Cluster Nodes

Authenticate localhost and all nodes from **`armadillium01`**:

```bash
sudo pcs client local-auth
sudo pcs host auth armadillium01 armadillium02 armadillium03 armadillium04 -u hacluster

```

### 3. Baseline Cluster Properties

Configure cluster defaults:

```bash
sudo pcs property set stonith-enabled=false
sudo pcs property set no-quorum-policy=ignore

```

---

<div id="creating-resources--high-availability-ip"></div>
## 📦 Creating Resources & High Availability IP

### 1. Web Server Resource

Create a managed resource for Nginx:

```bash
sudo pcs resource create webserver ocf:heartbeat:nginx configfile=/etc/nginx/nginx.conf op monitor timeout="5s" interval="5s"

```

### 2. Floating IP Resource & Constraints

Set up the single Virtual IP (`192.168.1.140`) and force it to bind to the web server lifecycle:

```bash
sudo pcs resource create virtual_ip ocf:heartbeat:IPaddr2 ip=192.168.1.140 cidr_netmask=32 op monitor interval=30s

# Colocation & Ordering Constraints
sudo pcs constraint colocation add webserver with virtual_ip INFINITY
sudo pcs constraint order virtual_ip then webserver

```

### 3. Start and Enable Cluster Wide Service

```bash
sudo pcs cluster start --all
sudo pcs cluster enable --all

```

---
<div id="web-server--ssl-setup-nginx"></div>
## 🌐 Web Server & SSL Setup (Nginx)

Generate self-signed SSL certificates for secure proxy deployment:

```bash
git clone https://github.com/universalbit-dev/HArmadillium
cd HArmadillium/ssl
sudo mkdir -p /etc/nginx/ssl
sudo openssl req -x509 -nodes -days 365 -newkey rsa:2048 -keyout /etc/nginx/ssl/host.key -out /etc/nginx/ssl/host.cert --config distinguished.cnf
sudo openssl dhparam -out /etc/nginx/ssl/dhparam.pem 2048

```

Apply node-specific configurations for [NGINX](https://github.com/universalbit-dev/HArmadillium/tree/main/nginx).

---
<div id="troubleshooting-guide"></div>
## 🔍 Troubleshooting Guide

### Common Error: 401 Unauthorized via PCSD

```text
Warning: Unable to read the known-hosts file... HTTP error: 401

```

**Fix:** Ensure `pcsd` is running actively across all remote targets:

```bash
ssh user@node-IP "sudo systemctl restart pcsd"

```

### Inspect Cluster Status

```bash
sudo pcs cluster status
sudo pcs property list

```

---

### Resources & References

* [ClusterLabs Documentation](https://clusterlabs.org/pacemaker/doc/2.1/Clusters_from_Scratch/html/index.html)
* [Debian High Availability Wiki](https://wiki.debian.org/Debian-HA)
* [NGINX High Availability Guides](https://docs.nginx.com/nginx/admin-guide/high-availability/)
