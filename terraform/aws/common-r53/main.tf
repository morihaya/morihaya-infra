terraform {
  cloud {
    organization = "morihaya"

    workspaces {
      name = "morihaya-infra-aws-common-r53"
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
