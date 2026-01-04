# Homelab - Proxmox Terraform Configuration

This directory contains Terraform configuration for managing Proxmox VE resources in the homelab environment.

## Overview

- **Provider**: [bpg/proxmox](https://registry.terraform.io/providers/bpg/proxmox/latest) v0.91.0
- **Backend**: HCP Terraform (Terraform Cloud) with Agent
- **Node Count**: 1 Proxmox node
- **LXC Containers**: 2 existing containers (to be imported)

## Prerequisites

### 1. HCP Terraform Setup

1. Create a workspace in HCP Terraform: `morihaya-infra-homelab`
2. Set the workspace execution mode to "Agent"
3. Deploy an HCP Terraform Agent in your homelab network

### 2. Proxmox API Token

Create an API token on your Proxmox node:

```bash
# Create user
pveum user add terraform@pve

# Create role with necessary privileges
pveum role add Terraform -privs "Datastore.Allocate,Datastore.AllocateSpace,Datastore.AllocateTemplate,Datastore.Audit,Pool.Allocate,Pool.Audit,SDN.Audit,SDN.Use,Sys.Audit,Sys.Console,Sys.Modify,VM.Allocate,VM.Audit,VM.Clone,VM.Config.CDROM,VM.Config.CPU,VM.Config.Cloudinit,VM.Config.Disk,VM.Config.HWType,VM.Config.Memory,VM.Config.Network,VM.Config.Options,VM.Console,VM.Migrate,VM.PowerMgmt,VM.Snapshot,VM.Snapshot.Rollback"

# Assign role to user
pveum aclmod / -user terraform@pve -role Terraform

# Create API token
pveum user token add terraform@pve provider --privsep=0
```

### 3. HCP Terraform Variables

Set the following variables in your HCP Terraform workspace:

| Variable | Type | Sensitive | Description |
|----------|------|-----------|-------------|
| `PROXMOX_VE_ENDPOINT` | Environment | No | Proxmox API URL (e.g., `https://192.168.1.100:8006/`) |
| `PROXMOX_VE_API_TOKEN` | Environment | Yes | API Token (e.g., `terraform@pve!provider=xxx-xxx-xxx`) |
| `PROXMOX_VE_INSECURE` | Environment | No | Set to `true` if using self-signed certificate |

## HCP Terraform Agent Setup

### Deploy Agent with Docker

```bash
docker run -d \
  --name tfc-agent \
  --restart unless-stopped \
  -e TFC_AGENT_TOKEN=<your-agent-token> \
  -e TFC_AGENT_NAME=homelab-agent \
  hashicorp/tfc-agent:latest
```

Or with Docker Compose:

```yaml
version: "3.8"
services:
  tfc-agent:
    image: hashicorp/tfc-agent:latest
    container_name: tfc-agent
    restart: unless-stopped
    environment:
      - TFC_AGENT_TOKEN=${TFC_AGENT_TOKEN}
      - TFC_AGENT_NAME=homelab-agent
```

## Importing Existing LXC Containers

After running `terraform init`, import your existing LXC containers:

```bash
# Import LXC container with VM ID 100
terraform import proxmox_virtual_environment_container.lxc_1 pve/100

# Import LXC container with VM ID 101
terraform import proxmox_virtual_environment_container.lxc_2 pve/101
```

**Note**: Replace `pve` with your actual node name and `100`/`101` with your actual VM IDs.

## Usage

```bash
# Initialize Terraform
terraform init

# Import existing resources (see above)

# Plan changes
terraform plan

# Apply changes
terraform apply
```

## File Structure

```
homelab/
├── README.md           # This file
├── backend.tf          # HCP Terraform backend configuration
├── main.tf             # Provider configuration
├── variables.tf        # Input variables
├── lxc.tf              # LXC container resources
└── outputs.tf          # Output values
```
