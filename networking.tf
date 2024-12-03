resource "aws_vpc" "main" {
  cidr_block           = var.networking.cidr
  enable_dns_hostnames = true
  enable_dns_support   = true

  tags = merge(
    var.tags,
    {
      Name = "${var.name}-${random_string.long.result}"
    }
  )
}

resource "aws_subnet" "public" {
  count             = length(var.networking.public_subnets)
  vpc_id            = aws_vpc.main.id
  cidr_block        = var.networking.public_subnets[count.index]
  availability_zone = var.networking.azs[count.index]

  map_public_ip_on_launch = true

  tags = merge(
    var.tags,
    {
      Name = "${var.name}-public-${var.networking.azs[count.index]}-${random_string.long.result}"
    }
  )
}

resource "aws_internet_gateway" "main" {
  vpc_id = aws_vpc.main.id

  tags = merge(
    var.tags,
    {
      Name = "${var.name}-igw-${random_string.long.result}"
    }
  )
}

resource "aws_route_table" "public" {
  vpc_id = aws_vpc.main.id

  route {
    cidr_block = "0.0.0.0/0"
    gateway_id = aws_internet_gateway.main.id
  }

  tags = merge(
    var.tags,
    {
      Name = "${var.name}-public-${random_string.long.result}"
    }
  )
}

resource "aws_route_table_association" "public" {
  count          = length(var.networking.public_subnets)
  subnet_id      = aws_subnet.public[count.index].id
  route_table_id = aws_route_table.public.id
}
