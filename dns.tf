data "aws_route53_zone" "selected" {
  name = var.dns.domain_name
}

resource "aws_route53_record" "k8s_api" {
  zone_id = data.aws_route53_zone.selected.zone_id
  name    = "${var.dns.controlplane_subdomain}.${var.dns.domain_name}"
  type    = "A"

  alias {
    name                   = aws_lb.k8s_master_lb.dns_name
    zone_id                = aws_lb.k8s_master_lb.zone_id
    evaluate_target_health = true
  }
}

resource "aws_route53_record" "k8s_ingress" {
  zone_id = data.aws_route53_zone.selected.zone_id
  name    = var.dns.ingress_subdomain
  type    = "A"

  alias {
    name                   = aws_lb.k8s_ingress.dns_name
    zone_id                = aws_lb.k8s_ingress.zone_id
    evaluate_target_health = true
  }
}
