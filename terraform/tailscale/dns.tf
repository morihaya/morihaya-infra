resource "tailscale_dns_nameservers" "nameservers" {
  nameservers = [
    "8.8.8.8",
    "8.8.4.4",
    "1.1.1.1",
    "1.1.1.2",
  ]
}

resource "tailscale_dns_preferences" "preferences" {
  magic_dns = true
}
