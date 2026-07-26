# Homelab - Proxmox Terraform Configuration

自宅の Proxmox VE クラスタ `morihaya` を管理する Terraform 設定。

## Overview

- **Provider**: [bpg/proxmox](https://registry.terraform.io/providers/bpg/proxmox/latest) `~> 0.111.0`
- **Backend**: HCP Terraform (org `morihaya` / workspace `morihaya-infra-homelab`)
- **Execution mode**: Agent (VM 103 の HCP Terraform Agent 経由)
- **Proxmox VE**: 9.1

### クラスタ構成

| ノード | IP | CPU | メモリ | ディスク |
|--------|-----|-----|--------|----------|
| `pve`  | 192.168.1.2  | 4 core | 16GB  | NVMe 477GB |
| `pve2` | 192.168.1.10 | AMD E1-2500 2 core | 7.5GB | SATA SSD 480GB |
| `pve3` | 192.168.1.11 | i5-7400T 4 core | 8GB | NVMe 256GB |

### 管理対象ゲスト

| ID | 種別 | 名前 | IP | 定位置 | 用途 |
|----|------|------|-----|--------|------|
| 100 | LXC | dns01 | 192.168.1.4 | pve | AdGuard Home (DNS + DHCP) |
| 101 | LXC | pulse | 192.168.1.5 | pve | Proxmox 監視 |
| 102 | LXC | traefik | 192.168.1.6 | pve | リバースプロキシ |
| 103 | VM  | hcp-terraform-agent | DHCP | pve | HCP Terraform Agent |
| 104 | LXC | homepage | 192.168.1.8 | pve | ダッシュボード |
| 105 | LXC | gh-runner | 192.168.1.9 | pve3 | GitHub Actions セルフホストランナー |

## High Availability

2026-07-25 に pve が停止した際、DNS / DHCP / Traefik が揃って落ちた。3 ノードの
クラスタは正常だったが、HA 登録されていたのが `ct:105` の 1 件のみで、かつ
共有ストレージもレプリケーションも無かったため。

その恒久対策として **2026-07-26 に全ノードを ZFS 化**し、`pvesr` による
ストレージレプリケーションと HA を有効化した。移行の記録は
[docs/zfs-ha-migration.md](docs/zfs-ha-migration.md) を参照。

| 変数 | 移行前 | 現在 |
|------|--------|------|
| `guest_datastore_id` | `local-lvm` | **`local-zfs`** |
| `enable_ha` | `false` | **`true`** |

> [!NOTE]
> この 2 つは**コード内の `default` で管理しており、HCP のワークスペース変数
> としては設定していない**。UI に隠れた状態を作らず、PR の speculative plan で
> 差分を確認できるようにするため。変更する場合は
> [variables.tf](variables.tf) を編集する。

HA 有効時のフェイルオーバー設計は [ha.tf](ha.tf) の `local.ha_guests` を参照。
共有ストレージが無いため、レプリカを持つ 2 ノードにだけ移動を許す
`strict = true` の node-affinity ルールを併用している。

## File Structure

```
homelab/
├── README.md                      # このファイル
├── versions.tf                    # terraform ブロック / cloud backend / provider 制約
├── providers.tf                   # provider 設定
├── variables.tf                   # 入力変数
├── ha.tf                          # ZFS ストレージ・レプリケーション・HA (enable_ha でゲート)
├── 100lxc_dns01.tf                # 各ゲストの定義 (1 ファイル 1 ゲスト)
├── 101lxc_pulse.tf
├── 102lxc_traefik.tf
├── 103vm_hcp_terraform_agent.tf
├── 104lxc_homepage.tf
├── 105lxc_gh_runner.tf
└── docs/
    └── zfs-ha-migration.md        # ZFS 移行と HA 有効化の手順書
```

## 設定上の約束ごと

- HA でフェイルオーバーしうるゲストは `node_name` を `ignore_changes` に入れる。
  入れないと HA が移動させた直後に Terraform が元ノードへ戻そうとする。
  ただし **これだけでは不十分**。bpg プロバイダは state の `node_name` の
  ノードにしかコンテナを問い合わせないため、フェイルオーバー後の plan は
  「削除された → 作り直す」になる (プロバイダ側の Known Issue)。
  復旧手順は [docs/zfs-ha-migration.md](docs/zfs-ha-migration.md) の
  「フェイルオーバー後の state 復旧」を参照。
- ゲストのディスク配置は `var.guest_datastore_id` を通す。実機の状態と
  ズレたまま apply するとディスクの再作成が走るため、ストレージ移行と
  変数変更は必ずセットで行う。
- `initialization` と `operating_system` は手動作成のコンテナを import した
  経緯から `ignore_changes` に入っている。IP を変えたい場合は Proxmox 側で
  変更すること。

## Prerequisites

### Proxmox API Token

```bash
pveum user add terraform@pve
```

```bash
pveum role add Terraform -privs "Datastore.Allocate,Datastore.AllocateSpace,Datastore.AllocateTemplate,Datastore.Audit,Pool.Allocate,Pool.Audit,SDN.Audit,SDN.Use,Sys.Audit,Sys.Console,Sys.Modify,VM.Allocate,VM.Audit,VM.Clone,VM.Config.CDROM,VM.Config.CPU,VM.Config.Cloudinit,VM.Config.Disk,VM.Config.HWType,VM.Config.Memory,VM.Config.Network,VM.Config.Options,VM.Console,VM.Migrate,VM.PowerMgmt,VM.Snapshot,VM.Snapshot.Rollback"
```

```bash
pveum aclmod / -user terraform@pve -role Terraform
```

```bash
pveum user token add terraform@pve provider --privsep=0
```

> [!NOTE]
> HA とレプリケーションを Terraform から管理する際に権限不足なら apply 時に
> 403 が返る。その時点で `pveum role modify` で権限を足すこと。

### HCP Terraform ワークスペース変数

| 変数 | 種別 | Sensitive | 説明 |
|------|------|-----------|------|
| `PROXMOX_VE_ENDPOINT` | Environment | No | Proxmox API URL |
| `PROXMOX_VE_API_TOKEN` | Environment | Yes | `terraform@pve!provider=xxx` |
| `PROXMOX_VE_INSECURE` | Environment | No | 自己署名証明書なら `true` |

### HCP Terraform Agent

```bash
docker run -d --name tfc-agent --restart unless-stopped -e TFC_AGENT_TOKEN=<your-agent-token> -e TFC_AGENT_NAME=homelab-agent hashicorp/tfc-agent:latest
```

> [!WARNING]
> Agent は VM 103 上で動いており、その 103 は pve 上にある。つまり
> **pve が落ちると Terraform の plan / apply ができなくなる**。
> ZFS 移行後は 103 を pve 以外のノードへ移すことを推奨する。

## Usage

```bash
terraform init
```

```bash
terraform plan
```

```bash
terraform apply
```
