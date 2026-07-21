## 📢 Support the UniversalBit Project

Help us grow and continue innovating!  
- [Support the UniversalBit Project](https://github.com/universalbit-dev/universalbit-dev/tree/main/support)  
- [Learn about Disambiguation](https://en.wikipedia.org/wiki/Wikipedia:Disambiguation)  
- [Bash Reference Manual](https://www.gnu.org/software/bash/manual/)

---

#### Unlimited Digital Development Environment for High Availability Clusters
<p align="center">
  <img src="docs/assets/images/Bitto_Ascii.png" alt="Bitto mascotte" width="200" />
</p>

---

# High Availability Clusters with HArmadillium

Welcome to **HArmadillium**, an open-source educational and production-ready framework for deploying, validating, and hardening Linux High Availability clusters with:

- **Pacemaker**
- **Corosync**
- **PCS**
- **Dynamic NGINX/Apache template rendering**
- **UFW + Fail2Ban security controls**

---

## 🗺️ HArmadillium Learning Roadmap

```text
  [ Node ]
         │
         ├──► 1: Propedeutic Sandbox (ha_cluster_setup.sh)
         │    └─ Learn networking, SSL, proxy, and baseline security locally.
         │
         ├──► 2: Automated Production Grid (utility/)
         │    └─ Bootstrap roles, membership, and authentication flows.
         │
         └──► 3: Dynamic Service Layer (templated nginx/apache)
              └─ Render final runtime configs from templates per node context.
```

---

## 🎯 Stage 1 — Propedeutic Sandbox (`ha_cluster_setup.sh`)

Designed for first-time cluster learning before multi-node rollout.

- Local environment preparation
- Network and service baseline validation
- Security and proxy fundamentals

---

## 🚀 Stage 2 — Utility Automation Suite (`utility/`)

Main scripts:

- `dynamic_installer.sh`
- `ha_rules.sh`
- `make_certs.sh`
- `ha_heartbeat.sh`

### Stage 2 responsibilities

- Install required cluster packages
- Initialize a genesis node or join peer nodes
- Configure local and remote cluster authentication
- Apply optional firewall and heartbeat integrations
- Launch Stage 3 dynamic web stack setup

---

## 🌐 Stage 3 — Dynamic Template-Based Web Configuration

Stage 3 is **template-driven** and integrated into `utility/dynamic_installer.sh`.

When prompted by the installer:

- Select web stack (`NGINX` or `Apache`)
- Provide runtime values (node name, node IP, upstream data)
- The installer renders final configs from templates:
  - `nginx/default.template`
  - `apache/000-default.conf.template`
- Syntax checks are executed before service restart
- Default TLS paths are used automatically; self-signed certs are generated if missing

This avoids manual per-node static file duplication and improves consistency.

---

## 🛠️ Quick Start

```bash
git clone https://github.com/universalbit-dev/HArmadillium.git
cd HArmadillium/utility
chmod +x *.sh
sudo ./dynamic_installer.sh
```

- Choose `yes` only on the designated genesis node
- Choose `no` on peer nodes and provide the genesis node address when prompted

Optional utilities:

```bash
./make_certs.sh
./ha_rules.sh <MASTER_IP> <LOCAL_IP> [SSH_USER]
sudo ./ha_heartbeat.sh --nodes "<NODE_IP_1>,<NODE_IP_2>,<NODE_IP_3>"
```

---

## 💓 Heartbeat Monitoring (`ha_heartbeat.sh`)

`ha_heartbeat.sh` supports:

- ICMP checks (default)
- Optional TCP/UDP checks
- Optional PCS/Corosync local snapshots
- JSONL output for telemetry ingestion
- Threshold-based eventing and optional failover hooks

Use conservative probe settings in production networks to reduce false positives.

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

- Use strong cluster credentials.
- Restrict private key permissions:
  ```bash
  chmod 600 utility/certs/*.key
  ```
- Treat logs and topology metadata as sensitive.
- Avoid publishing real internal hostnames, IP ranges, or credential patterns in public docs/screenshots.

---

## 📚 Technical Documentation & External Resources

### Core operations
- [HArmadillium Core Architecture Wiki](HArmadillium.md)
- [Nginx Configuration Guide](HArmadillium.md#nginx-configuration)
- [Apache Webserver Guide](HArmadillium.md#webserver)

### HA and security references
- [Pacemaker & Corosync ClusterLabs](https://clusterlabs.org)
- [UFW Reference](https://manpages.ubuntu.com/manpages/bionic/en/man8/ufw.8.html)
- [Fail2Ban Project](https://github.com/fail2ban/fail2ban)
- [OpenSSL SAN Notes](HArmadillium.md#self-signed-certificate-https-with-openssl)

### Optional advanced inspection
- [SELKS / Clear NDR Community](https://www.stamus-networks.com/selks-archive)

---

## 📄 License

This project is licensed under the **MIT License**.  
See the [LICENSE](LICENSE) file for details.
