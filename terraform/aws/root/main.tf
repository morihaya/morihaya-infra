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
}
