# =============================================================================
# Security Groups — VietMove
# Tham chiếu: docs/security_rules_matrix.md
# =============================================================================
#
# Lưu ý:
# - SG là stateful → chỉ cần khai báo 1 chiều, return traffic tự allow.
# - Cross-VPC traffic (qua TGW) KHÔNG tham chiếu SG được, phải dùng CIDR.
# =============================================================================


# -----------------------------------------------------------------------------
# 1. sg-alb (VPC Core) — Application Load Balancer public
# -----------------------------------------------------------------------------
resource "aws_security_group" "alb" {
  name        = "${var.project_name}-sg-alb"
  description = "ALB public, accept HTTP and HTTPS from Internet"
  vpc_id      = var.vpc_core_id

  tags = { Name = "${var.project_name}-sg-alb" }
}

resource "aws_vpc_security_group_ingress_rule" "alb_http" {
  security_group_id = aws_security_group.alb.id
  cidr_ipv4         = "0.0.0.0/0"
  from_port         = 80
  to_port           = 80
  ip_protocol       = "tcp"
  description       = "HTTP from Internet"
}

resource "aws_vpc_security_group_ingress_rule" "alb_https" {
  security_group_id = aws_security_group.alb.id
  cidr_ipv4         = "0.0.0.0/0"
  from_port         = 443
  to_port           = 443
  ip_protocol       = "tcp"
  description       = "HTTPS from Internet"
}

resource "aws_vpc_security_group_egress_rule" "alb_to_fargate" {
  security_group_id            = aws_security_group.alb.id
  referenced_security_group_id = aws_security_group.fargate.id
  from_port                    = 80
  to_port                      = 80
  ip_protocol                  = "tcp"
  description                  = "ALB to Fargate task"
}


# -----------------------------------------------------------------------------
# 2. sg-fargate (VPC Core) — Fargate task TMS
# -----------------------------------------------------------------------------
resource "aws_security_group" "fargate" {
  name        = "${var.project_name}-sg-fargate"
  description = "Fargate TMS, accept traffic from ALB only"
  vpc_id      = var.vpc_core_id

  tags = { Name = "${var.project_name}-sg-fargate" }
}

resource "aws_vpc_security_group_ingress_rule" "fargate_from_alb" {
  security_group_id            = aws_security_group.fargate.id
  referenced_security_group_id = aws_security_group.alb.id
  from_port                    = 80
  to_port                      = 80
  ip_protocol                  = "tcp"
  description                  = "From ALB"
}

resource "aws_vpc_security_group_egress_rule" "fargate_to_aurora" {
  for_each          = toset(var.vpc_data_private_cidrs)
  security_group_id = aws_security_group.fargate.id
  cidr_ipv4         = each.value
  from_port         = 5432
  to_port           = 5432
  ip_protocol       = "tcp"
  description       = "Fargate to Aurora (cross-VPC via TGW)"
}

resource "aws_vpc_security_group_egress_rule" "fargate_to_redis" {
  for_each          = toset(var.vpc_data_private_cidrs)
  security_group_id = aws_security_group.fargate.id
  cidr_ipv4         = each.value
  from_port         = 6379
  to_port           = 6379
  ip_protocol       = "tcp"
  description       = "Fargate to Redis (cross-VPC via TGW)"
}

resource "aws_vpc_security_group_egress_rule" "fargate_to_internet_https" {
  security_group_id = aws_security_group.fargate.id
  cidr_ipv4         = "0.0.0.0/0"
  from_port         = 443
  to_port           = 443
  ip_protocol       = "tcp"
  description       = "Pull ECR image, call AWS API"
}


# -----------------------------------------------------------------------------
# 3. sg-lambda (VPC Core) — Lambda ENI in private subnet
# -----------------------------------------------------------------------------
resource "aws_security_group" "lambda" {
  name        = "${var.project_name}-sg-lambda"
  description = "Lambda ENI, egress only"
  vpc_id      = var.vpc_core_id

  tags = { Name = "${var.project_name}-sg-lambda" }
}

resource "aws_vpc_security_group_egress_rule" "lambda_to_aurora" {
  for_each          = toset(var.vpc_data_private_cidrs)
  security_group_id = aws_security_group.lambda.id
  cidr_ipv4         = each.value
  from_port         = 5432
  to_port           = 5432
  ip_protocol       = "tcp"
  description       = "Lambda to Aurora"
}

