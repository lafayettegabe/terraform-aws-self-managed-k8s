resource "aws_efs_file_system" "k8s_efs" {
  creation_token   = "k8s-cluster-efs"
  performance_mode = "generalPurpose"
  throughput_mode  = "bursting"

  tags = {
    Name = "k8s-cluster-efs"
  }
}

resource "aws_efs_mount_target" "k8s_efs_mount_target" {
  count          = length(aws_subnet.public)
  file_system_id = aws_efs_file_system.k8s_efs.id
  subnet_id      = aws_subnet.public[count.index].id

  security_groups = [aws_security_group.k8s_worker_sg.id]
}
