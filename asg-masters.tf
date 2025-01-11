resource "aws_instance" "k8s_master" {
  ami                         = var.ami_architecture == "arm" ? data.aws_ami.debian_arm.id : data.aws_ami.debian_x86.id
  instance_type               = var.computing.workers.instance_type
  key_name                    = var.computing.key_name
  subnet_id                   = aws_subnet.public[0].id
  associate_public_ip_address = true
  security_groups             = [aws_security_group.k8s_master_sg.id]
  iam_instance_profile        = aws_iam_instance_profile.k8s_node_profile.name

  lifecycle {
    prevent_destroy = true
  }

  user_data = base64encode(templatefile("${path.module}/k8s_master_user_data.sh", {
    ami_architecture           = var.ami_architecture
    kubernetes_version         = var.versions.kubernetes_version
    kubernetes_install_version = var.versions.kubernetes_install_version
    containerd_version         = var.versions.containerd_version
    cluster_name               = var.name
    api_dns                    = "${var.dns.controlplane_subdomain}.${var.dns.domain_name}"
    pod_cidr                   = "192.168.0.0/16"
    s3_bucket_name             = aws_s3_bucket.k8s_config.id
  }))

  root_block_device {
    volume_size           = 10
    volume_type           = "gp3"
    delete_on_termination = true
  }

  tags = {
    Name                                = "${var.name}-master-node"
    "kubernetes.io/cluster/${var.name}" = "owned"
  }
}
