# =============================================================================
# Transit Gateway - Region 1 (ap-southeast-1)
# Hub connecting VPC Core, VPC Data, VPC Mgmt
# =============================================================================
#
# Strategy: use TGW default route table with auto association + auto propagation
# All VPCs see each other automatically. Simpler than custom RTs.
# =============================================================================


# 1. Transit Gateway
resource "aws_ec2_transit_gateway" "main" {
  description                     = "${var.project_name} TGW - Region 1 hub"
  default_route_table_association = "enable"
  default_route_table_propagation = "enable"
  dns_support                     = "enable"
  vpn_ecmp_support                = "enable"

  tags = { Name = "${var.project_name}-TGW-R1" }
}


# 2. VPC Attachments - one per VPC
resource "aws_ec2_transit_gateway_vpc_attachment" "core" {
  transit_gateway_id = aws_ec2_transit_gateway.main.id
  vpc_id             = var.vpc_core_id
  subnet_ids         = var.vpc_core_attach_subnet_ids
  dns_support        = "enable"

  tags = { Name = "${var.project_name}-TGW-Attach-Core" }
}

resource "aws_ec2_transit_gateway_vpc_attachment" "data" {
  transit_gateway_id = aws_ec2_transit_gateway.main.id
  vpc_id             = var.vpc_data_id
  subnet_ids         = var.vpc_data_attach_subnet_ids
  dns_support        = "enable"

  tags = { Name = "${var.project_name}-TGW-Attach-Data" }
}

resource "aws_ec2_transit_gateway_vpc_attachment" "mgmt" {
  transit_gateway_id = aws_ec2_transit_gateway.main.id
  vpc_id             = var.vpc_mgmt_id
  subnet_ids         = var.vpc_mgmt_attach_subnet_ids
  dns_support        = "enable"

  tags = { Name = "${var.project_name}-TGW-Attach-Mgmt" }
}


# 3. VPC Route Tables - send cross-VPC traffic (10.0.0.0/8) to TGW
#    Longest-prefix match keeps intra-VPC traffic local (each VPC has its own /16 local route)

# VPC Core: 3 private route tables (one per AZ)
resource "aws_route" "core_private_to_tgw" {
  count                  = length(var.vpc_core_private_route_table_ids)
  route_table_id         = var.vpc_core_private_route_table_ids[count.index]
  destination_cidr_block = "10.0.0.0/8"
  transit_gateway_id     = aws_ec2_transit_gateway.main.id

  depends_on = [aws_ec2_transit_gateway_vpc_attachment.core]
}

# VPC Data: 1 private route table
resource "aws_route" "data_private_to_tgw" {
  route_table_id         = var.vpc_data_private_route_table_id
  destination_cidr_block = "10.0.0.0/8"
  transit_gateway_id     = aws_ec2_transit_gateway.main.id

  depends_on = [aws_ec2_transit_gateway_vpc_attachment.data]
}

# VPC Mgmt: 1 public route table (has 0.0.0.0/0 to IGW already; 10/8 is more specific)
resource "aws_route" "mgmt_public_to_tgw" {
  route_table_id         = var.vpc_mgmt_public_route_table_id
  destination_cidr_block = "10.0.0.0/8"
  transit_gateway_id     = aws_ec2_transit_gateway.main.id

  depends_on = [aws_ec2_transit_gateway_vpc_attachment.mgmt]
}
