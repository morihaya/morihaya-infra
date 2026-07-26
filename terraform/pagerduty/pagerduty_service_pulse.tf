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
  auto_resolve_timeout = 86400

  # 自宅環境であり、ACK し忘れたからといって再通知で追い立てたくないため無効。
  #
  # この属性は型が string で、無効化は HCL の null ではなく文字列 "null" で表す。
  # HCL の null を書くと「未設定」と解釈され、provider が既定値 1800 を入れる。
  acknowledgement_timeout = "null"

  # =========================================================================
  # 対応時間帯による緊急度の出し分け
  #
  # 自宅サーバなので、深夜に high で叩き起こされるのを避ける。
  # 平日 10:00-22:00 (JST) は high、それ以外は low。
  # 時間外に発生して未解決のまま対応時間に入ったものは high へ昇格させる。
  # =========================================================================
  incident_urgency_rule {
    type = "use_support_hours"

    during_support_hours {
      type    = "constant"
      urgency = "high"
    }

    outside_support_hours {
      type    = "constant"
      urgency = "low"
    }
  }

  support_hours {
    type         = "fixed_time_per_day"
    time_zone    = "Asia/Tokyo"
    days_of_week = [1, 2, 3, 4, 5]
    start_time   = "10:00:00"
    end_time     = "22:00:00"
  }

  scheduled_actions {
    type       = "urgency_change"
    to_urgency = "high"

    at {
      type = "named_time"
      name = "support_hours_start"
    }
  }
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
