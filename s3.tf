resource "aws_s3_bucket" "k8s_config" {
  bucket = "${var.name}-k8s-config-${random_string.long.result}"

  tags = {
    Name = "${var.name}-k8s-config"
  }
}

resource "aws_s3_bucket_server_side_encryption_configuration" "k8s_config" {
  bucket = aws_s3_bucket.k8s_config.id

  rule {
    apply_server_side_encryption_by_default {
      sse_algorithm = "AES256"
    }
  }
}

resource "aws_s3_bucket_public_access_block" "k8s_config" {
  bucket = aws_s3_bucket.k8s_config.id

  block_public_acls       = true
  block_public_policy     = true
  ignore_public_acls      = true
  restrict_public_buckets = true
}
