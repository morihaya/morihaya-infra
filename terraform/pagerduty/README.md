# Terraform PagerDuty

個人用の PagerDuty 設定。

## 構成

| リソース | 内容 |
|----------|------|
| `pagerduty_user.owner` | オーナーユーザー |
| `pagerduty_escalation_policy.default` | 既定のエスカレーションポリシー (30 分でオーナーへ) |
| `pagerduty_service.default` | "morihaya"。New Relic の通知先 |
| `pagerduty_service.pulse_homelab` | **"Pulse at HomeLab"**。自宅 Proxmox の監視 |

state は HCP Terraform (`morihaya-infra-pagerduty`) にあるが、**execution mode は
`local`** なので plan / apply は手元で走る。VCS 連携も無いため、PR をマージしても
run は自動起動しない。

## 実行

認証情報は環境変数で渡す。

```bash
export TF_VAR_pagerduty_token=...
```

```bash
export TF_VAR_mail_own=...
```

```bash
terraform apply
```

## Pulse からの通知設定

`pagerduty_service_integration.pulse` が Events API v2 の受け口で、その
`integration_key` が Pulse 側の `routing_key` になる。apply 後に取り出す。

```bash
terraform output -raw pulse_integration_key
```

Pulse (ct:101 / 192.168.1.5) の Settings → Alerts → Webhook で、送信先を
PagerDuty (`https://events.pagerduty.com/v2/enqueue`) とし、ペイロードを
次のテンプレートにする。

```json
{
  "routing_key": "<integration_key>",
  "event_action": "trigger",
  "dedup_key": "pulse-{{.ID}}",
  "payload": {
    "summary": "[{{.Level}}] {{.ResourceName}}: {{.Message}}",
    "severity": "{{if eq .Level \"critical\"}}critical{{else if eq .Level \"warning\"}}warning{{else}}info{{end}}",
    "source": "{{.Node}}",
    "component": "{{.ResourceType}}",
    "custom_details": {
      "resource_id": "{{.ResourceID}}",
      "value": "{{.ValueFormatted}}",
      "threshold": "{{.ThresholdFormatted}}",
      "duration": "{{.Duration}}"
    }
  }
}
```

`severity` は PagerDuty が `critical` / `error` / `warning` / `info` しか受け付け
ないため、Pulse の `.Level` から明示的に写している。`dedup_key` を `.ID` 由来に
することで、同じアラートの再送でインシデントが増殖しない。

> [!NOTE]
> Pulse の `notifyOnResolve` が無効な間、復旧通知が飛ばないためインシデントは
> サービスの `auto_resolve_timeout` (4 時間) で自動クローズされる。復旧時に
> `event_action` を `resolve` にできれば即時クローズできるが、Pulse の
> テンプレート変数に復旧を判別するものがあるかは未確認。
