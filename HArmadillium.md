[![Hyperledger](https://img.shields.io/badge/hyperledger-2F3134?style=for-the-badge&logo=hyperledger&logoColor=white)](https://www.lfdecentralizedtrust.org/)
![Debian](https://img.shields.io/badge/Debian-D70A53?style=for-the-badge&logo=debian&logoColor=white)
![Ubuntu](https://img.shields.io/badge/Ubuntu-E95420?style=for-the-badge&logo=ubuntu&logoColor=white)
##### [Support UniversalBit Project](https://github.com/universalbit-dev/universalbit-dev/tree/main/support) -- [Disambiguation](https://en.wikipedia.org/wiki/Wikipedia:Disambiguation) -- [Bash Reference Manual](https://www.gnu.org/software/bash/manual/html_node/index.html) -- [Join Mastodon](https://mastodon.social/invite/wTHp2hSD) -- [Website](https://www.universalbit.it/) -- [Content Delivery Network](https://www.universalbitcdn.it/)

---
* [ThinClient] Setup:[Armadillium](https://github.com/universalbit-dev/armadillium)
<img src="https://github.com/universalbit-dev/HArmadillium/blob/main/docs/assets/images/ecosystem_gran_canaria_edited.png" width="auto" />

* ## [What is High Availability?](https://www.digitalocean.com/community/tutorials/what-is-high-availability)


**Required Packages**: Lists necessary software like `python3`, `corosync`, `pacemaker`, `fence-agents`, `crmsh`, `pcs`, `nginx`, and more.

* [Static IP](#StaticIP)
* [Host setup](#Host)
* [SSH connections](#SSH)
* [Corosync](#Corosync)
* [PCMK file](#PCMK)
* [CRM](#CRM)
* [PCS Setup](#PCS)
* [WebServer](#WebServer)
* [PaceMaker](#PaceMaker)
* [Firewall UFW](#UFW)

This document complements the `ha_cluster_setup.sh` script by detailing the manual configurations and additional setups needed to complete the HA cluster configuration process.

### [Learn More About High Availability](https://ubuntu.com/server/docs/introduction-to-high-availability)
---

### [Python3](https://www.python.org/) 
note:
--Deadsnakes <strong>PPA</strong> has already updated its support for Ubuntu 24.04 (Noble)
```bash
sudo add-apt-repository ppa:deadsnakes/ppa
sudo apt update
sudo apt install python3.11
sudo python3 -m ensurepip --upgrade
```
##### Alternative Python Setup:
* [Download and Compile Python3](https://www.python.org/downloads/)
* [Get Pip Py](https://pip.pypa.io/en/stable/installation/#get-pip-py)
* [Getting Started setup-building](https://devguide.python.org/getting-started/setup-building/index.html)
  

For **Ubuntu 24.04 LTS (Noble)**, install the following packages:  
```bash
sudo apt install corosync pacemaker fence-agents crmsh pcs* cluster-glue ufw nginx haveged heartbeat openssh-server openssh-client
```

### Static IP

**[Setup Static IP Address](https://www.freecodecamp.org/news/setting-a-static-ip-in-ubuntu-linux-ip-address-tutorial/)**  

Ensure that each node is configured with a static IP address by following the setup guide linked above.

### Host

**Edit the Host File for Each Node**  
To configure the host file on each node, use the following command:  
```bash
sudo nano /etc/hosts
```

**Reference:**  
- [Setup Instructions](https://github.com/universalbit-dev/HArmadillium/blob/main/host/readme.md)  

**Note:** Ensure that the host file is properly edited and configured on every node.


### UFW Firewall Rules for Each Node

The Uncomplicated Firewall (UFW) is a user-friendly front-end for managing iptables, simplifying the process of configuring a Netfilter firewall. It provides a command-line interface with syntax inspired by OpenBSD's Packet Filter, making it an excellent choice for a host-based firewall.

**Commands for Configuration:**
```bash
sudo ufw allow from 192.168.1.141
sudo ufw allow from 192.168.1.142
sudo ufw allow from 192.168.1.143
sudo ufw allow from 192.168.1.144
sudo ufw allow ssh
```

**Note:**  
Ensure that these firewall rules are applied to each node to maintain proper network access and security.

### SSH Connection to Communicate with All Nodes

**OpenSSH**  
Ensure that each node has SSH enabled to allow secure communication between nodes. OpenSSH is a widely-used tool for managing secure shell (SSH) connections, providing encryption for data transfer and remote command execution.

**References:**
- [OpenSSH Documentation](https://www.openssh.com/)
- [SSH Essentials](https://www.ssh.com/academy/ssh)

**Note:**  
To maintain proper connectivity, verify that SSH is enabled and properly configured on all nodes.

---

## Corosync
* [Corosync](https://packages.debian.org/sid/corosync) cluster engine daemon and utilities
##### The Corosync Cluster Engine is a Group Communication System with additional features for implementing high availability within applications. 
##### The project provides four C Application Programming Interface features:

 * A closed process group communication model with virtual synchrony
   guarantees for creating replicated state machines.
 * A simple availability manager that restarts the application process
   when it has failed.
 * A configuration and statistics in-memory database that provide the
   ability to set, retrieve, and receive change notifications of
   information.
 * A quorum system that notifies applications when quorum is achieved
   or lost.

#### Corosync Configuration File: repeat this TO [each node](https://github.com/universalbit-dev/HArmadillium/tree/main/corosync)
```bash
sudo rm /etc/corosync/corosync.conf
sudo nano /etc/corosync/corosync.conf
```
corosync configuration file:
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
```
sudo service corosync start
```
---
---
#### Corosync-keygen Authorize

* FROM armadillium01 create corosync key :
```bash
#armadillium01 
sudo corosync-keygen
```
* secure copy(ssh) corosync authkey <strong>FROM</strong> armadillium01 <strong>TO</strong> #armadillium02 #armadillium03 #armadillium04 <strong>IN</strong> /tmp directory 
```bash
sudo scp /etc/corosync/authkey armadillium02@192.168.1.142:/tmp #02
sudo scp /etc/corosync/authkey armadillium03@192.168.1.143:/tmp #03
sudo scp /etc/corosync/authkey armadillium04@192.168.1.144:/tmp #04
```
* connect via(ssh) and move copied file <strong>FROM</strong> /tmp directory <strong>TO</strong> /etc/corosync directory 
```bash
#connect(ssh) to armadillium02 
ssh armadillium02@192.168.1.142 #02
sudo mv /tmp/authkey /etc/corosync
sudo chown root: /etc/corosync/authkey
sudo chmod 400 /etc/corosync/authkey
```
[corosync setup](https://github.com/universalbit-dev/HArmadillium/tree/main/corosync)

---

## PCS: Pacemaker Configuration System  

PCS simplifies the management of Pacemaker-based clusters, allowing users to easily view, modify, and create clusters. It also includes `pcsd`, which acts as both a graphical user interface (GUI) and a remote server for managing PCS.

### Start the PCS Service
```bash
sudo service pcsd start
```

### Set Password and Authenticate Localhost
#### Create Password for `hacluster` User
```bash
# On armadillium01
sudo passwd hacluster
```

#### Authenticate Localhost
```bash
sudo pcs client local-auth
# Username: hacluster
# Password:
# localhost: Authorized
```

### Authorize/Authenticate Hosts
#### Authenticate Cluster Nodes
```bash
# On armadillium01
sudo pcs host auth armadillium01 armadillium02 armadillium03 armadillium04
# Username: hacluster
# Password:
# armadillium01: Authorized
# armadillium02: Authorized
# armadillium03: Authorized
# armadillium04: Authorized
```

**Reference:**  
[ClusterLabs: Enable pcs Daemon](https://clusterlabs.org/pacemaker/doc/2.1/Clusters_from_Scratch/html/cluster-setup.html) (3.3.2. Enable pcs Daemon)

---

### PCS Cluster Configuration  

#### Disable STONITH
```bash
sudo pcs property set stonith-enabled=false
```

#### Ignore Quorum Policy
```bash
sudo pcs property set no-quorum-policy=ignore
```

---

### Create Resources
#### Install Required Resource Agents
```bash
sudo apt install resource-agents-extra
```

#### Create Web Server Resource
```bash
sudo pcs resource create webserver ocf:heartbeat:nginx configfile=/etc/nginx/nginx.conf op monitor timeout="5s" interval="5s"
```

**Reference:**  
[PCS Create Resources](https://www.golinuxcloud.com/create-cluster-resource-in-ha-cluster-examples/)  
[ClusterLabs Resource Agents](https://github.com/ClusterLabs/resource-agents)

---

### Create Floating IP Resource
#### Add Floating IP
```bash
sudo pcs resource create virtual_ip ocf:heartbeat:IPaddr2 ip=192.168.1.140 cidr_netmask=32 op monitor interval=30s
```

#### Add Constraints
##### Colocation Constraint
```bash
sudo pcs constraint colocation add webserver with virtual_ip INFINITY
```

##### Order Constraint
```bash
sudo pcs constraint order webserver then virtual_ip
# Adding webserver virtual_ip (kind: Mandatory) (Options: first-action=start then-action=start)
```

---

### Start and Enable the Cluster
```bash
sudo pcs cluster start --all
sudo pcs cluster enable --all
# armadillium01: Starting Cluster...
# armadillium02: Starting Cluster...
# armadillium03: Starting Cluster...
# armadillium04: Starting Cluster...
# armadillium01: Cluster Enabled
# armadillium02: Cluster Enabled
# armadillium03: Cluster Enabled
# armadillium04: Cluster Enabled
```

**Note:**  
- For additional details, refer to [ClusterLabs Enable pcs Daemon](https://clusterlabs.org/pacemaker/doc/deprecated/en-US/Pacemaker/2.0/html/Clusters_from_Scratch/_enable_pcs_daemon.html).
  
## CRM 
#### Consider this configuration tool as an alternative to PCS.
[Setup](https://crmsh.github.io/start-guide/)

---

---
## Pacemaker
## Cluster Resource Manager:
-Description:
Pacemaker is a distributed finite state machine capable of co-ordinating the startup and recovery of inter-related services across a set of machines.
Pacemaker understands many different resource types (OCF, SYSV, systemd) and can accurately model the relationships between them (colocation, ordering).

##### Run Pacemaker after corosync service: TO each node
```bash
sudo update-rc.d pacemaker defaults 20 01
```
---
## PCMK

#### Create the PCMK Configuration File
1. Create the necessary directory and file:
   ```bash
   sudo mkdir /etc/corosync/service.d
   sudo nano /etc/corosync/service.d/pcmk
   ```

2. Add the following content to the file:
   ```bash
   service {
     name: pacemaker
     ver: 1
   }
   ```
## Webserver

#### Nginx as a Reverse Proxy
Install the necessary packages for setting up Nginx as a reverse proxy:  
```bash
sudo apt install openssl nginx git -y
```

**Reference:**  
[OpenSSL WebServer](https://nginx.org/en/docs/http/configuring_https_servers.html)

### Self-Signed Certificate (HTTPS) with OpenSSL
Generate a self-signed certificate using OpenSSL:
```bash
git clone https://github.com/universalbit-dev/HArmadillium/
cd HArmadillium/ssl
sudo mkdir /etc/nginx/ssl
sudo openssl req -x509 -nodes -days 365 -newkey rsa:2048 -keyout /etc/nginx/ssl/host.key -out /etc/nginx/ssl/host.cert --config distinguished.cnf
sudo openssl dhparam -out /etc/nginx/ssl/dhparam.pem 2048
```

---

## Nginx Configuration

Edit the default Nginx configuration file:
```bash
sudo rm /etc/nginx/sites-enabled/default
sudo nano /etc/nginx/sites-enabled/default
```

### Webserver Nginx Node Configuration
Refer to the node-specific Nginx configuration files:  
- [Node 01 Configuration](https://github.com/universalbit-dev/HArmadillium/blob/main/nginx/01/default)  
- [Node 02 Configuration](https://github.com/universalbit-dev/HArmadillium/blob/main/nginx/02/default)  
- [Node 03 Configuration](https://github.com/universalbit-dev/HArmadillium/blob/main/nginx/03/default)  
- [Node 04 Configuration](https://github.com/universalbit-dev/HArmadillium/blob/main/nginx/04/default)  

Start the Nginx service:
```bash
sudo service nginx start
```

---

## Alternative Webserver: Apache High Availability

For an alternative to Nginx, you can use Apache to set up high availability. Start by installing Apache and the required packages:  

```bash
sudo apt update
sudo apt install apache2 libapache2-mod-ssl ssl-cert -y
```
### Self-Signed Certificate (HTTPS) with OpenSSL for Apache
Generate a self-signed certificate for Apache:
```bash
git clone https://github.com/universalbit-dev/HArmadillium/
cd HArmadillium/ssl
sudo mkdir /etc/apache2/ssl
sudo openssl req -x509 -nodes -days 365 -newkey rsa:2048 -keyout /etc/apache2/ssl/host.key -out /etc/apache2/ssl/host.cert --config distinguished.cnf
sudo openssl dhparam -out /etc/apache2/ssl/dhparam.pem 2048
```
Once installed, you can proceed to configure Apache for high availability.  

Refer to the following resources for configuration files:  
- [Node 01 Configuration](https://github.com/universalbit-dev/HArmadillium/blob/main/apache/01/000-default.conf)  
- [Node 02 Configuration](https://github.com/universalbit-dev/HArmadillium/blob/main/apache/02/000-default.conf)  
- [Node 03 Configuration](https://github.com/universalbit-dev/HArmadillium/blob/main/apache/03/000-default.conf)  
- [Node 04 Configuration](https://github.com/universalbit-dev/HArmadillium/blob/main/apache/04/000-default.conf)  

For more details, visit the [Apache High Availability Documentation](https://activemq.apache.org/components/artemis/documentation/latest/ha).  

Start the Apache2 service:
```bash
sudo service apache2 start
```


**Reference:**  
- [ClusterLabs: Apache HTTP Server as a Cluster Service](https://clusterlabs.org/pacemaker/doc/deprecated/en-US/Pacemaker/1.1/html/Clusters_from_Scratch/ch06.html)  

---


### Virtual IP (VIP) Configuration for High Availability

To ensure optimal High Availability (HA) performance, it is highly recommended to use a **single Virtual IP (VIP)** for your web server configuration. A VIP simplifies failover management by directing traffic to the active node, which is managed by clustering software like Pacemaker.

For advanced configurations, including load balancing across multiple nodes, ensure proper health checks and synchronization of all nodes. Full details are available in the [VIP Configuration Guide](https://github.com/universalbit-dev/HArmadillium/blob/main/vip.md).

---

### Troubleshooter

#### Common Error:
```bash
**Error**
Warning: Unable to read the known-hosts file: No such file or directory: '/var/lib/pcsd/known-hosts'
armadillium03: Unable to authenticate to armadillium03 - (HTTP error: 401)...
armadillium01: Unable to authenticate to armadillium01 - (HTTP error: 401)...
armadillium04: Unable to authenticate to armadillium04 - (HTTP error: 401)...
armadillium02: Unable to authenticate to armadillium02 - (HTTP error: 401)...
```

#### Cause:
The **PCSD service** is not started.

#### Fix:
Start the PCSD service on the affected node(s):
```bash
# On armadillium02
ssh armadillium02@192.168.1.142
sudo service pcsd start
sudo service pcsd status
```

---

#### Check PCSD Cluster Status:
```bash
sudo pcs cluster status
```
Example Output:
```bash
  * armadillium03: Online
  * armadillium04: Online
  * armadillium02: Online
  * armadillium01: Online
```

---

#### View Cluster Property List for Each Node:
```bash
sudo pcs property list
```

#### Example Output:
```bash
Cluster Properties:
cluster-infrastructure: corosync
cluster-name: HArmadillium
dc-version: 2.0.5
have-watchdog: false
no-quorum-policy: ignore
stonith-enabled: false
```

---

### Your HACluster is now configured and ready to host something amazing!

#### Resources:
* [Clusters_from_Scratch](https://clusterlabs.org/pacemaker/doc/2.1/Clusters_from_Scratch/html/index.html)
* [NGINX High Availability](https://docs.nginx.com/nginx/admin-guide/high-availability/)
* [Apache High Availability](https://activemq.apache.org/components/artemis/documentation/latest/ha)
* [ClusterLabs Apache HTTP Server as a Cluster Service](https://clusterlabs.org/pacemaker/doc/deprecated/en-US/Pacemaker/1.1/html/Clusters_from_Scratch/ch06.html)
* [HA](https://wiki.debian.org/Debian-HA) 
* [Debian-HA](https://wiki.debian.org/Debian-HA/ClustersFromScratch)
* [Cluster-Labs](https://clusterlabs.org/)
* [Nginx High Availability](https://www.howtoforge.com/tutorial/how-to-set-up-nginx-high-availability-with-pacemaker-corosync-and-crmsh-on-ubuntu-1604/)
* [High-availability-setup-with-corosync](https://www.digitalocean.com/community/tutorials/how-to-create-a-high-availability-setup-with-corosync-pacemaker-and-reserved-ips-on-ubuntu-14-04)
* [Apache as reverse proxy](https://www.digitalocean.com/community/tutorials/how-to-use-apache-http-server-as-reverse-proxy-using-mod_proxy-extension-ubuntu-20-04)
* [Nginx HA](https://www.howtoforge.com/tutorial/how-to-set-up-nginx-high-availability-with-pacemaker-corosync-on-centos-7/)
* [High Availability](https://www.digitalocean.com/community/tutorials/how-to-create-a-high-availability-setup-with-corosync-pacemaker-and-reserved-ips-on-ubuntu-14-04)
* [Pacemaker](https://github.com/ClusterLabs/pacemaker)
* [Bash Reference Manual](https://www.gnu.org/software/bash/manual/html_node/index.html)
* [NetWorkManager](https://wiki.debian.org/NetworkConfiguration)
* [Ubuntu Certified Hardware](https://ubuntu.com/certified)
* [Hosts](https://wiki.debian.org/Hostname)
* [Compiling Software](https://help.ubuntu.com/community/CompilingSoftware)
