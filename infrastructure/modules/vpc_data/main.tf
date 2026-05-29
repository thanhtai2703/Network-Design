# Lấy danh sách AZ khả dụng
data "aws_availability_zones" "available" {
  state = "available"
}

# 1. Tạo VPC Data Layer
resource "aws_vpc" "main" {
  cidr_block           = var.vpc_cidr
  enable_dns_hostnames = true
  enable_dns_support   = true

  tags = { Name = "${var.project_name}-VPC-Data" }
}

# 2. Tạo 3 Private Subnets cho Aurora + Redis (3 AZ)
#    10.2.1.0/24, 10.2.2.0/24, 10.2.3.0/24
resource "aws_subnet" "private" {
  count             = 3
  vpc_id            = aws_vpc.main.id
  cidr_block        = cidrsubnet(var.vpc_cidr, 8, count.index + 1)
  availability_zone = data.aws_availability_zones.available.names[count.index]

  tags = { Name = "Data-Private-${count.index + 1}" }
}

# 3. Route Table — chỉ có 1 RT cho private subnet
#    Route 0.0.0.0/0 sẽ KHÔNG có (Data Layer không cần ra Internet trực tiếp)
#    Cross-VPC traffic sẽ thêm sau khi attach Transit Gateway (Giai đoạn 3)
resource "aws_route_table" "private" {
  vpc_id = aws_vpc.main.id
  tags   = { Name = "Data-Private-RT" }
}

# 4. Associate Route Table cho 3 Private Subnets
resource "aws_route_table_association" "private" {
  count          = 3
  subnet_id      = aws_subnet.private[count.index].id
  route_table_id = aws_route_table.private.id
}

# 5. DB Subnet Group (dùng cho Aurora — task 4.1)
resource "aws_db_subnet_group" "aurora" {
  name       = "${lower(var.project_name)}-aurora-subnet-group"
  subnet_ids = aws_subnet.private[*].id

  tags = { Name = "${var.project_name}-Aurora-Subnet-Group" }
}

# ElastiCache Redis đã bị loại khỏi thiết kế (theo yêu cầu) — không tạo
# elasticache_subnet_group nữa.
