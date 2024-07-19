* [Support UniversalBit Project](https://github.com/universalbit-dev/universalbit-dev/tree/main/support)
* [Disambiguation](https://en.wikipedia.org/wiki/Wikipedia:Disambiguation)
* [ThinClient] Setup:[Armadillium](https://github.com/universalbit-dev/armadillium)
<img src="https://github.com/universalbit-dev/HArmadillium/blob/main/docs/assets/images/ecosystem_gran_canaria_edited.png" width="auto" />

---

## [Introduction to High Availability](https://ubuntu.com/server/docs/introduction-to-high-availability)

### HArmadillium 
Hardware:
* [HP-T610 Thin Client Product Specifications](https://support.hp.com/us-en/document/c03235347) 
* [HP-T630 Thin Client Product Specifications](https://support.hp.com/us-en/document/c05240287) 

note: [certified hardware](https://ubuntu.com/certified)

##### ubuntu
Required:<strong>ubuntu repository</strong>
#[Ubuntu 24.04 LTS Noble] 
<img src="https://github.com/universalbit-dev/HArmadillium/blob/main/images/software_repositories.png" width="auto"></img>

### Wiring
<img src="https://github.com/universalbit-dev/HArmadillium/blob/main/images/HArmadillium.jpg" width="auto" />

note: [ipfire](https://github.com/universalbit-dev/universalbit-dev/blob/main/ipfire/readme.md)

---
---
### [Python3](https://www.python.org/) 
note:
--Deadsnakes <strong>PPA</strong> has already updated its support for Ubuntu 24.04 (Noble)
```bash
sudo add-apt-repository ppa:deadsnakes/ppa
sudo apt update
sudo apt install python3.11
```

<strong>OR</strong> Download and Compile Python3 from [source](https://www.python.org/downloads/): 
* note:
[Compiling Software](https://help.ubuntu.com/community/CompilingSoftware)

```bash
./configure
make
make test
sudo make install
```

### High Availability Required Packages:
```bash
#[Ubuntu 24.04 LTS Noble]
sudo apt install corosync pacemaker fence-agents crmsh pcs* cluster-glue ufw nginx haveged heartbeat openssh-server
```
---

###### Overview:
* [Host setup](#Host)
* [SSH connections](#SSH)
* [Corosync](#Corosync)
* [PCMK file](#PCMK)
* [CRM](#CRM)
* [PCS Setup](#PCS)
* [WebServer](#WebServer)
* [PaceMaker](#PaceMaker)
* [Firewall UFW](#UFW)

Getting <strong>Wiki</strong>:
* [Corosync-PCS-PaceMaker](https://wiki.debian.org/Debian-HA/ClustersFromScratch)

## Host
* edit host file <strong>TO</strong> each node
```bash
sudo nano /etc/hosts
```
armadillium01 host
```bash
127.0.0.1       localhost
127.0.1.1       armadillium01

# The following lines are desirable for IPv6 capable hosts
::1     ip6-localhost ip6-loopback
fe00::0 ip6-localnet
ff00::0 ip6-mcastprefix
ff02::1 ip6-allnodes
ff02::2 ip6-allrouters

192.168.1.142 armadillium02
192.168.1.143 armadillium03
192.168.1.144 armadillium04
```
host setup
* ##### [#01](https://github.com/universalbit-dev/HArmadillium/blob/main/host/01.md) -- [#02](https://github.com/universalbit-dev/HArmadillium/blob/main/host/02.md) -- [#03](https://github.com/universalbit-dev/HArmadillium/blob/main/host/03.md) -- [#04](https://github.com/universalbit-dev/HArmadillium/blob/main/host/04.md)

---
## SSH
##### SSH connection to communicate with all nodes
Install required packages to each node and <strong>Check [ubuntu repository](#ubuntu)</strong>
* <strong>FROM</strong> armadillium01 <strong>TO</strong> armadillium02
```bash
ssh armadillium02@192.168.1.142
sudo apt install corosync pacemaker fence-agents crmsh pcs* cluster-glue ufw nginx haveged heartbeat openssh-server
```
ssh setup
* ##### -- [#03](https://github.com/universalbit-dev/HArmadillium/blob/main/ssh/03.md) -- [#04](https://github.com/universalbit-dev/HArmadillium/blob/main/ssh/04.md)

## UFW
## Firewall Rules TO each node
-Description:
The Uncomplicated FireWall is a front-end for iptables, to make managing a Netfilter firewall easier. It provides a command line interface with syntax similar to OpenBSD's Packet Filter. It is particularly well-suited as a host-based firewall.

```bash
sudo ufw allow from 192.168.1.141
sudo ufw allow from 192.168.1.142
sudo ufw allow from 192.168.1.143
sudo ufw allow from 192.168.1.144
sudo ufw allow ssh
```
[firewall rules](https://github.com/universalbit-dev/HArmadillium/tree/main/ufw)

---

#### High Availability
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
## CRM 
#### Consider this configuration tool as an alternative to PCS.
[Cluster Setup](https://crmsh.github.io/start-guide/)

---

## PCS
* [PCS](https://packages.debian.org/buster/pcs) Pacemaker Configuration System
  
-Description:
It permits users to easily view, modify and create pacemaker based clusters.
pcs also provides pcsd, which operates as a GUI and remote server for PCS.

* ##### PCS Setup Cluster : 
```bash
#armadillium01
sudo pcs cluster setup HArmadillium armadillium01 armadillium02 armadillium03 armadillium04
```
#### PCS Create Password  and authenticate localhost
```bash
#armadillium01
sudo passwd hacluster
```

#### authenticate localhost
```bash
sudo pcs client local-auth
#Username: hacluster
#Password: 
#localhost: Authorized
```
[ClusterLabs](https://clusterlabs.org/pacemaker/doc/2.1/Clusters_from_Scratch/html/cluster-setup.html) (3.3.2. Enable pcs Daemon)

#### PCS AUTH authorize/authenticate other host
```bash
#armadillium01
sudo pcs host auth armadillium01 armadillium02 armadillium03 armadillium04
#Username: hacluster
#Password:
#armadillium01: Authorized
#armadillium02: Authorized
#armadillium03: Authorized
#armadillium04: Authorized
```

* ##### Disable STONITH 
```bash
sudo pcs property set stonith-enabled=false
```
* ##### Ignore Quorum policy
```bash
sudo pcs property set no-quorum-policy=ignore
```
* ##### [PCS Create Resources](https://www.golinuxcloud.com/create-cluster-resource-in-ha-cluster-examples/):
* ##### Create WebServer Resource
```bash
#[under review]
#sudo pcs resource create webserver ocf:heartbeat:nginx configfile=/etc/nginx/nginx.conf op monitor timeout="5s" interval="5s"
#crm configure primitive webserver ocf:heartbeat:nginx configfile=/etc/nginx/nginx.conf op start timeout="40s" interval="0" op stop timeout="60s" interval="0" op monitor interval="10s" timeout="60s" meta migration-threshold="10"
```
### ClusterLabs [Resource Agents](https://github.com/ClusterLabs/resource-agents)

* ##### Create PCS FLOATING IP Resource:
```bash
sudo pcs resource create virtual_ip ocf:heartbeat:IPaddr2 ip=192.168.1.140 cidr_netmask=32 op monitor interval=30s
#crm configure primitive virtual_ip ocf:heartbeat:IPaddr2 params ip="192.168.1.140" cidr_netmask="32" op monitor interval="10s" meta migration-threshold="10"
```
##### Constraint:
```bash
sudo pcs constraint colocation add webserver with virtual_ip INFINITY
```
```bash
sudo pcs constraint order webserver then virtual_ip
#Adding webserver virtual_ip (kind: Mandatory) (Options: first-action=start then-action=start)

```
#### note:
* [ClusterLabs Enable pcs Daemon ](https://clusterlabs.org/pacemaker/doc/deprecated/en-US/Pacemaker/2.0/html/Clusters_from_Scratch/_enable_pcs_daemon.html)


* ##### Start PCS cluster and enable all
```bash
sudo pcs cluster start --all
sudo pcs cluster enable --all
#armadillium01: Starting Cluster...
#armadillium02: Starting Cluster...
#armadillium03: Starting Cluster...
#armadillium04: Starting Cluster...
#armadillium01: Cluster Enabled
#armadillium02: Cluster Enabled
#armadillium03: Cluster Enabled
#armadillium04: Cluster Enabled

```
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
* ##### Create PCMK file
```bash 
sudo mkdir /etc/corosync/service.d
sudo nano /etc/corosync/service.d/pcmk
```
* ##### add this
```bash
service {
  name: pacemaker
  ver: 1
}
```

---
## Webserver
* ##### Nginx as Reverse Proxy
```bash
sudo apt install openssl nginx -y
```
[OpenSSL](https://github.com/openssl/openssl) WebServer 

## [HTTPS]
#### self-signed certificate (HTTPS) with OpenSSL 
```bash
sudo mkdir /etc/nginx/ssl
```

```bash
git clone https://github.com/universalbit-dev/HArmadillium/
cd ~/HArmadillium/ssl
openssl genrsa 2048 > host.key
chmod 400 host.key
openssl req -new -x509 -nodes -sha256 -days 365 -key host.key -out host.cert -config distinguished.cnf
sudo cp host.key host.cert /etc/nginx/ssl
```

## Nginx Configuration File (default)
* edit the Nginx default file 
```bash
nano /etc/nginx/sites-enabled/default
```

* #armadillium01 Nginx configuration file:
```bash
#armadillium01 192.168.1.141
server {
listen 80;
listen [::]:80;
server_name 192.168.1.141;
return 301 https://$server_name$request_uri;
}

server {
    server_name 192.168.1.141;
    listen 8001;
    return 301 https://$host$request_uri;
    }
    
upstream websocket {
    server 192.168.1.141;
    server 192.168.1.142;
    server 192.168.1.143;
    server 192.168.1.144;
}

server {
    listen 443 ssl;
    listen [::]:443 ssl;
    server_name 192.168.1.141;
    root /usr/share/nginx/html;
    ssl_certificate /etc/nginx/ssl/host.cert;
    ssl_certificate_key /etc/nginx/ssl/host.key;    

    location / {
            proxy_buffers 8 32k;
            proxy_buffer_size 64k;
            proxy_pass http://websocket;
            proxy_set_header X-Real-IP $remote_addr;
            proxy_set_header Host $http_host;
            proxy_set_header X-Forwarded-For $proxy_add_x_forwarded_for;
            proxy_set_header X-NginX-Proxy true;
            proxy_http_version 1.1;
            proxy_set_header Upgrade $http_upgrade;
            proxy_set_header Connection "upgrade";
            proxy_read_timeout 86400s;
            proxy_send_timeout 86400s;
    }
}
#armadillium01 systemd[1]: Started nginx.service - A high performance web server and a reverse proxy server.

```
#### webserver nginx node configuration file:
  * #[01](https://github.com/universalbit-dev/HArmadillium/blob/main/nginx/01/default) -- #[02](https://github.com/universalbit-dev/HArmadillium/blob/main/nginx/02/default) -- #[03](https://github.com/universalbit-dev/HArmadillium/blob/main/nginx/03/default) -- #[04](https://github.com/universalbit-dev/HArmadillium/blob/main/nginx/03/default)

---

* ##### Throubleshooter:
```
**Error
Warning: Unable to read the known-hosts file: No such file or directory: '/var/lib/pcsd/known-hosts'
armadillium03: Unable to authenticate to armadillium03 - (HTTP error: 401)...
armadillium01: Unable to authenticate to armadillium01 - (HTTP error: 401)...
armadillium04: Unable to authenticate to armadillium04 - (HTTP error: 401)...
armadillium02: Unable to authenticate to armadillium02 - (HTTP error: 401)...
```

* ##### cause: PCSD service not started
* ##### fix: Start PCSD service
```bash
#armadilliun02
ssh armadillium02@10.0.2.142
sudo service pcsd start
sudo service pcsd status
```

* ##### PCSD Status:
```bash
sudo pcs cluster status
```
```bash
  * armadillium03: Online
  * armadillium04: Online
  * armadillium02: Online
  * armadillium01: Online
```
---

* ##### Property List TO each node
```bash
sudo pcs property list
```

##### Example Working Output: 
```bash
Cluster Properties:
cluster-infrastructure: corosync
cluster-name: HArmadillium
dc-version: 2.0.5
have-watchdog: false
no-quorum-policy: ignore
stonith-enabled: false
```
##### HACluster configured and ready to host something of amazing
---
---

Resources:
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
* [Hosts](https://wiki.debian.org/Hostname)
