# PCS

[PCS](https://packages.debian.org/buster/pcs) - Pacemaker Configuration System

## Description
The Pacemaker Configuration System (PCS) allows users to easily view, modify, and create Pacemaker-based clusters. PCS also includes `pcsd`, which provides a GUI and remote server for easier cluster management.

---

## PCS Cluster Setup

### 1. Initialize and Start the Cluster
```bash
# From armadillium01
sudo pcs cluster setup HArmadillium armadillium01 armadillium02 armadillium03 armadillium04
sudo pcs cluster start --all
