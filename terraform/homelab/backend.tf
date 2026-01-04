terraform {
  cloud {
    organization = "morihaya"
    workspaces {
      name = "morihaya-infra-homelab"
    }
  }
}
