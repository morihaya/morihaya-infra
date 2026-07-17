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
