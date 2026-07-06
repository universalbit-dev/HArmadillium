# HArmadillium Core Utilities

📦 **Core Stack Tools**
[![Installer](https://img.shields.io/badge/Utility-dynamic__installer.sh-blue?style=flat-flat&logo=gnu-bash&logoColor=white)](./dynamic_installer.sh)
[![Firewall](https://img.shields.io/badge/Security-ha__rules.sh-success?style=flat-flat&logo=linux&logoColor=white)](./ha_rules.sh)
[![Crypto](https://img.shields.io/badge/Crypto-make__certs.sh-blueviolet?style=flat-flat&logo=openssl&logoColor=white)](./make_certs.sh)

🚀 **System Status & Architecture**
[![Platform](https://img.shields.io/badge/Ubuntu-24.04%20LTS-orange?style=flat-flat&logo=ubuntu&logoColor=white)](https://ubuntu.com)
[![Cluster manager](https://img.shields.io/badge/HA-Pacemaker%20%2B%20Corosync-red?style=flat-flat)](https://clusterlabs.org)
[![Firewall Engine](https://img.shields.io/badge/Firewall-UFW%20Optimized-darkgreen?style=flat-flat)](https://launchpad.net/ufw)


## 🛠️ Script Overview

This directory contains the core automation and security orchestration scripts for managing high-availability clusters.

### 1. `dynamic_installer.sh`
Automates the configuration and installation of cluster components across environments. 
*   **Recent Update:** Provisioned with updated Genesis Master IP routing and node discovery configurations.
*   **Key Feature:** Dynamic node pairing and target environment validation.

### 2. `ha_rules.sh`
Orchestrates secure network boundaries using optimized UFW configurations designed specifically for Corosync/Pacemaker traffic.
*   **Recent Update:** Refactored example usages for cleaner multi-node deployments.
*   **Key Feature:** Prevents split-brain scenarios by keeping cluster communication loops isolated and strictly permitted.

### 3. `make_certs.sh`
Automated utility to handle TLS/SSL infrastructure within the cluster.
*   **Key Feature:** Rapidly generates and renews internal cryptographic assets required for secure inter-node transactions.

---
