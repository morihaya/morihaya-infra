# DNS records for morihaya.tech
locals {
  records = {
    gcp01 = {
      name    = "gcp01.morihaya.tech"
      records = ["34.169.244.99"]
    }
    example = {
      name    = "example.morihaya.tech"
      records = ["192.0.2.1"]
    }
    example3 = {
      name    = "example3.morihaya.tech"
      ttl     = 299
      records = ["192.0.2.4"]
    }
  }
}

module "records" {
  source   = "./modules/route53_record"
  for_each = local.records

  zone_id = data.aws_route53_zone.morihaya_tech.zone_id
  name    = each.value.name
  type    = lookup(each.value, "type", "A")
  ttl     = lookup(each.value, "ttl", 300)
  records = each.value.records
}
