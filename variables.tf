variable "name" {
  description = "Name prefix for resources"
  type        = string
}

variable "computing" {
  description = "Master and Worker nodes"
  type = object({
    masters = object({
      instance_type = string
    })
    workers = object({
      instance_type    = string
      desired_capacity = number
      min_size         = number
      max_size         = number
    })
    key_name = string
  })
}

variable "dns" {
  description = "DNS configuration"
  type = object({
    domain_name            = string
    controlplane_subdomain = string
    ingress_subdomain      = string
  })
}

variable "networking" {
  description = "VPC configuration"
  type = object({
    cidr           = string
    azs            = list(string)
    public_subnets = list(string)
  })
  default = {
    cidr           = "10.0.0.0/16"
    azs            = ["us-east-1a", "us-east-1b", "us-east-1c"]
    public_subnets = ["10.0.1.0/24", "10.0.2.0/24", "10.0.3.0/24"]
  }
}

variable "tags" {
  description = "Tags to apply to all resources"
  type        = map(string)
  default     = {}
}

variable "versions" {
  type = object({
    kubernetes_version         = string
    kubernetes_install_version = string
    containerd_version         = string
  })
  default = {
    kubernetes_version         = "1.31.0"
    kubernetes_install_version = "1.31.0-1.1"
    containerd_version         = "1.7"
  }
}