resource "aws_vpc_security_group_egress_rule" "lambda_to_internet_https" {
  security_group_id = aws_security_group.lambda.id
  cidr_ipv4         = "0.0.0.0/0"
  from_port         = 443
  to_port           = 443
  ip_protocol       = "tcp"
  description       = "AWS API + SQS"
}


# -----------------------------------------------------------------------------
# 4. sg-vpn (VPC Core) — Client VPN endpoint ENI
# -----------------------------------------------------------------------------
resource "aws_security_group" "vpn" {
  name        = "${var.project_name}-sg-vpn"
  description = "Client VPN endpoint ENI"
  vpc_id      = var.vpc_core_id

  tags = { Name = "${var.project_name}-sg-vpn" }
}

resource "aws_vpc_security_group_ingress_rule" "vpn_udp" {
  security_group_id = aws_security_group.vpn.id
  cidr_ipv4         = "0.0.0.0/0"
  from_port         = 443
  to_port           = 443
  ip_protocol       = "udp"
  description       = "Client VPN connect"
}

resource "aws_vpc_security_group_egress_rule" "vpn_forward" {
  security_group_id = aws_security_group.vpn.id
  cidr_ipv4         = "10.0.0.0/8"
  ip_protocol       = "-1"
  description       = "Forward client traffic to internal VPCs"
}


# -----------------------------------------------------------------------------
# 5. sg-vpc-endpoint-core (VPC Core) — Interface VPC Endpoints
# -----------------------------------------------------------------------------
resource "aws_security_group" "vpc_endpoint_core" {
  name        = "${var.project_name}-sg-vpce-core"
  description = "Interface VPC Endpoints in VPC Core"
  vpc_id      = var.vpc_core_id

  tags = { Name = "${var.project_name}-sg-vpce-core" }
}

resource "aws_vpc_security_group_ingress_rule" "vpce_core_https" {
  security_group_id = aws_security_group.vpc_endpoint_core.id
  cidr_ipv4         = var.vpc_core_cidr
  from_port         = 443
  to_port           = 443
  ip_protocol       = "tcp"
  description       = "HTTPS from VPC Core"
}


# -----------------------------------------------------------------------------
# 6. sg-aurora (VPC Data) — Aurora cluster
# -----------------------------------------------------------------------------
resource "aws_security_group" "aurora" {
  name        = "${var.project_name}-sg-aurora"
  description = "Aurora cluster, accept PostgreSQL from Fargate, Lambda, Bastion"
  vpc_id      = var.vpc_data_id

  tags = { Name = "${var.project_name}-sg-aurora" }
}

resource "aws_vpc_security_group_ingress_rule" "aurora_from_core" {
  for_each          = toset(var.vpc_core_private_cidrs)
  security_group_id = aws_security_group.aurora.id
  cidr_ipv4         = each.value
  from_port         = 5432
  to_port           = 5432
  ip_protocol       = "tcp"
  description       = "From VPC Core private (Fargate + Lambda)"
}

resource "aws_vpc_security_group_ingress_rule" "aurora_from_bastion" {
  for_each          = toset(var.vpc_mgmt_public_cidrs)
  security_group_id = aws_security_group.aurora.id
  cidr_ipv4         = each.value
  from_port         = 5432
  to_port           = 5432
  ip_protocol       = "tcp"
  description       = "From Bastion (admin)"
}


# -----------------------------------------------------------------------------
# 7. sg-redis (VPC Data) — ElastiCache cluster
# -----------------------------------------------------------------------------
resource "aws_security_group" "redis" {
  name        = "${var.project_name}-sg-redis"
  description = "ElastiCache Redis, accept from Fargate and Lambda"
  vpc_id      = var.vpc_data_id

  tags = { Name = "${var.project_name}-sg-redis" }
}

resource "aws_vpc_security_group_ingress_rule" "redis_from_core" {
  for_each          = toset(var.vpc_core_private_cidrs)
  security_group_id = aws_security_group.redis.id
  cidr_ipv4         = each.value
  from_port         = 6379
  to_port           = 6379
  ip_protocol       = "tcp"
  description       = "From VPC Core private"
}

resource "aws_vpc_security_group_ingress_rule" "redis_from_bastion" {
  for_each          = toset(var.vpc_mgmt_public_cidrs)
  security_group_id = aws_security_group.redis.id
  cidr_ipv4         = each.value
  from_port         = 6379
  to_port           = 6379
  ip_protocol       = "tcp"
  description       = "From Bastion (admin)"
}


