resource "aws_route53_zone" "morihaya-tech" {
  comment           = "muumuu-domain.com"
  delegation_set_id = null
  force_destroy     = null
  name              = "morihaya.tech"
  tags              = {}
  tags_all          = {}
}
