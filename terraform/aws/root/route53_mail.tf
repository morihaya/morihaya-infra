## Root txt for morihaya.tech
moved {
  from = aws_route53_record.googole_postmaster_tools
  to   = aws_route53_record.root
}
resource "aws_route53_record" "root" {
  zone_id = aws_route53_zone.morihaya-tech.zone_id
  name    = ""
  type    = "TXT"
  ttl     = 300
  records = [
    "google-site-verification=KrWd-ES4dWt0_LSLo8F_-oX7ZnclQesj17VEViVP_Wo", # For postmaster tools
    "v=spf1 mx ra=postmaster -all"                                          # SPF Record
  ]
}

## Dmarc Record
resource "aws_route53_record" "dmarc" {
  zone_id = aws_route53_zone.morihaya-tech.zone_id
  name    = "_dmarc"
  type    = "TXT"
  ttl     = 3600
  records = [
    "v=DMARC1; p=reject; rua=mailto:d05c4fc08c@rua.easydmarc.us,mailto:postmaster@morihaya.tech,mailto:dmarc_agg@vali.email; ruf=mailto:d05c4fc08c@ruf.easydmarc.us,mailto:postmaster@morihaya.tech; fo=1;"
  ]
}

## A Record for mail.morihaya.tech
resource "aws_route53_record" "mail_a" {
  zone_id = aws_route53_zone.morihaya-tech.zone_id
  name    = "mail"
  type    = "A"
  ttl     = 300
  records = [
    "34.169.244.99" # Public IP
  ]
}

## MX Record for mail.morihaya.tech
resource "aws_route53_record" "mail_mx" {
  zone_id = aws_route53_zone.morihaya-tech.zone_id
  name    = "morihaya.tech"
  type    = "MX"
  ttl     = 300
  records = [
    "10 mail.morihaya.tech."
  ]
}

## DKIM Record for mail.morihaya.tech
resource "aws_route53_record" "dkim_1" {
  zone_id = aws_route53_zone.morihaya-tech.zone_id
  name    = "202601e._domainkey"
  type    = "TXT"
  ttl     = 300
  records = [
    "v=DKIM1; k=ed25519; h=sha256; p=UiU34pbHXcp8jeHIDomrsdadAthCH7AvFoHLPclmHJE="
  ]
}

# Route53の仕様で255文字を超えるTXTレコードは分割して登録する必要があるため、localで分割したものを結合して登録する。
locals {
  dkim2_value = "v=DKIM1; k=rsa; h=sha256; p=MIIBIjANBgkqhkiG9w0BAQEFAAOCAQ8AMIIBCgKCAQEAwVcAQOH0Uaq/my3mSoBfTsKdfaNuIdRoxYqUzzg79onMx9fO/69uzYeBEcFa+SoE3j04Z2PJHlimK71QECIe5QKXyag16fOtUz8PPy2ZVIXi4JKP4ZJlrouZ0FPvWeC/wNV1eWvvKGqodTwV9375C0ktZcQ8AMEu/O2GWelfyQ6szWQVVnrzXgqvWwEuyWSQsrmXRoP0trOh1EAw9qDsNRe6ToBOyCxso8OGyhabLtEcYT3NEn7xrYA714hbkWGBkJabjOBEMOJLcqrKJcsQvxgKX9Nwiq0KFjIRGnEpX5qs6Uijea8fQjPNswLXpyiC2w10/Hah6mlpLnaSN0bYuwIDAQAB"
}
resource "aws_route53_record" "dkim_2" {
  zone_id = aws_route53_zone.morihaya-tech.zone_id
  name    = "202601r._domainkey"
  type    = "TXT"
  ttl     = 300
  records = [
    join("\"\"", regexall(".{1,255}", local.dkim2_value))
  ]
}

## SPF Record for mail.morihaya.tech
resource "aws_route53_record" "spf_mail" {
  zone_id = aws_route53_zone.morihaya-tech.zone_id
  name    = "mail"
  type    = "TXT"
  ttl     = 300
  records = [
    "v=spf1 a ra=postmaster -all"
  ]
}

## SRV Records for mail service discovery
resource "aws_route53_record" "srv_jmap" {
  zone_id = aws_route53_zone.morihaya-tech.zone_id
  name    = "_jmap._tcp"
  type    = "SRV"
  ttl     = 300
  records = ["0 1 443 mail.morihaya.tech."]
}

resource "aws_route53_record" "srv_caldavs" {
  zone_id = aws_route53_zone.morihaya-tech.zone_id
  name    = "_caldavs._tcp"
  type    = "SRV"
  ttl     = 300
  records = ["0 1 443 mail.morihaya.tech."]
}

resource "aws_route53_record" "srv_carddavs" {
  zone_id = aws_route53_zone.morihaya-tech.zone_id
  name    = "_carddavs._tcp"
  type    = "SRV"
  ttl     = 300
  records = ["0 1 443 mail.morihaya.tech."]
}

resource "aws_route53_record" "srv_imaps" {
  zone_id = aws_route53_zone.morihaya-tech.zone_id
  name    = "_imaps._tcp"
  type    = "SRV"
  ttl     = 300
  records = ["0 1 993 mail.morihaya.tech."]
}

resource "aws_route53_record" "srv_imap" {
  zone_id = aws_route53_zone.morihaya-tech.zone_id
  name    = "_imap._tcp"
  type    = "SRV"
  ttl     = 300
  records = ["0 1 143 mail.morihaya.tech."]
}

resource "aws_route53_record" "srv_pop3s" {
  zone_id = aws_route53_zone.morihaya-tech.zone_id
  name    = "_pop3s._tcp"
  type    = "SRV"
  ttl     = 300
  records = ["0 1 995 mail.morihaya.tech."]
}

resource "aws_route53_record" "srv_pop3" {
  zone_id = aws_route53_zone.morihaya-tech.zone_id
  name    = "_pop3._tcp"
  type    = "SRV"
  ttl     = 300
  records = ["0 1 110 mail.morihaya.tech."]
}

resource "aws_route53_record" "srv_submissions" {
  zone_id = aws_route53_zone.morihaya-tech.zone_id
  name    = "_submissions._tcp"
  type    = "SRV"
  ttl     = 300
  records = ["0 1 465 mail.morihaya.tech."]
}

resource "aws_route53_record" "srv_submission" {
  zone_id = aws_route53_zone.morihaya-tech.zone_id
  name    = "_submission._tcp"
  type    = "SRV"
  ttl     = 300
  records = ["0 1 587 mail.morihaya.tech."]
}

## CNAME Records for mail autodiscovery
resource "aws_route53_record" "autoconfig" {
  zone_id = aws_route53_zone.morihaya-tech.zone_id
  name    = "autoconfig"
  type    = "CNAME"
  ttl     = 300
  records = ["mail.morihaya.tech."]
}

resource "aws_route53_record" "autodiscover" {
  zone_id = aws_route53_zone.morihaya-tech.zone_id
  name    = "autodiscover"
  type    = "CNAME"
  ttl     = 300
  records = ["mail.morihaya.tech."]
}

resource "aws_route53_record" "smtp" {
  zone_id = aws_route53_zone.morihaya-tech.zone_id
  name    = "_smtp._tls"
  type    = "TXT"
  ttl     = 300
  records = ["v=TLSRPTv1; rua=mailto:postmaster@morihaya.tech"]
}
