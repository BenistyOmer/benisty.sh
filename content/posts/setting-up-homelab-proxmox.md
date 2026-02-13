---
title: "Setting Up a Home Lab with Proxmox"
date: 2026-02-13T10:00:00Z
draft: true
author:
  name: Omer Benisty
description: "A guide to building a home lab environment using Proxmox VE for learning and testing infrastructure."
tags:
  - linux
  - proxmox
  - homelab
  - virtualization
categories:
  - Infrastructure
featuredImagePreview: ""
---

In this post, I'll walk through how I set up my home lab using **Proxmox VE** — a powerful open-source virtualization platform.

<!--more-->

## Why a Home Lab?

As a sysadmin, having a home lab is invaluable. It gives you a safe environment to:

- Test configurations before deploying to production
- Learn new technologies hands-on
- Break things without consequences
- Build your portfolio with real projects

{{< admonition type="tip" title="Pro Tip" >}}
You don't need expensive hardware. An old desktop or even a mini PC like an Intel NUC works great for getting started.
{{< /admonition >}}

## Hardware Requirements

Here's what I'm running:

| Component | Spec |
|-----------|------|
| CPU | Intel i5-12400 |
| RAM | 64GB DDR4 |
| Storage | 1TB NVMe + 2x 4TB HDD |
| Network | 2x 1Gbps NIC |

## Installation

First, download the Proxmox VE ISO from the [official site](https://www.proxmox.com/en/downloads).

After booting from the USB, the installation is straightforward. Once it's done, you can access the web UI at `https://your-ip:8006`.

### Post-Install Configuration

Update the system and disable the enterprise repository:

```bash
# Remove enterprise repo
rm /etc/apt/sources.list.d/pve-enterprise.list

# Add no-subscription repo
echo "deb http://download.proxmox.com/debian/pve bookworm pve-no-subscription" > \
  /etc/apt/sources.list.d/pve-no-subscription.list

# Update
apt update && apt full-upgrade -y
```

{{< admonition type="warning" title="Important" >}}
The no-subscription repository is **not recommended for production**. It's fine for a home lab, but in production you should use the enterprise repository with a valid subscription.
{{< /admonition >}}

## Network Setup

I configured a bridge network for my VMs:

```bash
auto vmbr0
iface vmbr0 inet static
    address 10.0.0.1/24
    bridge-ports eno1
    bridge-stp off
    bridge-fd 0
```

Here's how the network topology looks:

{{< mermaid >}}
graph TD
    Internet[Internet] --> Router[Router]
    Router --> Switch[Managed Switch]
    Switch --> Proxmox[Proxmox Host - vmbr0]
    Proxmox --> VM1[Ubuntu Server]
    Proxmox --> VM2[Docker Host]
    Proxmox --> VM3[pfSense]
    Proxmox --> LXC1[Nginx Proxy]
{{< /mermaid >}}

## VMs I'm Running

{{< tabs defaultTab="0" type="card" >}}
  {{% tab title="Docker Host" %}}
  An Ubuntu Server VM running Docker and Docker Compose. Hosts most of my self-hosted services:
  - Portainer
  - Uptime Kuma
  - Grafana + Prometheus
  - Homepage dashboard
  {{% /tab %}}
  {{% tab title="pfSense" %}}
  Handles all routing, firewall rules, and VPN. Configured with:
  - WireGuard VPN for remote access
  - Suricata IDS/IPS
  - DNS resolver with DNSBL
  {{% /tab %}}
  {{% tab title="Nginx Proxy" %}}
  An LXC container running Nginx Proxy Manager for reverse proxying all services with automatic SSL via Let's Encrypt.
  {{% /tab %}}
{{< /tabs >}}

## Monitoring

I use Grafana with Prometheus and node_exporter to monitor all my hosts:

```yaml
# docker-compose.yml snippet
services:
  prometheus:
    image: prom/prometheus:latest
    volumes:
      - ./prometheus.yml:/etc/prometheus/prometheus.yml
    ports:
      - "9090:9090"

  grafana:
    image: grafana/grafana:latest
    ports:
      - "3000:3000"
    environment:
      - GF_SECURITY_ADMIN_PASSWORD=changeme
```

{{< admonition type="info" title="Resource Usage" >}}
With all VMs and containers running, I typically use about **24GB of RAM** and **15% CPU**. Proxmox handles memory ballooning well, so VMs only consume what they actually need.
{{< /admonition >}}

## Backups

{{< admonition type="danger" title="Don't Skip Backups!" >}}
Always set up automated backups. I learned this the hard way after a failed ZFS pool import wiped a weekend of configuration work.
{{< /admonition >}}

Proxmox has built-in backup scheduling. I run nightly backups to a separate NFS share:

```bash
# Verify backup storage is mounted
pvesm status

# List existing backups
pvesm list backup-storage
```

## What's Next

{{< details summary="Future plans for the lab" open=true >}}
- Set up a Kubernetes cluster with k3s
- Add a TrueNAS VM for centralized storage
- Configure Ansible for automated provisioning
- Implement GitOps with ArgoCD
{{< /details >}}

---

If you're thinking about building a home lab, just start small. You can always scale up later. The most important thing is to **start doing** — reading documentation only gets you so far.

Feel free to reach out if you have questions!
