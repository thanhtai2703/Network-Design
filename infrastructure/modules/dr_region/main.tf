# =============================================================================
# DR Region (Phase 5A) - network base in a 2nd AWS region
# =============================================================================
# Creates in DR region:
#   - VPC Core DR (2 AZ): 1 public + 1 private subnet per AZ, IGW, 1 NAT GW (shared, cost-saving)
#   - VPC Data DR (2 AZ): private subnet, DB subnet group (for 5B read replica)
#   - Transit Gateway DR with attachments
#   - Inter-region TGW peering: DR (requester) -> Primary (accepter)
#   - Routes: DR private subnets -> 10.0.0.0/8 -> TGW DR -> peering -> Primary TGW
#
# Cost-saving simplifications vs primary region:
#   - 2 AZ instead of 3
#   - 1 NAT GW (shared between AZ) instead of 1-per-AZ
#   - No VPC Mgmt DR (admin via primary Bastion + peering is enough for demo)
# =============================================================================

terraform {
  required_providers {
    aws = {
      source                = "hashicorp/aws"
      configuration_aliases = [aws.dr]
    }
  }
}

data "aws_availability_zones" "dr" {
  provider = aws.dr
  state    = "available"
}


# -----------------------------------------------------------------------------
# 1. VPC Core DR (2 AZ)
# -----------------------------------------------------------------------------
resource "aws_vpc" "core_dr" {
  provider             = aws.dr
  cidr_block           = var.vpc_core_dr_cidr
  enable_dns_hostnames = true
  enable_dns_support   = true
  tags                 = { Name = "${var.project_name}-VPC-Core-DR" }
}

resource "aws_internet_gateway" "core_dr" {
  provider = aws.dr
  vpc_id   = aws_vpc.core_dr.id
  tags     = { Name = "${var.project_name}-IGW-DR" }
}

resource "aws_subnet" "core_dr_public" {
  provider                = aws.dr
  count                   = 2
  vpc_id                  = aws_vpc.core_dr.id
  cidr_block              = cidrsubnet(var.vpc_core_dr_cidr, 8, count.index + 1) # 10.11.1.0/24, 10.11.2.0/24
  availability_zone       = data.aws_availability_zones.dr.names[count.index]
  map_public_ip_on_launch = true

  tags = { Name = "DR-Core-Public-AZ${count.index + 1}" }
}

resource "aws_subnet" "core_dr_private" {
  provider          = aws.dr
  count             = 2
  vpc_id            = aws_vpc.core_dr.id
  cidr_block        = cidrsubnet(var.vpc_core_dr_cidr, 8, count.index + 10) # 10.11.10.0/24, 10.11.11.0/24
  availability_zone = data.aws_availability_zones.dr.names[count.index]

  tags = { Name = "DR-Core-Private-AZ${count.index + 1}" }
}

# Single NAT GW in AZ-1 (shared) - cost saving
resource "aws_eip" "core_dr_nat" {
  provider = aws.dr
  domain   = "vpc"
  tags     = { Name = "${var.project_name}-EIP-NAT-DR" }
}

resource "aws_nat_gateway" "core_dr" {
  provider      = aws.dr
  allocation_id = aws_eip.core_dr_nat.id
  subnet_id     = aws_subnet.core_dr_public[0].id
  tags          = { Name = "${var.project_name}-NAT-DR" }
  depends_on    = [aws_internet_gateway.core_dr]
}

resource "aws_route_table" "core_dr_public" {
  provider = aws.dr
  vpc_id   = aws_vpc.core_dr.id
  route {
    cidr_block = "0.0.0.0/0"
    gateway_id = aws_internet_gateway.core_dr.id
  }
  tags = { Name = "DR-Core-Public-RT" }
}

resource "aws_route_table" "core_dr_private" {
  provider = aws.dr
  vpc_id   = aws_vpc.core_dr.id
  route {
    cidr_block     = "0.0.0.0/0"
    nat_gateway_id = aws_nat_gateway.core_dr.id
  }
  tags = { Name = "DR-Core-Private-RT" }

  lifecycle {
    ignore_changes = [route] # TGW route added below
  }
}

