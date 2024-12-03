resource "random_string" "short" {
  length  = 4
  special = false
  upper   = false
}

resource "random_string" "long" {
  length  = 8
  special = false
  upper   = false
}
