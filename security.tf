resource "aws_security_group" "k8s_master_sg" {
  vpc_id = aws_vpc.main.id

  # SSH (for debugging)
  ingress {
    from_port   = 22
    to_port     = 22
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  # DNS
  ingress {
    from_port   = 53
    to_port     = 53
    protocol    = "udp"
    cidr_blocks = [aws_vpc.main.cidr_block]
  }

  # BGP (for kube-router)
  ingress {
    from_port   = 179
    to_port     = 179
    protocol    = "tcp"
    cidr_blocks = [aws_vpc.main.cidr_block]
  }

  # kube-router health checks
  ingress {
    from_port   = 20244
    to_port     = 20244
    protocol    = "tcp"
    cidr_blocks = [aws_vpc.main.cidr_block]
  }

  # IPIP (for pod networking)
  ingress {
    from_port   = -1
    to_port     = -1
    protocol    = "4"
    cidr_blocks = [aws_vpc.main.cidr_block]
  }

  # API Server
  ingress {
    from_port   = 6443
    to_port     = 6443
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  # EFS
  ingress {
    from_port   = 2049
    to_port     = 2049
    protocol    = "tcp"
    cidr_blocks = [aws_vpc.main.cidr_block]
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = {
    Name = "${var.name}-master-sg"
  }
}

resource "aws_security_group" "k8s_worker_sg" {
  vpc_id = aws_vpc.main.id

  # SSH (for debugging)
  ingress {
    from_port   = 22
    to_port     = 22
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }
  # DNS
  ingress {
    from_port   = 53
    to_port     = 53
    protocol    = "udp"
    cidr_blocks = [aws_vpc.main.cidr_block]
  }

  # BGP (for kube-router)
  ingress {
    from_port   = 179
    to_port     = 179
    protocol    = "tcp"
    cidr_blocks = [aws_vpc.main.cidr_block]
  }

  # kube-router health checks
  ingress {
    from_port   = 20244
    to_port     = 20244
    protocol    = "tcp"
    cidr_blocks = [aws_vpc.main.cidr_block]
  }

  # IPIP (for pod networking)
  ingress {
    from_port   = -1
    to_port     = -1
    protocol    = "4"
    cidr_blocks = [aws_vpc.main.cidr_block]
  }

  # Kubelet
  ingress {
    from_port   = 10250
    to_port     = 10250
    protocol    = "tcp"
    cidr_blocks = [aws_vpc.main.cidr_block]
  }

  # NodePort Services
  ingress {
    from_port   = 30000
    to_port     = 32767
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  # EFS
  ingress {
    from_port   = 2049
    to_port     = 2049
    protocol    = "tcp"
    cidr_blocks = [aws_vpc.main.cidr_block]
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = {
    Name = "${var.name}-worker-sg"
  }
}
