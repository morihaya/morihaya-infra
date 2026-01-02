# Records for home.morihaya.tech
# 自宅サーバー関連のDNSレコード。ゾーン切り出しするほどでもないため手動で .home サブドメインに追加。

resource "aws_route53_record" "pve_home" {
  zone_id = data.aws_route53_zone.morihaya_tech.zone_id
  name    = "pve.home.morihaya.tech"
  type    = "A"
  ttl     = 300
  records = ["192.168.1.2"]
  lifecycle {
    create_before_destroy = true
  }
}
