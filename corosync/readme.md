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

To integrate the `PCMK` configuration into the repository, follow these steps:

### 1. **Create the `PCMK` File in Corosync Service Directory**
   - Run the following commands to create the necessary directory and file:
     ```bash
     sudo mkdir -p /etc/corosync/service.d
     sudo nano /etc/corosync/service.d/pcmk
     ```

### 2. **Add the Required Service Block**
   - Inside the `pcmk` file, add the following service configuration:
     ```plaintext
     service {
       name: pacemaker
       ver: 1
     }
     ```

### 3. **Important Considerations**
   - Ensure this step is performed **after generating the `corosync.conf` file**.
   - Make sure the `corosync-keygen` file is properly generated and copied to the appropriate location.

### Suggested Integration in the `corosync/readme.md` File
Add the above steps to the `corosync/readme.md` file to document the process. Here's an example of how it can be written:

## Configuring Pacemaker (PCMK) Service in Corosync

### Create the `PCMK` File
Run the following commands to create the `pcmk` service configuration file:

```bash
sudo mkdir -p /etc/corosync/service.d
sudo nano /etc/corosync/service.d/pcmk
```

### Add the Service Configuration
Add the following content to the `pcmk` file:

```plaintext
service {
  name: pacemaker
  ver: 1
}
```

### Notes:
- This step must be performed **after** generating the `corosync.conf` file.

