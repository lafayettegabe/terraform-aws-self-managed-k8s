resource "aws_lb" "k8s_ingress" {
  name               = "${var.name}-ingress"
  internal           = false
  load_balancer_type = "network"
  subnets            = aws_subnet.public[*].id

  enable_cross_zone_load_balancing = true
}

resource "aws_lb_listener" "http" {
  load_balancer_arn = aws_lb.k8s_ingress.arn
  port              = "80"
  protocol          = "TCP"

  default_action {
    type             = "forward"
    target_group_arn = aws_lb_target_group.k8s_ingress_http.arn
  }
}

resource "aws_lb_listener" "https" {
  load_balancer_arn = aws_lb.k8s_ingress.arn
  port              = "443"
  protocol          = "TCP"

  default_action {
    type             = "forward"
    target_group_arn = aws_lb_target_group.k8s_ingress_https.arn
  }
}

resource "aws_lb_target_group" "k8s_ingress_http" {
  name     = "${var.name}-ingress-http"
  port     = 30080
  protocol = "TCP"
  vpc_id   = aws_vpc.main.id

  health_check {
    protocol = "TCP"
    port     = 30080
    interval = 30
  }
}

resource "aws_lb_target_group" "k8s_ingress_https" {
  name     = "${var.name}-ingress-https"
  port     = 30443
  protocol = "TCP"
  vpc_id   = aws_vpc.main.id

  health_check {
    protocol = "TCP"
    port     = 30443
    interval = 30
  }
}
