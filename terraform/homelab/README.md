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
| 106 | VM  | openclaw | 192.168.1.12 | pve3 | OpenClaw 執事エージェント (Slack + Bedrock) |

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
├── 106vm_openclaw.tf              # 唯一 Terraform で新規作成した VM (cloud-init)
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
  変更すること。**ただし 106 は Terraform で新規作成したため対象外**で、
  cloud-init の設定はコードが正となる。
- HA リソース ID には `ct:` / `vm:` の種別プレフィックスが必要。
  `local.ha_guests` の `type` は省略時 `ct` として扱うため、LXC のエントリには
  書かない (106 のみ `type = "vm"`)。
- **ディスクの `import_from` は `images` か `import` タイプのストレージにある
  ファイルしか受け付けない。** `local` に content_type = `iso` で置いた cloud
  image を指定すると apply が次のエラーで失敗する。
  ```
  scsi0: local:iso/debian-12-genericcloud-amd64.img has wrong type 'iso'
  - needs to be 'images' or 'import'
  ```
  そのため cloud image は専用の `image-import` ストレージ
  ([106vm_openclaw.tf](106vm_openclaw.tf) の `proxmox_storage_directory`) に
  `import` タイプで置いている。`local` に `import` を足す手もあるが、`local` は
  全ノードの ISO・バックアップ・コンテナテンプレートを抱えているため
  Terraform 管理下に取り込まない。
- **Terraform が新規作成するゲストを HA に載せる場合、`ha.tf` の
  `proxmox_replication` に `depends_on` を足す。** 依存が無いとゲスト作成と
  並行してレプリケーションジョブ作成が走り「そんなゲストは無い」で失敗する。
  100-105 は import 済みで常に存在していたため露呈していなかった。

## Prerequisites

### Proxmox API Token

```bash
pveum user add terraform@pve
```

```bash
pveum role add Terraform -privs "Datastore.Allocate,Datastore.AllocateSpace,Datastore.AllocateTemplate,Datastore.Audit,Pool.Allocate,Pool.Audit,SDN.Audit,SDN.Use,Sys.Audit,Sys.Console,Sys.Modify,VM.Allocate,VM.Audit,VM.Clone,VM.Config.CDROM,VM.Config.CPU,VM.Config.Cloudinit,VM.Config.Disk,VM.Config.HWType,VM.Config.Memory,VM.Config.Network,VM.Config.Options,VM.Console,VM.Migrate,VM.PowerMgmt,VM.Replicate,VM.Snapshot,VM.Snapshot.Rollback"
```

```bash
pveum aclmod / -user terraform@pve -role Terraform
```

```bash
pveum user token add terraform@pve provider --privsep=0
```

> [!IMPORTANT]
> **`VM.Replicate` は `pvesr` のレプリケーションジョブ作成に必須。**
> 当初の権限一覧には含まれておらず、2026-07-26 の HA 有効化 apply が
> 次のエラーで失敗した。
>
> ```
> error creating Replication: received an HTTP 403 response
> Reason: Forbidden (Permission check failed (/vms/100, VM.Replicate))
> ```
>
> 既存ロールへ後から足す場合は `--append` を使う (付けないと権限一覧が
> 置き換わる)。
>
> ```bash
> pveum role modify Terraform --privs VM.Replicate --append 1
> ```
>
> HA リソースとルールの操作には `Sys.Console` が要るが、これは当初から
> 含まれている。

### HCP Terraform ワークスペース変数

Homelab variable set (HomeLab プロジェクトに紐付け) に登録する。

| 変数 | 種別 | Sensitive | 説明 |
|------|------|-----------|------|
| `PROXMOX_VE_ENDPOINT` | **Environment** | No | Proxmox API URL |
| `PROXMOX_VE_API_TOKEN` | **Environment** | Yes | `terraform@pve!provider=xxx` |
| `PROXMOX_VE_INSECURE` | **Environment** | No | 自己署名証明書なら `true` |

> [!IMPORTANT]
> **種別は Environment。** provider は OS の環境変数として読むため。
> Terraform 種別にすると「宣言されていない Terraform 変数に値が渡っている」
> ことになり、plan のたびに `Warning: Value for undeclared variable` が出る。
>
> 宣言を足して黙らせることもできるが、provider が使わない変数の
> `tflint-ignore` 付きダミー宣言が増えるだけになる。実際に 2026-07-26 まで
> その状態で、`variables.tf` に 3 つのダミー宣言が置かれていた。

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
