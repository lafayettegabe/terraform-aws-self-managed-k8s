# Self-Managed Kubernetes Module

This Terraform module makes it easy to deploy a Kubernetes cluster on AWS.

It automates the creation of essential infrastructure components required for running Kubernetes, such as:

- Auto Scaling Groups (ASGs) for worker nodes
- VPC, subnets, and route tables for networking
- Security groups tailored for Kubernetes communication
- IAM roles and policies for smooth operations
- An S3 bucket for storing cluster state and configuration
- Elastic Load Balancers for control plane and ingress traffic
- DNS settings for Kubernetes cluster endpoints

The module is flexible and customizable, enabling you to adjust it to fit your needs while adhering to AWS best practices for security and scalability.

## Features

- **Fully Automated Setup**: Deploy your Kubernetes cluster with minimal effort.
- **Modular Architecture**: Use only the components you need or extend them as desired.
- **Customizable Configurations**: Choose instance types, sizes, and scaling policies that suit your workload.
- **Optimized Security**: IAM roles and security groups are pre-configured with Kubernetes best practices in mind.
- **Ready-to-Use Nodes**: Pre-configured user data scripts for master and worker nodes, allowing your cluster to be operational immediately after deployment.
- ~~**Support for Private Clusters with Advanced Networking Options**~~  
  (TODO: Evaluate implementing private ASG with NLB or NGINX Load Balancer. Although this setup may provide additional security and scalability, it is not necessary for small to medium-sized clusters. Public ASGs, as configured, already offer sufficient security due to strict access controls like limited ports, SSH keys, and security groups. Thus, the complexity and cost of a fully private setup may be unnecessary in most cases.)

## Prerequisites

- Terraform
- AWS account and credentials
- An existing SSH key pair for EC2 instances
- S3 bucket for cluster state and configuration (optional)

## Usage Example

```hcl
module "self-managed-k8s" {
  source  = "lafayettegabe/self-managed-k8s/aws"
  version = "2.0.0"

  name = "k8s-cluster"

  computing = {
    masters = {
      instance_type = "t4g.medium"
    }
    workers = {
      instance_type    = "t4g.nano"
      min_size         = 2
      max_size         = 5
      desired_capacity = 2
    }
    key_name = aws_key_pair.example.key_name
  }

  networking = {
    cidr           = "10.0.0.0/16"
    public_subnets = ["10.0.1.0/24", "10.0.2.0/24", "10.0.3.0/24"]
    azs            = ["us-east-1a", "us-east-1b", "us-east-1c"]
  }

  dns = {
    domain_name            = "example.com"
    controlplane_subdomain = "k8s"
    ingress_subdomain      = "app"
  }

  tags = {
    Project     = "k8s-cluster"
    Terraform   = "true"
    Environment = "prod"
  }
}
```
