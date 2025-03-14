[![Hyperledger](https://img.shields.io/badge/hyperledger-2F3134?style=for-the-badge&logo=hyperledger&logoColor=white)](https://www.lfdecentralizedtrust.org/)
![Debian](https://img.shields.io/badge/Debian-D70A53?style=for-the-badge&logo=debian&logoColor=white)
![Ubuntu](https://img.shields.io/badge/Ubuntu-E95420?style=for-the-badge&logo=ubuntu&logoColor=white)

##### [Support UniversalBit Project](https://github.com/universalbit-dev/universalbit-dev/tree/main/support) -- [Disambiguation](https://en.wikipedia.org/wiki/Wikipedia:Disambiguation) -- [Bash Reference Manual](https://www.gnu.org/software/bash/manual/html_node/index.html) -- [Join Mastodon](https://mastodon.social/invite/wTHp2hSD) -- [Website](https://www.universalbit.it/) -- [Content Delivery Network](https://www.universalbitcdn.it/)
---

<img src="https://github.com/universalbit-dev/HArmadillium/blob/main/docs/assets/images/ecosystem_gran_canaria_edited.png" width="auto" />



# [Armadillium](https://en.wikipedia.org/wiki/Thin_client) (ThinClient)
<img src="https://github.com/universalbit-dev/HArmadillium/blob/main/docs/assets/images/armadillidium.png" width="5%" />

#### Development need a digital working environment for develop with or without limit.
Create your Software, Application, WebPage,static and dynamic content.

---

### [Introduction-to-High-Availability](https://ubuntu.com/server/docs/introduction-to-high-availability)
# High Availability Clusters [HArmadillium](https://github.com/universalbit-dev/armadillium/blob/main/HArmadillium.md)

##### HARDWARE: ThinClient examples
* ThinClient HPT610 : [Specifications](https://support.hp.com/us-en/document/c03235347)
* ThinClient HPT630 : [Specifications](https://support.hp.com/us-en/document/c05240287) 
---

Operative System:
* [Debian Minimal Server](https://www.howtoforge.com/tutorial/debian-minimal-server/)
* [Ubuntu 24.04 LTS](https://ubuntu.com/download/desktop#community)

---

##### WebServer:
* [Nginx](https://github.com/universalbit-dev/HArmadillium/blob/main/HArmadillium.md#webserver) -- [Nginx configuration file](https://github.com/universalbit-dev/HArmadillium/blob/main/nginx/01/default)
* [HTTPS](https://github.com/universalbit-dev/HArmadillium/blob/main/HArmadillium.md#self-signed-certificate-https-with-openssl) 
* [SSH connections](https://github.com/universalbit-dev/HArmadillium/blob/main/HArmadillium.md#ssh)

##### Basic Security (If needed,use this: [SELKS](https://github.com/universalbit-dev/SELKS/pkgs/container/arkimeviewer))
* [UFW](https://manpages.ubuntu.com/manpages/bionic/en/man8/ufw.8.html) -- [UFW Firewall setup](https://www.digitalocean.com/community/tutorials/how-to-set-up-a-firewall-with-ufw-on-ubuntu)
* [Haproxy](https://www.haproxy.org/) -- [Haproxy github repository:](https://github.com/haproxy/haproxy/)  -- [Haproxy and Load Balancing Concepts](https://www.digitalocean.com/community/tutorials/an-introduction-to-haproxy-and-load-balancing-concepts)
* [Fail2ban](https://github.com/fail2ban/fail2ban) -- [Protect WebServer with Fail2ban ](https://www.digitalocean.com/community/tutorials/how-to-protect-an-nginx-server-with-fail2ban-on-ubuntu-22-04)
* [Haveged](https://wiki.archlinux.org/title/Haveged#) (Haveged inspired algorithm has been included in the Linux kernel )

```bash
apt install ufw haproxy fail2ban
systemctl enable ufw haproxy fail2ban
```
---
### Debian/Ubuntu distro: [GPUOpen-Drivers](https://github.com/GPUOpen-Drivers/AMDVLK)
---

##### Monitor server performance with 
* [Netdata](https://www.netdata.cloud/) via browser:
```bash
wget -O /tmp/netdata-kickstart.sh https://my-netdata.io/kickstart.sh && sh /tmp/netdata-kickstart.sh
```
### HappyCoding!
