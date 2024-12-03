locals {
  project = "k8s-cluster"

  domain_name            = "example.com"
  controlplane_subdomain = "k8s"
  ingress_subdomain      = "app"

  region = "us-east-1"

  vpc_cidr       = "10.0.0.0/16"
  azs            = ["us-east-1a", "us-east-1b", "us-east-1c"]
  public_subnets = ["10.0.1.0/24", "10.0.2.0/24", "10.0.3.0/24"]

  instance_type = "t3.medium"

  common_tags = {
    Project     = local.project
    Terraform   = "true"
    Environment = "dev"
  }
}
