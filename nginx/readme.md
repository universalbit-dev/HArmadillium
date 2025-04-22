# Nginx Webserver in HArmadillium Cluster

### **Introduction**
The Nginx webserver plays a critical role in the HArmadillium High Availability (HA) cluster as the primary webserver resource. It serves as the endpoint for handling HTTP and HTTPS traffic, ensuring the seamless delivery of web content and applications hosted within the cluster. To provide reliability and fault tolerance, the Nginx service is managed as a cluster resource, with a **virtual IP** (VIP) enabling automatic failover between nodes.

---

### **Role of Nginx in HArmadillium**
1. **Webserver Resource**:
   - Nginx is configured as a managed cluster resource in HArmadillium.
   - It ensures the availability of web services by automatically restarting or relocating the service in case of a node failure.

2. **Virtual IP**:
   - A virtual IP (VIP) is assigned to the Nginx resource, allowing clients to access the webserver without depending on specific node IP addresses.
   - The VIP ensures that requests are routed to the active node hosting the Nginx service.

3. **High Availability**:
   - Nginx is integrated with the cluster to provide load balancing and failover capabilities.
   - In the event of a node failure, the cluster automatically migrates the Nginx service and VIP to another healthy node.

---

### **Virtual IP Configuration**
The following virtual IP is shared among the nodes in the cluster:
- **VIP**: `192.168.1.140`

This VIP is dynamically assigned to one of the following nodes based on availability:
- `armadillium01`
- `armadillium02`
- `armadillium03`
- `armadillium04`

The VIP ensures that clients can always access the webserver, regardless of which node is currently active.

---

### **Steps to Configure Nginx in the Cluster**
1. **Install Nginx**:
   - Install Nginx on all nodes in the cluster:
     ```bash
     sudo apt update
     sudo apt install nginx
     ```

2. **Add Nginx as a Cluster Resource**:
   - Use the `pcs` command to add Nginx as a managed resource:
     ```bash
     sudo pcs resource create nginx ocf:heartbeat:nginx \
       configfile="/etc/nginx/nginx.conf" \
       op monitor interval="30s"
     ```

3. **Configure the Virtual IP**:
   - Add a VIP resource to the cluster:
     ```bash
     sudo pcs resource create vip ocf:heartbeat:IPaddr2 \
       ip="192.168.1.140" cidr_netmask="24" \
       op monitor interval="30s"
     ```

4. **Set Resource Constraints**:
   - Co-locate the VIP and Nginx resources on the same node:
     ```bash
     sudo pcs constraint colocation add nginx vip INFINITY
     ```

   - Ensure VIP is started before Nginx:
     ```bash
     sudo pcs constraint order vip then nginx
     ```

5. **Enable the Cluster**:
   - Start the cluster services and enable them to start automatically:
     ```bash
     sudo pcs cluster start --all
     sudo pcs cluster enable --all
     ```

---

### **Testing and Verification**
1. Verify that the Nginx service is running on the active node:
   ```bash
   sudo pcs status
   ```

2. Access the webserver using the VIP:
   - Open a browser or use `curl` to access the VIP:
     ```bash
     curl http://192.168.1.140
     ```

3. Simulate a node failure:
   - Power off or stop the cluster services on the active node and confirm that the Nginx service and VIP are migrated to another node.

---

### **Conclusion**
By configuring Nginx as a webserver resource with a virtual IP, HArmadillium ensures high availability and fault tolerance for web applications. This setup guarantees uninterrupted service, even in the event of node failures, making it an essential component of the HArmadillium HA cluster.

For additional details, consult the main repository documentation or the [Pacemaker](https://clusterlabs.org/pacemaker/doc/) and [Nginx](https://nginx.org/en/docs/) official guides.

---
