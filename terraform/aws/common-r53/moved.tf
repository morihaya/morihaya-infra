# Moved blocks for migrating from individual resources to modules

# r53.tf records
moved {
  from = aws_route53_record.example
  to   = module.records["example"].aws_route53_record.this
}

moved {
  from = aws_route53_record.example3
  to   = module.records["example3"].aws_route53_record.this
}

# home.morihaya.tech.tf records
moved {
  from = aws_route53_record.pve_home
  to   = module.home_records["pve"].aws_route53_record.this
}

moved {
  from = aws_route53_record.ceph_home
  to   = module.home_records["ceph"].aws_route53_record.this
}

moved {
  from = aws_route53_record.dns_home
  to   = module.home_records["dns"].aws_route53_record.this
}
