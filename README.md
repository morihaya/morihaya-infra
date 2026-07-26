# morihaya-infra

[![Terraform Format Check](https://github.com/morihaya/morihaya-infra/actions/workflows/terraform-fmt.yml/badge.svg)](https://github.com/morihaya/morihaya-infra/actions/workflows/terraform-fmt.yml)
[![Terraform Validate](https://github.com/morihaya/morihaya-infra/actions/workflows/terraform-validate.yml/badge.svg)](https://github.com/morihaya/morihaya-infra/actions/workflows/terraform-validate.yml)
[![Actionlint](https://github.com/morihaya/morihaya-infra/actions/workflows/actionlint.yml/badge.svg)](https://github.com/morihaya/morihaya-infra/actions/workflows/actionlint.yml)
[![Ansible Lint](https://github.com/morihaya/morihaya-infra/actions/workflows/ansible-lint.yml/badge.svg)](https://github.com/morihaya/morihaya-infra/actions/workflows/ansible-lint.yml)
[![Dependabot Updates](https://github.com/morihaya/morihaya-infra/actions/workflows/dependabot/dependabot-updates/badge.svg)](https://github.com/morihaya/morihaya-infra/actions/workflows/dependabot/dependabot-updates)
[![CodeQL](https://github.com/morihaya/morihaya-infra/actions/workflows/github-code-scanning/codeql/badge.svg)](https://github.com/morihaya/morihaya-infra/actions/workflows/github-code-scanning/codeql)

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
    ├── inventories/    # Host definitions (plaintext; see ansible/README.md)
    └── roles/          # Reusable roles (common)
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

## 📐 Conventions

- Each Terraform root follows the same layout: `versions.tf` (terraform block,
  provider requirements, HCP Terraform `cloud` backend), `providers.tf`,
  `variables.tf`, and resource files
- State lives in HCP Terraform (org: `morihaya`), one workspace per root
- Provider versions are pinned and `.terraform.lock.hcl` files are committed
- The Terraform CLI version for local development is pinned in
  [.terraform-version](.terraform-version) (tfenv/mise compatible)
- CI runs `terraform fmt -check`, `terraform validate`, `tflint`, `ansible-lint`,
  and `actionlint`; GitHub Actions are pinned to commit SHAs (via pinact)

## 🔑 Local HCP Terraform credentials

State lives in the personal org `morihaya`. If the default credentials file
(`~/.terraform.d/credentials.tfrc.json`) holds a different account's token,
`terraform init` fails with `organization "morihaya" ... not found` — this is an
account mismatch, not an expired token.

Point Terraform at the right credentials file with `TF_CLI_CONFIG_FILE`. The
committed `.gitignore` reserves `mise.local.toml` for this machine-local setting:

```toml
[env]
TF_CLI_CONFIG_FILE = "{{env.HOME}}/.terraformrc-morihaya"
```

New checkouts need `mise trust` once before mise will read it.

## 📝 License

This repository is public for educational and portfolio purposes.
