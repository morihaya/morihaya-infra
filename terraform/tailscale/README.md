# Terraform Tailscale

My personal [Tailscale](https://tailscale.com/)

Using:
- acl
- dns

Terraform state is in app.terraform.io.

## Provider migration (davidsbond/tailscale → tailscale/tailscale)

The configuration now uses the official `tailscale/tailscale` provider.
Existing state still references the deprecated `davidsbond/tailscale`
provider, so run the following once before the next plan/apply:

```sh
terraform init -upgrade
terraform state replace-provider \
  registry.terraform.io/davidsbond/tailscale \
  registry.terraform.io/tailscale/tailscale
```

After that, `terraform plan` should show no changes.