resource "aws_route_table_association" "core_dr_public" {
  provider       = aws.dr
  count          = 2
  subnet_id      = aws_subnet.core_dr_public[count.index].id
  route_table_id = aws_route_table.core_dr_public.id
}

resource "aws_route_table_association" "core_dr_private" {
  provider       = aws.dr
  count          = 2
  subnet_id      = aws_subnet.core_dr_private[count.index].id
  route_table_id = aws_route_table.core_dr_private.id
}


# -----------------------------------------------------------------------------
# 2. VPC Data DR (2 AZ)
# -----------------------------------------------------------------------------
resource "aws_vpc" "data_dr" {
  provider             = aws.dr
  cidr_block           = var.vpc_data_dr_cidr
  enable_dns_hostnames = true
  enable_dns_support   = true
  tags                 = { Name = "${var.project_name}-VPC-Data-DR" }
}

resource "aws_subnet" "data_dr_private" {
  provider          = aws.dr
  count             = 2
  vpc_id            = aws_vpc.data_dr.id
  cidr_block        = cidrsubnet(var.vpc_data_dr_cidr, 8, count.index + 1) # 10.12.1.0/24, 10.12.2.0/24
  availability_zone = data.aws_availability_zones.dr.names[count.index]

  tags = { Name = "DR-Data-Private-AZ${count.index + 1}" }
}

resource "aws_route_table" "data_dr_private" {
  provider = aws.dr
  vpc_id   = aws_vpc.data_dr.id
  tags     = { Name = "DR-Data-Private-RT" }

  lifecycle {
    ignore_changes = [route] # TGW route added below
  }
}

resource "aws_route_table_association" "data_dr_private" {
  provider       = aws.dr
  count          = 2
  subnet_id      = aws_subnet.data_dr_private[count.index].id
  route_table_id = aws_route_table.data_dr_private.id
}

resource "aws_db_subnet_group" "data_dr" {
  provider   = aws.dr
  name       = "${lower(var.project_name)}-dr-db-subnet-group"
  subnet_ids = aws_subnet.data_dr_private[*].id

  tags = { Name = "${var.project_name}-DR-DB-Subnet-Group" }
}


# -----------------------------------------------------------------------------
# 3. Transit Gateway DR
# -----------------------------------------------------------------------------
resource "aws_ec2_transit_gateway" "dr" {
  provider                        = aws.dr
  description                     = "${var.project_name} TGW - DR region"
  default_route_table_association = "enable"
  default_route_table_propagation = "enable"
  dns_support                     = "enable"

  tags = { Name = "${var.project_name}-TGW-DR" }
}

resource "aws_ec2_transit_gateway_vpc_attachment" "core_dr" {
  provider           = aws.dr
  transit_gateway_id = aws_ec2_transit_gateway.dr.id
  vpc_id             = aws_vpc.core_dr.id
  subnet_ids         = aws_subnet.core_dr_private[*].id
  dns_support        = "enable"

  tags = { Name = "${var.project_name}-TGW-Attach-Core-DR" }
}

resource "aws_ec2_transit_gateway_vpc_attachment" "data_dr" {
  provider           = aws.dr
  transit_gateway_id = aws_ec2_transit_gateway.dr.id
  vpc_id             = aws_vpc.data_dr.id
  subnet_ids         = aws_subnet.data_dr_private[*].id
  dns_support        = "enable"

  tags = { Name = "${var.project_name}-TGW-Attach-Data-DR" }
}


