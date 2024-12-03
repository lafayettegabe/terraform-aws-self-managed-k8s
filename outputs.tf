output "k8s_api_server_endpoint" {
  value       = aws_lb.k8s_master_lb.dns_name
  description = "DNS name of the load balancer for the Kubernetes API server"
}

output "api_endpoint" {
  value       = "${var.dns.controlplane_subdomain}.${var.dns.domain_name}"
  description = "Full domain name for the Kubernetes API endpoint"
}

output "ingress_dns" {
  value = aws_lb.k8s_ingress.dns_name
}
