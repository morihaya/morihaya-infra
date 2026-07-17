terraform {
  required_version = ">= 1.5.0"

  cloud {
    organization = "morihaya"

    workspaces {
      name = "morihaya-infra-aws-common-r53"
    }
  }

  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 6.27"
    }
  }
}
