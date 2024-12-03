resource "aws_autoscaling_group" "k8s_worker_asg" {
  name = "${var.name}-worker-asg"
  launch_template {
    id      = aws_launch_template.k8s_worker_lc.id
    version = "$Latest"
  }

  target_group_arns = [
    aws_lb_target_group.k8s_ingress_http.arn,
    aws_lb_target_group.k8s_ingress_https.arn
  ]

  min_size            = 2
  max_size            = 5
  desired_capacity    = 2
  vpc_zone_identifier = aws_subnet.public[*].id

  tag {
    key                 = "Name"
    value               = "${var.name}-worker-node"
    propagate_at_launch = true
  }
  tag {
    key                 = "k8s.io/cluster-autoscaler/enabled"
    value               = "true"
    propagate_at_launch = true
  }
  tag {
    key                 = "k8s.io/cluster-autoscaler/${var.name}"
    value               = "owned"
    propagate_at_launch = true
  }
  tag {
    key                 = "kubernetes.io/cluster/${var.name}"
    value               = "owned"
    propagate_at_launch = true
  }
  tag {
    key                 = "k8s.io/cluster-autoscaler/${var.name}/Role"
    value               = "worker"
    propagate_at_launch = true
  }
}

resource "aws_launch_template" "k8s_worker_lc" {
  name          = "${var.name}-worker-lc"
  image_id      = data.aws_ami.debian.id
  instance_type = var.nodes.instance_type

  key_name = var.nodes.key_name

  network_interfaces {
    associate_public_ip_address = true
    security_groups             = [aws_security_group.k8s_worker_sg.id]
  }

  lifecycle {
    create_before_destroy = true
  }

  user_data = base64encode(templatefile("${path.module}/k8s_worker_user_data.sh", {
    kubernetes_version         = "1.31.0"
    kubernetes_install_version = "1.31.0-1.1"
    containerd_version         = "1.7"
    s3_bucket_name             = aws_s3_bucket.k8s_config.id
  }))

  iam_instance_profile {
    name = aws_iam_instance_profile.k8s_node_profile.name
  }
}
