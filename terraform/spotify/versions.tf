terraform {
  required_version = ">= 1.5.0"

  required_providers {
    spotify = {
      source  = "conradludgate/spotify"
      version = "~> 0.2.6"
    }
  }
}
