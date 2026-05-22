# Lấy danh sách các AZ khả dụng trong Region
data "aws_availability_zones" "available" {
  state = "available"
}

# 1. Tạo VPC Core
resource "aws_vpc" "main" {
  cidr_block           = var.vpc_cidr
  enable_dns_hostnames = true
  enable_dns_support   = true

  tags = { Name = "${var.project_name}-VPC-Core" }
}

# 2. Tạo Internet Gateway
resource "aws_internet_gateway" "igw" {
  vpc_id = aws_vpc.main.id
  tags   = { Name = "${var.project_name}-IGW" }
}

# 3. Tạo 3 Public Subnets (Dùng cho ALB, NAT GW)
resource "aws_subnet" "public" {
  count                   = 3
  vpc_id                  = aws_vpc.main.id
  cidr_block              = cidrsubnet(var.vpc_cidr, 8, count.index + 1) # 10.1.1.0, 10.1.2.0, 10.1.3.0
  availability_zone       = data.aws_availability_zones.available.names[count.index]
  map_public_ip_on_launch = true

  tags = { Name = "Public-Subnet-AZ${count.index + 1}" }
}

# 4. Tạo 3 Private Subnets (Dùng cho Fargate)
resource "aws_subnet" "private" {
  count             = 3
  vpc_id            = aws_vpc.main.id
  cidr_block        = cidrsubnet(var.vpc_cidr, 8, count.index + 10) # 10.1.10.0, 10.1.11.0, 10.1.12.0
  availability_zone = data.aws_availability_zones.available.names[count.index]

  tags = { Name = "Private-Subnet-AZ${count.index + 1}" }
}

# 5. NAT Gateways (Để Private Subnet ra internet tải image)
resource "aws_eip" "nat" {
  count  = 3
  domain = "vpc"
  tags   = { Name = "EIP-NAT-AZ${count.index + 1}" }
}

resource "aws_nat_gateway" "nat" {
  count         = 3
  allocation_id = aws_eip.nat[count.index].id
  subnet_id     = aws_subnet.public[count.index].id
  tags          = { Name = "NAT-GW-AZ${count.index + 1}" }
  depends_on    = [aws_internet_gateway.igw]
}

# 6. Route Tables
resource "aws_route_table" "public" {
  vpc_id = aws_vpc.main.id
  route {
    cidr_block = "0.0.0.0/0"
    gateway_id = aws_internet_gateway.igw.id
  }
  tags = { Name = "Public-RT" }
}

resource "aws_route_table" "private" {
  count  = 3
  vpc_id = aws_vpc.main.id
  route {
    cidr_block     = "0.0.0.0/0"
    nat_gateway_id = aws_nat_gateway.nat[count.index].id
  }
  tags = { Name = "Private-RT-AZ${count.index + 1}" }

  # transit_gateway module adds 10.0.0.0/8 -> TGW via separate aws_route resource.
  # Without ignore_changes, this route table would try to remove that route every plan.
  lifecycle {
    ignore_changes = [route]
  }
}

# 7. Route Table Associations
resource "aws_route_table_association" "public" {
  count          = 3
  subnet_id      = aws_subnet.public[count.index].id
  route_table_id = aws_route_table.public.id
}

resource "aws_route_table_association" "private" {
  count          = 3
  subnet_id      = aws_subnet.private[count.index].id
  route_table_id = aws_route_table.private[count.index].id
}
