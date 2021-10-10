resource "tailscale_acl" "acl" {
  acl = data.template_file.acl.rendered
}


data "template_file" "acl" {
  template = file("${path.module}/acl.json.tpl")

  vars = {
    user = var.mail_own
  }
}
