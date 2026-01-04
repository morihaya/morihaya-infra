# morihaya-infra

Infrastructure as Code repository managing my personal environments using Terraform and Ansible.

## 🏗️ Overview

This repository contains infrastructure definitions for managing multiple cloud providers and services, demonstrating real-world Terraform practices including:

- Multi-cloud infrastructure management
- Modular Terraform architecture
- Remote state management with backend configurations
- Integration with various SaaS providers

## 📁 Repository Structure

```
.
├── terraform/          # Infrastructure as Code
│   ├── aws/            # AWS resources (Route53, Budgets, SNS)
│   ├── azure/          # Azure resources (DNS, Resource Groups)
│   ├── homelab/        # Proxmox homelab infrastructure
│   ├── newrelic/       # New Relic synthetic monitoring
│   ├── pagerduty/      # PagerDuty alerting configuration
│   ├── spotify/        # Spotify playlist management
│   └── tailscale/      # Tailscale VPN ACLs and DNS
│
└── ansible/            # Configuration Management
    ├── inventories/    # Host definitions
    └── roles/          # Reusable roles (common, docker-compose, postgres)
```

## 🛠️ Terraform Configurations

| Provider | Description |
|----------|-------------|
| **AWS** | Route53 DNS management, Budget alerts, SNS notifications |
| **Azure** | Public DNS zones, Resource group organization |
| **Homelab** | Proxmox LXC container provisioning |
| **New Relic** | Synthetic monitoring for uptime checks |
| **PagerDuty** | On-call schedules, escalation policies, service integrations |
| **Spotify** | Playlist management via Terraform provider |
| **Tailscale** | ACL policies, DNS configuration for mesh VPN |

## 🔧 Technologies

- **Terraform** - Infrastructure provisioning across multiple providers
- **Ansible** - Configuration management and automation
- **GitHub Actions** - CI/CD workflows

## 📝 License

This repository is public for educational and portfolio purposes.
