# a record for example.morihaya.tech
resource "aws_route53_record" "example" {
  zone_id = data.aws_route53_zone.morihaya_tech.zone_id
  name    = "example.morihaya.tech"
  type    = "A"
  ttl     = 300
  records = ["192.0.2.1"]
  lifecycle {
    create_before_destroy = true
  }
}

# a record for example.morihaya.tech
resource "aws_route53_record" "example3" {
  zone_id = data.aws_route53_zone.morihaya_tech.zone_id
  name    = "example3.morihaya.tech"
  type    = "A"
  ttl     = 299
  records = ["192.0.2.3"]
  lifecycle {
    create_before_destroy = true
  }
}

# Testing for No changes
