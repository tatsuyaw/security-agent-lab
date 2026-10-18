resource "aws_vpc" "lab" {
  cidr_block           = var.vpc_cidr
  enable_dns_support   = true
  enable_dns_hostnames = true

  tags = { Name = "${var.name}-vpc" }
}

resource "aws_internet_gateway" "lab" {
  vpc_id = aws_vpc.lab.id

  tags = { Name = "${var.name}-igw" }
}

# ALB 用パブリックサブネット(2 AZ)
resource "aws_subnet" "public" {
  for_each = local.public_subnets

  vpc_id                  = aws_vpc.lab.id
  cidr_block              = each.value.cidr
  availability_zone       = each.value.az
  map_public_ip_on_launch = false

  tags = { Name = "${var.name}-${each.key}" }
}

resource "aws_route_table" "public" {
  vpc_id = aws_vpc.lab.id

  tags = { Name = "${var.name}-public" }
}

resource "aws_route" "public_default" {
  route_table_id         = aws_route_table.public.id
  destination_cidr_block = "0.0.0.0/0"
  gateway_id             = aws_internet_gateway.lab.id
}

resource "aws_route_table_association" "public" {
  for_each = aws_subnet.public

  subnet_id      = each.value.id
  route_table_id = aws_route_table.public.id
}

# 対象アプリ用プライベートサブネット。インターネットへの経路は持たない(NAT なし)。
# 外部とのやり取りは ALB 経由の受信と、VPC エンドポイント経由の S3 / SSM だけ。
resource "aws_subnet" "app" {
  vpc_id                  = aws_vpc.lab.id
  cidr_block              = local.app_subnet.cidr
  availability_zone       = local.app_subnet.az
  map_public_ip_on_launch = false

  tags = { Name = "${var.name}-app" }
}

resource "aws_route_table" "private" {
  vpc_id = aws_vpc.lab.id

  tags = { Name = "${var.name}-private" }
}

resource "aws_route_table_association" "app" {
  subnet_id      = aws_subnet.app.id
  route_table_id = aws_route_table.private.id
}

module "endpoints" {
  source = "../../modules/vpc-endpoints"

  name            = var.name
  vpc_id          = aws_vpc.lab.id
  vpc_cidr        = var.vpc_cidr
  region          = var.region
  route_table_ids = [aws_route_table.private.id]
  subnet_ids      = [aws_subnet.app.id]
}
