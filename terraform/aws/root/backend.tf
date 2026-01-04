terraform {
  cloud {
    organization = "morihaya"

    workspaces {
      name = "morihaya-infra-aws-root"
    }
  }
}

provider "aws" {
  region = "ap-northeast-1"
  default_tags {
    tags = {
      Terraform = "True"
      GitHub    = "morihaya/morihaya-infra"
    }
  }
}
