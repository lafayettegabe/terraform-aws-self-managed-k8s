# Self-Managed Kubernetes Module

This Terraform module makes it super easy to spin up a Kubernetes cluster on AWS.

It takes care of all the heavy lifting by provisioning the essential infrastructure components you need to run Kubernetes, such as:

- Auto Scaling Groups for master and worker nodes
- VPC, subnets, and route tables for networking
- Security groups customized for Kubernetes communication
- IAM roles and policies for smooth operations
- An S3 bucket to store cluster state and config
- Elastic Load Balancers for control plane and ingress traffic
- DNS settings for cluster endpoints

The module is flexible and customizable, so you can tweak it to match your needs while sticking to AWS best practices for security and scalability.

## What You Get

- Fully automated setup: Deploy your Kubernetes cluster with minimal effort.
- Modular structure: Use only the pieces you need or extend them as you like.
- Flexible configurations: Choose instance types, sizes, and scaling policies that fit your workload.
- Optimized security: IAM roles and security groups are pre-configured for Kubernetes best practices.
- Ready-to-use nodes: Pre-configured user data scripts for master and worker nodes, so your cluster is up and running as soon as it’s deployed.
- ~~Support for private clusters with advanced networking options~~ (TODO: Evaluate implementing private ASG with NLB or NGINX Load Balancer. While this setup can offer additional security and scalability, it is unnecessary for small to medium clusters. Public ASGs, as configured, are already effectively private due to strict access controls such as limited ports, SSH keys, and security groups, making the added complexity and cost of a fully private setup unnecessary in most cases.)


### Example usage:

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
  tags = local.common_tags

}
```
