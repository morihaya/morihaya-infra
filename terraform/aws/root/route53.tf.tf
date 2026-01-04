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

## Dmarc Record
resource "aws_route53_record" "dmarc" {
  zone_id = aws_route53_zone.morihaya-tech.zone_id
  name    = "_dmarc"
  type    = "TXT"
  ttl     = 3600
  records = [
    "v=DMARC1;p=reject;rua=mailto:d05c4fc08c@rua.easydmarc.us;ruf=mailto:d05c4fc08c@ruf.easydmarc.us;fo=1;"
  ]
}

# Route53 NS Records
## For Azure DNS
resource "aws_route53_record" "azure_ns" {
  zone_id = aws_route53_zone.morihaya-tech.zone_id
  name    = "azure"
  type    = "NS"
  ttl     = 3600
  records = [
    "ns1-03.azure-dns.com.",
    "ns2-03.azure-dns.net.",
    "ns3-03.azure-dns.org.",
    "ns4-03.azure-dns.info."
  ]
}
