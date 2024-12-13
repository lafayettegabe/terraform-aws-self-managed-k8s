module "k8s_cluster" {
  source = "../.."

  name = local.project

  computing = {
    masters = {
      min_size         = 3
      max_size         = 5
      desired_capacity = 3
    }
    workers = {
      min_size         = 3
      max_size         = 5
      desired_capacity = 3
    }

  }

  networking = {
    cidr           = local.vpc_cidr
    azs            = local.azs
    public_subnets = local.public_subnets
  }

  nodes = {
    instance_type = local.instance_type
    key_name      = aws_key_pair.example.key_name
  }

  dns = {
    domain_name            = local.domain_name
    controlplane_subdomain = local.controlplane_subdomain
    ingress_subdomain      = local.ingress_subdomain
  }

  tags = local.common_tags
}
