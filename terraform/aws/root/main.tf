terraform {
  backend "remote" {
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


variable "aws_accountid" {
  type = string
}
variable "mail_alert" {
  type = string
}
