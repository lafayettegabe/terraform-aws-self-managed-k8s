variable "name" {
  description = "Name prefix for resources"
  type        = string
}

variable "dns" {
  description = "DNS configuration"
  type = object({
    domain_name            = string
    controlplane_subdomain = string
    ingress_subdomain      = string
  })
}

variable "nodes" {
  description = "Node configuration"
  type = object({
    instance_type = string
    key_name      = string
  })
}

variable "networking" {
  description = "VPC configuration"
  type = object({
    cidr           = string
    azs            = list(string)
    public_subnets = list(string)
  })
}

variable "tags" {
  description = "Tags to apply to all resources"
  type        = map(string)
  default     = {}
}
