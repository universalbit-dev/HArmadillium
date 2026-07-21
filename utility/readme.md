# HArmadillium Core Utilities

📦 **Core Stack Tools**  
[![Installer](https://img.shields.io/badge/Utility-dynamic__installer.sh-blue?style=flat-flat&logo=gnu-bash&logoColor=white)](./dynamic_installer.sh)
[![Firewall](https://img.shields.io/badge/Security-ha__rules.sh-success?style=flat-flat&logo=linux&logoColor=white)](./ha_rules.sh)
[![Crypto](https://img.shields.io/badge/Crypto-make__certs.sh-blueviolet?style=flat-flat&logo=openssl&logoColor=white)](./make_certs.sh)
[![Heartbeat](https://img.shields.io/badge/Observability-ha__heartbeat.sh-ff69b4?style=flat-flat&logo=heartbeat&logoColor=white)](./ha_heartbeat.sh)

🚀 **System Status & Architecture**  
[![Platform](https://img.shields.io/badge/Ubuntu-24.04%20LTS-orange?style=flat-flat&logo=ubuntu&logoColor=white)](https://ubuntu.com)
[![Cluster manager](https://img.shields.io/badge/HA-Pacemaker%20%2B%20Corosync-red?style=flat-flat)](https://clusterlabs.org)
[![Firewall Engine](https://img.shields.io/badge/Firewall-UFW%20Optimized-darkgreen?style=flat-flat)](https://launchpad.net/ufw)

---

## 🛠️ Script Overview

This directory contains automation, security orchestration, and observability scripts for high-availability clusters.

- **`dynamic_installer.sh`**
  - Installs and configures cluster dependencies (`corosync`, `pacemaker`, `pcs`, `ufw`, `fail2ban`)
  - Supports genesis initialization and peer join flows
  - Applies dynamic Stage 3 web stack setup (NGINX or Apache)
  - Optionally installs heartbeat as a systemd service

- **`ha_rules.sh`**
  - Applies UFW hardening for cluster mesh communication
  - Dynamically maps peer nodes from cluster configuration
  - Restricts ingress to required management and HA ports

- **`make_certs.sh`**
  - Generates self-signed TLS certificates with SAN entries
  - Supports host/IP-based internal validation use cases

- **`ha_heartbeat.sh`**
  - Monitors peer liveness using ICMP/TCP/UDP checks
  - Writes human-readable logs and JSONL telemetry
  - Supports optional failover command execution on threshold breach

---

## 📊 Deployment Pipeline Diagram

```text
==========================================================================================
                      THIN CLIENT HA SETUP PIPELINE (Ubuntu 24.04 LTS)
==========================================================================================

 [GENESIS MASTER NODE]
    ├── 1. Prepare Ubuntu 24.04 LTS
    ├── 2. Clone repository
    ├── 3. cd HArmadillium/utility
    ├── 4. Run ./dynamic_installer.sh  ---> Select 'y'
    ├── 5. Run ./make_certs.sh
    ├── 6. Run ./ha_rules.sh           ---> master/local IP parameters
    └── 7. Run ./ha_heartbeat.sh       ---> peer health telemetry

            │
            ▼

 [PEER NODES]
    ├── 1. SSH into node
    ├── 2. Clone repository
    ├── 3. cd HArmadillium/utility
    ├── 4. Run ./dynamic_installer.sh  ---> Select 'n' and provide master IP
    ├── 5. Run ./ha_rules.sh           ---> master/local IP parameters
    └── 6. Run ./ha_heartbeat.sh       ---> local peer visibility

==========================================================================================
```

---

## 🚀 Execution Guide

Set executable permission:

```bash
chmod +x *.sh
```

### Phase A — Initialize Genesis Master

```bash
git clone https://github.com/universalbit-dev/HArmadillium.git
cd HArmadillium/utility
sudo ./dynamic_installer.sh
```

When prompted, select `y` for genesis master initialization.

Generate TLS assets:

```bash
./make_certs.sh
```

Apply firewall policy:

```bash
./ha_rules.sh <MASTER_IP> <LOCAL_IP> [SSH_USER]
```

Run heartbeat monitor:

```bash
sudo ./ha_heartbeat.sh \
  --nodes "<NODE_IP_1>,<NODE_IP_2>,<NODE_IP_3>" \
  --check-tcp --tcp-ports "22,2224" \
  --check-pcs --check-corosync \
  --summary-every 10
```

### Phase B — Join Peer Nodes

```bash
git clone https://github.com/universalbit-dev/HArmadillium.git
cd HArmadillium/utility
sudo ./dynamic_installer.sh
```

When prompted, select `n` and provide the genesis master IP.

Then apply firewall rules and start heartbeat:

```bash
./ha_rules.sh <MASTER_IP> <LOCAL_IP> [SSH_USER]
sudo ./ha_heartbeat.sh --nodes "<NODE_IP_1>,<NODE_IP_2>,<NODE_IP_3>"
```

---

## 💓 `ha_heartbeat.sh` Quick Reference

Minimal:

```bash
./ha_heartbeat.sh --nodes "IP1,IP2,IP3"
```

Common options:

- `--self-ip <IP>`
- `--interval <seconds>`
- `--timeout <seconds>`
- `--fail-threshold <count>`
- `--check-tcp --tcp-ports "22,2224"`
- `--check-udp --udp-ports "5404,5405"`
- `--check-pcs`
- `--check-corosync`
- `--summary-every <N>`
- `--log-file <path>`
- `--raw-out <path>`
- `--failover-cmd "<command>"`

Recommended LAN profile:

```bash
sudo ./ha_heartbeat.sh \
  --nodes "IP1,IP2,IP3" \
  --interval 3 \
  --timeout 2 \
  --fail-threshold 5 \
  --check-tcp --tcp-ports "22,2224" \
  --check-pcs --check-corosync \
  --summary-every 10
```

---

## ✅ Validation Checklist

```bash
sudo pcs status
sudo pcs status nodes
sudo systemctl status pcsd --no-pager
sudo systemctl status nginx --no-pager
sudo systemctl status apache2 --no-pager
sudo systemctl status ha-heartbeat.service --no-pager
sudo ufw status numbered
```

---

## 🔐 Security Guidance

- Use strong cluster credentials (minimum length and non-reusable patterns).
- Restrict private key permissions:
  ```bash
  chmod 600 certs/*.key
  ```
- Treat heartbeat logs as sensitive operational telemetry.
- Avoid exposing internal IP topology in public issue trackers/screenshots.

---

## 🧩 Troubleshooting

- **Heartbeat flapping (UP/DOWN oscillation)**  
  Increase tolerance parameters (`interval`, `timeout`, `fail-threshold`).

- **Node already member / already exists**  
  Verify cluster state:
  ```bash
  sudo pcs status nodes
  ```

- **TLS startup issues in web stack**  
  Verify expected cert/key paths and permissions, then retest service config.

- **Split cluster due to multiple genesis initializations**  
  Rebuild with a single authoritative genesis node and rejoin peers in non-master mode.

---

## 📄 License

This project is licensed under the **MIT License**.  
See the repository root [LICENSE]() file for full text.
