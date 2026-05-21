# Lấy danh sách AZ khả dụng
data "aws_availability_zones" "available" {
  state = "available"
}

# 1. Tạo VPC Security & Management
resource "aws_vpc" "main" {
  cidr_block           = var.vpc_cidr
  enable_dns_hostnames = true
  enable_dns_support   = true

  tags = { Name = "${var.project_name}-VPC-Mgmt" }
}

# 2. Internet Gateway (Bastion cần SSH inbound từ admin Internet)
resource "aws_internet_gateway" "igw" {
  vpc_id = aws_vpc.main.id
  tags   = { Name = "${var.project_name}-Mgmt-IGW" }
}

# 3. Tạo 2 Public Subnets cho Bastion (2 AZ)
#    10.3.1.0/24, 10.3.2.0/24
resource "aws_subnet" "public" {
  count                   = 2
  vpc_id                  = aws_vpc.main.id
  cidr_block              = cidrsubnet(var.vpc_cidr, 8, count.index + 1)
  availability_zone       = data.aws_availability_zones.available.names[count.index]
  map_public_ip_on_launch = true

  tags = { Name = "Mgmt-Public-${count.index + 1}" }
}

# 4. Route Table — public → IGW
resource "aws_route_table" "public" {
  vpc_id = aws_vpc.main.id

  route {
    cidr_block = "0.0.0.0/0"
    gateway_id = aws_internet_gateway.igw.id
  }

  tags = { Name = "Mgmt-Public-RT" }
}

# 5. Associate Route Table cho 2 Public Subnets
resource "aws_route_table_association" "public" {
  count          = 2
  subnet_id      = aws_subnet.public[count.index].id
  route_table_id = aws_route_table.public.id
}
