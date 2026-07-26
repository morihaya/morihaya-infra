# HCP Terraform - ワークスペース管理

HCP Terraform 自体を Terraform で管理するルート。本リポジトリが使う
ワークスペースの設定をコード化する。

## なぜやるのか

ワークスペースの設定は UI にしか無く、**壊れていても気づけない**。
実際に 2026-07 の調査で以下が判明した。

- `morihaya-infra-newrelic` / `-pagerduty` / `-tailscale` が **Terraform 1.0.8** のまま
- `auto_apply` がワークスペースごとにバラバラ (`-aws-common-r53` と `-azure` だけ有効)
- `speculative_enabled` も不統一。無効なワークスペースは PR 時に plan が走らない
- `working_directory` の先頭・末尾スラッシュ、`trigger_patterns` の `./` 有無が不統一
- ワークスペースの `terraform_version` が `~>1.14.0` なのにリポジトリの
  [.terraform-version](../../.terraform-version) は `1.15.0` で不整合。
  ローカルから state を操作しようとすると弾かれる

さらに、Dependabot の run が確認待ちのまま 1 ヶ月以上放置されて
ワークスペースがロックし、その裏で apply が半年止まっていたことも
[#64](https://github.com/morihaya/morihaya-infra/pull/64) で判明した。
UI 任せの運用が実害を出している。

## 管理対象

| ワークスペース | project | working_directory | exec | Terraform | auto_apply | speculative |
|---|---|---|---|---|---|---|
| `-aws-common-r53` | AWS | `terraform/aws/common-r53` | remote | `~>1.14.0` | **true** | true |
| `-aws-root` | AWS | `terraform/aws/root/` | remote | `~>1.14.0` | false | **false** |
| `-azure` | Azure | `/terraform/azure` | remote | `~>1.14.0` | **true** | true |
| `-homelab` | HomeLab | `/terraform/homelab` | **agent** | `~>1.14.0` | false | true |
| `-newrelic` | Default | `/terraform/newrelic/` | remote | **1.0.8** | false | **false** |
| `-pagerduty` | Default | (なし) | **local** | **1.0.8** | false | false |
| `-tailscale` | Default | (なし) | **local** | **1.0.8** | false | false |

`-pagerduty` と `-tailscale` は VCS 連携が無く `execution_mode = local`。
HCP は state の保管場所としてのみ使われ、plan / apply は手元で走る。

`terraform/spotify` は HCP を使わずローカル state なので、対応する
ワークスペースは存在しない。

> [!IMPORTANT]
> 現時点のコードは**実態をそのまま写し取っているだけ**で、上表のバラつきは
> 意図的に現状のまま記述している。plan を no-op に保つため。
> 統一は別 PR で行う。

## 自分自身は管理しない

このルートを動かす `morihaya-infra` ワークスペース (working directory
`/terraform/hcpterraform`) は**管理対象に含めていない**。自分が乗っている枝を
切る事故を防ぐため、このワークスペースだけは手動で作成・管理する。

ワークスペースの `destroy` は **state の消失**を意味するため、全ワークスペースに
`prevent_destroy = true` を付けている。

## 認証情報

`tfe` provider には org の owners team 権限を持つ API トークンが必要で、
これは**本リポジトリで使うどの認証情報よりも強い**。ワークスペース
`morihaya-infra` の環境変数 `TFE_TOKEN` に sensitive で設定する。

| 変数 | 種別 | Sensitive | 説明 |
|------|------|-----------|------|
| `TFE_TOKEN` | **Terraform** | Yes | org owner 権限の API トークン |

種別が Environment ではなく **Terraform** である点に注意。`tfe` provider は
環境変数 `TFE_TOKEN` を読む仕様だが、それに頼ると「変数は設定したのに認証が
通らない」という分かりにくい失敗をする。[providers.tf](providers.tf) で
`token = var.TFE_TOKEN` と明示的に渡す形にしてある。

空にしておくと provider 標準の探索 (環境変数 → Terraform CLI config の
credentials) にフォールバックする。手元から実行する場合はこの経路になる。

> [!NOTE]
> **新規ワークスペースは初回だけ手動で run をキューする必要がある。**
> `queue_all_runs = false` の場合、HCP は「一度も手動で run がキューされて
> いないワークスペース」では webhook 起因の run をキューしない。
> 実際にこのワークスペースは作成から半年間 run が 0 件で、VCS 連携の設定は
> 正しいのに PR を出しても plan が走らなかった。UI から一度 "Start new run"
> すれば以降は自動で走る。

## 変数の値は管理しない

各ワークスペースが必要とする変数は org の variable set 側にあり、本ルートでは
**管理していない**。理由は 2 つ。

1. 機密値をコードに置けない。このリポジトリは公開されている
2. アカウント ID (`aws_accountid` / `newrelic_accountid`) やエンドポイントは
   機密ではないが識別情報になる。公開する実益が無い

将来的には Proxmox 上に HashiCorp Vault (Community Edition) を立て、そちらで
認証情報を管理する方針。その時点で variable set の扱いを再検討する。

## 不透明な識別子をコードに書かない

project ID / agent pool ID / GitHub App installation ID は `ghain-xxxx` のような
HCP 内部の識別子だが、公開リポジトリに並べる必要が無いので**全てデータソースで
名前から引いている**。

```hcl
data "tfe_project" "homelab" {
  name         = "HomeLab"
  organization = var.tfe_organization
}
```

## Usage

```bash
terraform init
```

```bash
terraform plan
```

初回 apply 後は [imports.tf](imports.tf) を削除してよい。

## 今後

- [ ] `terraform_version` を全ワークスペースで統一し、`.terraform-version` と揃える
- [ ] `working_directory` と `trigger_patterns` の表記を統一する
- [ ] `speculative_enabled` を全ワークスペースで有効にし、PR 時に必ず plan させる
- [ ] `auto_apply` の方針を決める (現在は 2 つだけ有効で一貫していない)
- [ ] Vault 導入後に variable set の管理方法を再検討する
