resource "random_string" "long" {
  length  = 8
  special = false
  upper   = false
}

resource "aws_key_pair" "example" {
  key_name   = "${local.project}-key-${random_string.long.result}"
  public_key = file("${path.module}/key.pem.pub")
}