# -----------------------------------------------------------------------------
# 4. Inter-Region TGW Peering
# Requester = DR side (creates the attachment)
# Accepter  = Primary side (must accept via aws_ec2_transit_gateway_peering_attachment_accepter)
# -----------------------------------------------------------------------------
resource "aws_ec2_transit_gateway_peering_attachment" "dr_to_primary" {
  provider                = aws.dr
  transit_gateway_id      = aws_ec2_transit_gateway.dr.id
  peer_transit_gateway_id = var.primary_tgw_id
  peer_region             = var.primary_aws_region

  tags = { Name = "${var.project_name}-TGW-Peering-DR-to-Primary" }
}

resource "aws_ec2_transit_gateway_peering_attachment_accepter" "primary_accept" {
  # Default provider = primary region
  transit_gateway_attachment_id = aws_ec2_transit_gateway_peering_attachment.dr_to_primary.id

  tags = { Name = "${var.project_name}-TGW-Peering-Primary-Accept" }
}


# -----------------------------------------------------------------------------
# 5. Static routes on TGW route tables - peering must use static routes
#    (peering attachments don't support route propagation)
# -----------------------------------------------------------------------------

# Primary TGW default RT: route DR CIDRs -> peering
data "aws_ec2_transit_gateway" "primary" {
  id = var.primary_tgw_id
}

resource "aws_ec2_transit_gateway_route" "primary_to_dr_core" {
  destination_cidr_block         = var.vpc_core_dr_cidr
  transit_gateway_route_table_id = data.aws_ec2_transit_gateway.primary.association_default_route_table_id
  transit_gateway_attachment_id  = aws_ec2_transit_gateway_peering_attachment_accepter.primary_accept.id

  depends_on = [aws_ec2_transit_gateway_peering_attachment_accepter.primary_accept]
}

resource "aws_ec2_transit_gateway_route" "primary_to_dr_data" {
  destination_cidr_block         = var.vpc_data_dr_cidr
  transit_gateway_route_table_id = data.aws_ec2_transit_gateway.primary.association_default_route_table_id
  transit_gateway_attachment_id  = aws_ec2_transit_gateway_peering_attachment_accepter.primary_accept.id

  depends_on = [aws_ec2_transit_gateway_peering_attachment_accepter.primary_accept]
}

# DR TGW default RT: route Primary CIDRs -> peering
# IMPORTANT: depend on the ACCEPTER (not just the requester). The DR-side
# attachment is in pendingAcceptance until primary accepts, and creating
# routes against it fails with "invalid state".
resource "aws_ec2_transit_gateway_route" "dr_to_primary_all" {
  provider                       = aws.dr
  destination_cidr_block         = "10.0.0.0/8"
  transit_gateway_route_table_id = aws_ec2_transit_gateway.dr.association_default_route_table_id
  transit_gateway_attachment_id  = aws_ec2_transit_gateway_peering_attachment.dr_to_primary.id

  depends_on = [aws_ec2_transit_gateway_peering_attachment_accepter.primary_accept]
}

# (Note: this DR-side 10/8 route would conflict with DR VPC CIDRs (10.11, 10.12)
#  on the TGW RT, but TGW RT uses longest-prefix match — DR attachment routes
#  for 10.11.0.0/16 and 10.12.0.0/16 are auto-propagated and take priority.)


# -----------------------------------------------------------------------------
# 6. VPC route tables -> TGW DR (for cross-VPC + cross-region traffic)
# -----------------------------------------------------------------------------
resource "aws_route" "core_dr_private_to_tgw" {
  provider               = aws.dr
  route_table_id         = aws_route_table.core_dr_private.id
  destination_cidr_block = "10.0.0.0/8"
  transit_gateway_id     = aws_ec2_transit_gateway.dr.id

  depends_on = [aws_ec2_transit_gateway_vpc_attachment.core_dr]
}

resource "aws_route" "data_dr_private_to_tgw" {
  provider               = aws.dr
  route_table_id         = aws_route_table.data_dr_private.id
  destination_cidr_block = "10.0.0.0/8"
  transit_gateway_id     = aws_ec2_transit_gateway.dr.id

  depends_on = [aws_ec2_transit_gateway_vpc_attachment.data_dr]
}
