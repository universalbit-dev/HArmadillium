## Corosync in HArmadillium

HArmadillium is a comprehensive solution for configuring and managing High Availability (HA) clusters. Corosync forms the foundation of the cluster communication stack but is only one part of the full HArmadillium configuration. Other components, such as PCS (Pacemaker Configuration System), are required to complete the setup.

This directory contains resources and scripts related to Corosync, including configuration and deployment.

---

## Script: `generate_and_deploy_corosync.sh`

For automating the configuration and deployment of Corosync, a dedicated script, `generate_and_deploy_corosync.sh`, has been provided. This script simplifies the Corosync setup process and ensures consistent configuration across nodes in the cluster.

For detailed instructions and usage, refer to the [generate_and_deploy_corosync.md](https://github.com/universalbit-dev/HArmadillium/blob/main/corosync/generate_and_deploy_corosync.md) guide.

---

## Note

Corosync is only part of the HArmadillium HA cluster configuration. To complete the setup, additional components such as PCS and resource agents must also be configured. Refer to the main repository and related documentation for further details.
