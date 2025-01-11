resource "aws_autoscaling_group" "k8s_worker_asg" {
  name = "${var.name}-worker-asg"

  launch_template {
    id      = aws_launch_template.k8s_worker_lc.id
    version = "$Latest"
  }

  min_size         = var.computing.workers.min_size
  max_size         = var.computing.workers.max_size
  desired_capacity = var.computing.workers.desired_capacity

  vpc_zone_identifier = aws_subnet.public[*].id
  target_group_arns = [
    aws_lb_target_group.k8s_ingress_http.arn,
    aws_lb_target_group.k8s_ingress_https.arn
  ]

  tag {
    key                 = "Name"
    value               = "${var.name}-worker-node"
    propagate_at_launch = true
  }

  tag {
    key                 = "kubernetes.io/cluster/${var.name}"
    value               = "owned"
    propagate_at_launch = true
  }
}

resource "aws_launch_template" "k8s_worker_lc" {
  name          = "${var.name}-worker-lc"
  image_id      = var.ami_architecture == "arm" ? data.aws_ami.debian_arm.id : data.aws_ami.debian_x86.id
  instance_type = var.computing.workers.instance_type

  key_name = var.computing.key_name

  network_interfaces {
    associate_public_ip_address = true
    security_groups             = [aws_security_group.k8s_worker_sg.id]
  }

  user_data = base64encode(templatefile("${path.module}/k8s_worker_user_data.sh", {
    ami_architecture           = var.ami_architecture
    kubernetes_version         = var.versions.kubernetes_version
    kubernetes_install_version = var.versions.kubernetes_install_version
    containerd_version         = var.versions.containerd_version
    s3_bucket_name             = aws_s3_bucket.k8s_config.id
  }))

  iam_instance_profile {
    name = aws_iam_instance_profile.k8s_node_profile.name
  }
}
