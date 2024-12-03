resource "aws_lb" "k8s_master_lb" {
  name               = "${var.name}-master-lb-${random_string.short.result}"
  internal           = false
  load_balancer_type = "network"
  subnets            = aws_subnet.public[*].id

  enable_deletion_protection = false

  tags = {
    Name = "${var.name}-master-lb"
  }
}

resource "aws_lb_target_group" "k8s_master_tg" {
  name        = "${var.name}-master-tg-${random_string.short.result}"
  port        = 6443
  protocol    = "TCP"
  vpc_id      = aws_vpc.main.id
  target_type = "instance"
}

resource "aws_lb_listener" "k8s_master" {
  load_balancer_arn = aws_lb.k8s_master_lb.arn
  port              = "6443"
  protocol          = "TCP"

  default_action {
    type             = "forward"
    target_group_arn = aws_lb_target_group.k8s_master_tg.arn
  }
}
