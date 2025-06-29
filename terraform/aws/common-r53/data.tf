# rroute53 zone data source
data "aws_route53_zone" "morihaya_tech" {
  name         = "morihaya.tech"
  private_zone = false
}
