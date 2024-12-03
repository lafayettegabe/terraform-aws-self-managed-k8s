terraform {

  backend "s3" {
    bucket = "backend-tf-0"
    key    = "k8s/example/terraform.tfstate"
    region = "us-east-1"
  }

  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 5.0"
    }
    random = {
      source = "hashicorp/random"
    }
  }
}

provider "aws" {
  region = local.region
}