# -----------------------------------------------------------------------------
# 8. sg-vpc-endpoint-data (VPC Data)
# -----------------------------------------------------------------------------
resource "aws_security_group" "vpc_endpoint_data" {
  name        = "${var.project_name}-sg-vpce-data"
  description = "Interface VPC Endpoints in VPC Data"
  vpc_id      = var.vpc_data_id

  tags = { Name = "${var.project_name}-sg-vpce-data" }
}

resource "aws_vpc_security_group_ingress_rule" "vpce_data_https" {
  security_group_id = aws_security_group.vpc_endpoint_data.id
  cidr_ipv4         = var.vpc_data_cidr
  from_port         = 443
  to_port           = 443
  ip_protocol       = "tcp"
  description       = "HTTPS from VPC Data"
}


# -----------------------------------------------------------------------------
# 9. sg-bastion (VPC Mgmt) — Bastion EC2 jump host
# -----------------------------------------------------------------------------
resource "aws_security_group" "bastion" {
  name        = "${var.project_name}-sg-bastion"
  description = "Bastion host, SSH from admin whitelist only"
  vpc_id      = var.vpc_mgmt_id

  tags = { Name = "${var.project_name}-sg-bastion" }
}

resource "aws_vpc_security_group_ingress_rule" "bastion_ssh" {
  for_each          = toset(var.admin_ssh_cidrs)
  security_group_id = aws_security_group.bastion.id
  cidr_ipv4         = each.value
  from_port         = 22
  to_port           = 22
  ip_protocol       = "tcp"
  description       = "SSH from admin"
}

resource "aws_vpc_security_group_egress_rule" "bastion_to_core" {
  security_group_id = aws_security_group.bastion.id
  cidr_ipv4         = var.vpc_core_cidr
  from_port         = 22
  to_port           = 22
  ip_protocol       = "tcp"
  description       = "SSH jump to VPC Core"
}

resource "aws_vpc_security_group_egress_rule" "bastion_to_data_ssh" {
  security_group_id = aws_security_group.bastion.id
  cidr_ipv4         = var.vpc_data_cidr
  from_port         = 22
  to_port           = 22
  ip_protocol       = "tcp"
  description       = "SSH jump to VPC Data"
}

resource "aws_vpc_security_group_egress_rule" "bastion_to_aurora" {
  security_group_id = aws_security_group.bastion.id
  cidr_ipv4         = var.vpc_data_cidr
  from_port         = 5432
  to_port           = 5432
  ip_protocol       = "tcp"
  description       = "Admin to Aurora"
}

resource "aws_vpc_security_group_egress_rule" "bastion_to_redis" {
  security_group_id = aws_security_group.bastion.id
  cidr_ipv4         = var.vpc_data_cidr
  from_port         = 6379
  to_port           = 6379
  ip_protocol       = "tcp"
  description       = "Admin to Redis"
}

resource "aws_vpc_security_group_egress_rule" "bastion_to_internet_https" {
  security_group_id = aws_security_group.bastion.id
  cidr_ipv4         = "0.0.0.0/0"
  from_port         = 443
  to_port           = 443
  ip_protocol       = "tcp"
  description       = "yum update, AWS API"
}

# Phase 5B - DR replica access (port 5432 to VPC Data DR via TGW peering).
resource "aws_vpc_security_group_egress_rule" "bastion_to_dr_data" {
  security_group_id = aws_security_group.bastion.id
  cidr_ipv4         = "10.12.0.0/16"
  from_port         = 5432
  to_port           = 5432
  ip_protocol       = "tcp"
  description       = "Bastion to RDS DR (cross-region via TGW peering)"
}


# -----------------------------------------------------------------------------
# 10. sg-vpc-endpoint-mgmt (VPC Mgmt)
# -----------------------------------------------------------------------------
resource "aws_security_group" "vpc_endpoint_mgmt" {
  name        = "${var.project_name}-sg-vpce-mgmt"
  description = "Interface VPC Endpoints in VPC Mgmt (SSM)"
  vpc_id      = var.vpc_mgmt_id

  tags = { Name = "${var.project_name}-sg-vpce-mgmt" }
}

resource "aws_vpc_security_group_ingress_rule" "vpce_mgmt_https" {
  security_group_id = aws_security_group.vpc_endpoint_mgmt.id
  cidr_ipv4         = var.vpc_mgmt_cidr
  from_port         = 443
  to_port           = 443
  ip_protocol       = "tcp"
  description       = "HTTPS from VPC Mgmt"
}
