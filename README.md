##### [Support UniversalBit Project](https://github.com/universalbit-dev/universalbit-dev/tree/main/support)
<img src="https://github.com/universalbit-dev/HArmadillium/blob/main/docs/assets/images/ecosystem_gran_canaria_edited.png" width="auto" />

* also [mini pond](https://www.bbc.com/future/article/20240423-how-to-make-a-mini-wildlife-pond) is a good example

# [Armadillium](https://en.wikipedia.org/wiki/Thin_client) (ThinClient)
<img src="https://github.com/universalbit-dev/HArmadillium/blob/main/docs/assets/images/armadillidium.png" width="5%" />

#### Development need a digital working environment for develop with or without limit.
Create your Software, Application, WebPage,static and dynamic content.

# Cluster [HArmadillium](https://github.com/universalbit-dev/armadillium/blob/main/HArmadillium.md)

##### HARDWARE: ThinClient examples
* N.4 ThinClient HPT610 : [HP ThinClient Specifications](https://support.hp.com/us-en/document/c03235347)
* N.4 ThinClient HPT630 : [HP ThinClient Specifications](https://support.hp.com/us-en/document/c05240287) 

-- [AMDVLK](https://github.com/universalbit-dev/AMDVLK) --

##### [Debian 12](https://www.debian.org/)
* [Debian Minimal Server](https://www.howtoforge.com/tutorial/debian-minimal-server/)
##### [Ubuntu 24.04 LTS](https://ubuntu.com/download/desktop)
* [Ubuntu Desktop](https://ubuntu.com/download/desktop#community)

---
---

##### WebServer:
* [Nginx](https://docs.nginx.com/nginx/admin-guide/installing-nginx/installing-nginx-open-source/)
* [Apache2](https://www.digitalocean.com/community/tutorials/how-to-create-a-self-signed-ssl-certificate-for-apache-in-debian-10)


* SSH connections [wiki](https://wiki.debian.org/SSH)

##### Basic Security (If needed,use this: [SELKS](https://github.com/universalbit-dev/SELKS))
* [Ufw](https://manpages.ubuntu.com/manpages/bionic/en/man8/ufw.8.html) -- [Ufw wiki](https://wiki.debian.org/Uncomplicated%20Firewall%20%28ufw%29)
* [Havp](https://www.havp.org/) -- [Havp github repository:](https://github.com/HaveSec/HAVP)
* [Haproxy](https://www.haproxy.org/) -- [Haproxy github repository:](https://github.com/haproxy/haproxy/)
* [Fail2ban](https://github.com/fail2ban/fail2ban) -- [Fail2ban wiki](https://en.wikipedia.org/wiki/Fail2ban)
* [Haveged](https://wiki.archlinux.org/title/Haveged#) (Haveged inspired algorithm has been included in the Linux kernel )

```bash
apt install ufw havp haproxy fail2ban
```
---
---

### Debian/Ubuntu distro: [GPUOpen-Drivers](https://github.com/GPUOpen-Drivers/AMDVLK)
* [OpenCL](https://github.com/KhronosGroup/OpenCL-Guide/blob/main/chapters/getting_started_linux.md) 
* [AMDVLK](https://github.com/GPUOpen-Drivers/AMDVLK)

```bash
apt-get install libssl-dev libx11-dev libxcb1-dev x11proto-dri2-dev libxcb-dri3-dev libxcb-dri2-0-dev libxcb-present-dev libxshmfence-dev libxrandr-dev libwayland-dev ocl-icd-opencl-dev 
```
##### amdvlk other [distro](https://github.com/GPUOpen-Drivers/AMDVLK?tab=readme-ov-file#install-dev-and-tools-packages)

---

##### Monitor server performance with 
* [Netdata](https://www.netdata.cloud/) via browser:
```bash
wget -O /tmp/netdata-kickstart.sh https://my-netdata.io/kickstart.sh && sh /tmp/netdata-kickstart.sh
```

[Bash Reference Manual](https://www.gnu.org/software/bash/manual/html_node/index.html)

### HappyCoding!
