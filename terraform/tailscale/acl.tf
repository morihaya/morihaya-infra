resource "tailscale_acl" "acl" {
  acl = templatefile("${path.module}/acl.json.tpl", {
    user = var.mail_own
  })
}
