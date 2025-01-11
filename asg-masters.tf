resource "aws_autoscaling_group" "k8s_master_asg" {
  name = "${var.name}-master-asg"

  launch_template {
    id      = aws_launch_template.k8s_master_lc.id
    version = "$Latest"
  }

  min_size         = var.computing.masters.min_size
  max_size         = var.computing.masters.max_size
  desired_capacity = var.computing.masters.desired_capacity

  vpc_zone_identifier = aws_subnet.public[*].id
  target_group_arns   = [aws_lb_target_group.k8s_master_tg.arn]

  tag {
    key                 = "Name"
    value               = "${var.name}-master-node"
    propagate_at_launch = true
  }

  tag {
    key                 = "kubernetes.io/cluster/${var.name}"
    value               = "owned"
    propagate_at_launch = true
  }
}

resource "aws_launch_template" "k8s_master_lc" {
  name          = "${var.name}-master-lc"
  image_id      = data.aws_ami.debian.id
  instance_type = var.computing.workers.instance_type

  key_name = var.computing.key_name

  network_interfaces {
    associate_public_ip_address = true
    security_groups             = [aws_security_group.k8s_master_sg.id]
  }

  lifecycle {
    create_before_destroy = true
  }

  user_data = base64encode(templatefile("${path.module}/k8s_master_user_data.sh", {
    kubernetes_version         = var.versions.kubernetes_version
    kubernetes_install_version = var.versions.kubernetes_install_version
    containerd_version         = var.versions.containerd_version
    cluster_name               = var.name
    api_dns                    = "${var.dns.controlplane_subdomain}.${var.dns.domain_name}"
    pod_cidr                   = "192.168.0.0/16"
    s3_bucket_name             = aws_s3_bucket.k8s_config.id
  }))

  iam_instance_profile {
    name = aws_iam_instance_profile.k8s_node_profile.name
  }
}
