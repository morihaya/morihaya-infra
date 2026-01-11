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
    "v=DMARC1;p=reject;rua=mailto:d05c4fc08c@rua.easydmarc.us,mailto:postmaster@morihaya.tech;ruf=mailto:d05c4fc08c@ruf.easydmarc.us,mailto:postmaster@morihaya.tech;fo=1;"
  ]
}

## A Record for mail.morihaya.tech
resource "aws_route53_record" "mail_a" {
  zone_id = aws_route53_zone.morihaya-tech.zone_id
  name    = "mail"
  type    = "A"
  ttl     = 300
  records = [
    "106.73.59.225" # Dynamic IP
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
    "v=DKIM1; k=ed25519; h=sha256; p=KJE3gVewwPZd9dUzb6meTbEscgQjRKZSw3XRKCX5+Zk="
  ]
}
resource "aws_route53_record" "dkim_2" {
  zone_id = aws_route53_zone.morihaya-tech.zone_id
  name    = "202601r._domainkey"
  type    = "TXT"
  ttl     = 300
  records = [
    join("", [
      "\"v=DKIM1; k=rsa; h=sha256; p=MIIBIjANBgkqhkiG9w0BAQEFAAOCAQ8AMIIBCgKCAQEAzcO4IIjzKwHGAZvVPfzxqWDSQ/Tgy3+lgqc5wh8OEnq5ne3MweVLawxBLIbfXn4mALfr899l/pO35XsR0xQM3LxGJ5H0m/z6V/I/FDKHGCWJLG7n0faXk6rlejDrx+Roz25C3cKqxJulKzhE\"",
      "\"tJbiYiDxxVZPi7jS0X6Si9I/1NlLyDTNO9eo8Mrh+PYh0hcikfzdwg8sRXNITpBycvv85mHaY1k+j4+NwLCPvJMvtUJOnzXXNLYafxNJZ0aP3zI/Oun8gmnPojUwndwH8aXq/lSLuMKLjhsmvK8HTfNgc2YjFAh2jtW8SDRIbie4oojdc69Dgv68M+LA1kVQ4zdszwIDAQAB\""
    ])
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
