# Records for home.morihaya.tech
# 自宅サーバー関連のDNSレコード。ゾーン切り出しするほどでもないため手動で .home サブドメインに追加。

locals {
  home_records = {
    pve = {
      name    = "pve.home.morihaya.tech"
      records = ["192.168.1.6"] # 実IPは 192.168.1.2 だがTraefik経由でアクセス
    }
    ceph = {
      name    = "ceph.home.morihaya.tech"
      records = ["192.168.1.3"]
    }
    dns = {
      name    = "dns.home.morihaya.tech"
      records = ["192.168.1.6"] # 実IPは 192.168.1.4 だがTraefik経由でアクセス
    }
    pulse = {
      name    = "pulse.home.morihaya.tech"
      records = ["192.168.1.6"] # 実IPは 192.168.1.5 だがTraefik経由でアクセス
    }
    traefik = {
      name    = "traefik.home.morihaya.tech"
      records = ["192.168.1.6"]
    }
    stalwart = {
      name    = "stalwart.home.morihaya.tech"
      records = ["192.168.1.6"] # 実IPは 192.168.1.8 だがTraefik経由でアクセス
    }
}

module "home_records" {
  source   = "./modules/route53_record"
  for_each = local.home_records

  zone_id = data.aws_route53_zone.morihaya_tech.zone_id
  name    = each.value.name
  type    = lookup(each.value, "type", "A")
  ttl     = lookup(each.value, "ttl", 300)
  records = each.value.records
}
