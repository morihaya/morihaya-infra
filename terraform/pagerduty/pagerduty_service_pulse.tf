# =============================================================================
# Pulse at HomeLab
#
# 自宅 Proxmox クラスタ morihaya の監視。ct:101 (192.168.1.5) で動く Pulse から
# Events API v2 で通知を受ける。
#
# 既存の "morihaya" サービスへ相乗りさせず専用サービスを立てているのは、
# あちらが New Relic の通知先を兼ねており、自宅インフラのアラートが混ざると
# インシデント一覧で見分けが付かなくなるため。
# =============================================================================
resource "pagerduty_service" "pulse_homelab" {
  name              = "Pulse at HomeLab"
  escalation_policy = pagerduty_escalation_policy.default.id
  alert_creation    = "create_alerts_and_incidents"

  description = <<-EOT
        Managed by Terraform.
        自宅 Proxmox クラスタ (pve / pve2 / pve3) の監視アラート。
        送信元: Pulse (ct:101 / 192.168.1.5)
        ダッシュボード: https://pulse.home.morihaya.tech
        構成: terraform/homelab
    EOT

  # Pulse 側の notifyOnResolve が無効な間、復旧通知が飛んでこないため
  # インシデントはこのタイムアウトで自動クローズされる。
  # Pulse から resolve を送るようにしたらここは短縮してよい。
  auto_resolve_timeout    = 14400
  acknowledgement_timeout = 600
}

# -----------------------------------------------------------------------------
# Events API v2 の受け口。integration_key が Pulse 側の routing_key になる。
# -----------------------------------------------------------------------------
resource "pagerduty_service_integration" "pulse" {
  name    = "Pulse Events API v2"
  service = pagerduty_service.pulse_homelab.id
  type    = "events_api_v2_inbound_integration"
}

## Output Values
output "pulse_integration_key" {
  description = "Routing key for the Pulse webhook. Read it with `terraform output -raw pulse_integration_key`."
  value       = pagerduty_service_integration.pulse.integration_key
  # 本リポジトリは公開しているため、run のログに出さない。
  sensitive = true
}
