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
