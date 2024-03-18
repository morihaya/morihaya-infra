resource "aws_route53_zone" "morihaya-tech" {
  comment           = "muumuu-domain.com"
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
