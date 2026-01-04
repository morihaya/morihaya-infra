resource "aws_route53domains_registered_domain" "morihaya-tech" {
  domain_name = "morihaya.tech"

  name_server {
    name = "ns-1199.awsdns-21.org"
  }
  name_server {
    name = "ns-1989.awsdns-56.co.uk"
  }
  name_server {
    name = "ns-771.awsdns-32.net"
  }
  name_server {
    name = "ns-64.awsdns-08.com"
  }
}

resource "aws_route53_zone" "morihaya-tech" {
  comment           = "Registered in Route53"
  delegation_set_id = null
  force_destroy     = null
  name              = "morihaya.tech"
  tags              = {}
  tags_all          = {}
}


# Route53 Txt Records

## Google Postmaster Tools
resource "aws_route53_record" "googole_postmaster_tools" {
  zone_id = aws_route53_zone.morihaya-tech.zone_id
  name    = ""
  type    = "TXT"
  ttl     = 300
  records = [
    "google-site-verification=KrWd-ES4dWt0_LSLo8F_-oX7ZnclQesj17VEViVP_Wo"
  ]
}
