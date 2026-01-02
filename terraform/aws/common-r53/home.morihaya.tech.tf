# Records for home.morihaya.tech
# 自宅サーバー関連のDNSレコード。ゾーン切り出しするほどでもないため手動で .home サブドメインに追加。

locals {
  home_records = {
    pve = {
      name    = "pve.home.morihaya.tech"
      records = ["192.168.1.2"]
    }
    ceph = {
      name    = "ceph.home.morihaya.tech"
      records = ["192.168.1.3"]
    }
    dns = {
      name    = "dns.home.morihaya.tech"
      records = ["192.168.1.4"]
    }
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
