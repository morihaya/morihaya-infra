# 既存の Route 53 レコードを Terraform 管理下に取り込むための import ブロック。
# HCP Terraform 上の apply が完了したら、このファイルは削除して構わない。

# blog.morihaya.tech (CNAME -> hatenablog.com)
import {
  to = module.records["blog"].aws_route53_record.this
  id = "${data.aws_route53_zone.morihaya_tech.zone_id}_blog.morihaya.tech_CNAME"
}
