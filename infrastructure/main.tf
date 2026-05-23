terraform {
  required_version = ">= 1.0.0"
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = ">= 5.0"
    }
    tls = {
      source  = "hashicorp/tls"
      version = ">= 4.0"
    }
    local = {
      source  = "hashicorp/local"
      version = ">= 2.0"
    }
    archive = {
      source  = "hashicorp/archive"
      version = ">= 2.0"
    }
    random = {
      source  = "hashicorp/random"
      version = ">= 3.0"
    }
  }
}

provider "aws" {
  region = var.aws_region
}

# Required for CLOUDFRONT-scope WAF (must live in us-east-1).
provider "aws" {
  alias  = "us_east_1"
  region = "us-east-1"
}

# DR region (Phase 5).
provider "aws" {
  alias  = "dr"
  region = var.dr_aws_region
}

# =============================================================================
# VPC Core — 10.1.0.0/16 (Application Layer)
# =============================================================================
module "vpc_core" {
  source       = "./modules/vpc_core"
  vpc_cidr     = var.vpc_core_cidr
  project_name = var.project_name
}

# =============================================================================
# VPC Data Layer — 10.2.0.0/16 (Aurora + Redis)
# =============================================================================
module "vpc_data" {
  source       = "./modules/vpc_data"
  vpc_cidr     = var.vpc_data_cidr
  project_name = var.project_name
}

# =============================================================================
# VPC Security & Mgmt — 10.3.0.0/16 (Bastion)
# =============================================================================
module "vpc_mgmt" {
  source       = "./modules/vpc_mgmt"
  vpc_cidr     = var.vpc_mgmt_cidr
  project_name = var.project_name
}

# =============================================================================
# Security Groups — cross-VPC, depends on all 3 VPCs above
# =============================================================================
module "security_groups" {
  source       = "./modules/security_groups"
  project_name = var.project_name

  vpc_core_id            = module.vpc_core.vpc_id
  vpc_core_cidr          = var.vpc_core_cidr
  vpc_core_private_cidrs = module.vpc_core.private_subnet_cidrs

  vpc_data_id            = module.vpc_data.vpc_id
  vpc_data_cidr          = var.vpc_data_cidr
  vpc_data_private_cidrs = module.vpc_data.private_subnet_cidrs

  vpc_mgmt_id           = module.vpc_mgmt.vpc_id
  vpc_mgmt_cidr         = var.vpc_mgmt_cidr
  vpc_mgmt_public_cidrs = module.vpc_mgmt.public_subnet_cidrs

  admin_ssh_cidrs = var.admin_ssh_cidrs
}

# =============================================================================
# Transit Gateway - hub connecting all 3 VPCs
# =============================================================================
module "transit_gateway" {
  source       = "./modules/transit_gateway"
  project_name = var.project_name

  vpc_core_id                      = module.vpc_core.vpc_id
  vpc_core_attach_subnet_ids       = module.vpc_core.private_subnet_ids
  vpc_core_private_route_table_ids = module.vpc_core.private_route_table_ids

  vpc_data_id                     = module.vpc_data.vpc_id
  vpc_data_attach_subnet_ids      = module.vpc_data.private_subnet_ids
  vpc_data_private_route_table_id = module.vpc_data.private_route_table_id

  vpc_mgmt_id                    = module.vpc_mgmt.vpc_id
  vpc_mgmt_attach_subnet_ids     = module.vpc_mgmt.public_subnet_ids
  vpc_mgmt_public_route_table_id = module.vpc_mgmt.public_route_table_id
}

# =============================================================================
# VPC Endpoints - one module call per VPC (different service lists)
# =============================================================================

# Core: S3 (Gateway, free) + ECR API + ECR DKR + CloudWatch Logs (Interface, for Fargate)
module "vpc_endpoint_core" {
  source            = "./modules/vpc_endpoint"
  name_prefix       = "${var.project_name}-Core"
  vpc_id            = module.vpc_core.vpc_id
  route_table_ids   = module.vpc_core.private_route_table_ids
  subnet_ids        = module.vpc_core.private_subnet_ids
  security_group_id = module.security_groups.sg_vpc_endpoint_core_id

  gateway_services   = ["s3"]
  interface_services = ["ecr.api", "ecr.dkr", "logs"]
}

# Data: S3 only (Aurora and Redis don't need ECR/CloudWatch interface endpoints)
module "vpc_endpoint_data" {
  source          = "./modules/vpc_endpoint"
  name_prefix     = "${var.project_name}-Data"
  vpc_id          = module.vpc_data.vpc_id
  route_table_ids = [module.vpc_data.private_route_table_id]

  gateway_services = ["s3"]
}

# Mgmt: SSM + SSM Messages + EC2 Messages (so Bastion can use Session Manager privately)
module "vpc_endpoint_mgmt" {
  source            = "./modules/vpc_endpoint"
  name_prefix       = "${var.project_name}-Mgmt"
  vpc_id            = module.vpc_mgmt.vpc_id
  subnet_ids        = module.vpc_mgmt.public_subnet_ids
  security_group_id = module.security_groups.sg_vpc_endpoint_mgmt_id

  interface_services = ["ssm", "ssmmessages", "ec2messages"]
}

# =============================================================================
# Bastion Host - 2 EC2 in VPC Mgmt (one per AZ), accessible via SSM Session Manager
# =============================================================================
module "bastion" {
  source            = "./modules/bastion"
  project_name      = var.project_name
  subnet_ids        = module.vpc_mgmt.public_subnet_ids
  security_group_id = module.security_groups.sg_bastion_id
  instance_type     = var.bastion_instance_type
}

# =============================================================================
# Office VPN - one S2S VPN connection per remote office (Part 3B)
# =============================================================================
module "office_vpn" {
  source   = "./modules/office_vpn"
  for_each = var.offices

  project_name       = var.project_name
  office_name        = each.key
  office_cidr        = each.value.cidr
  transit_gateway_id = module.transit_gateway.tgw_id
  tgw_route_table_id = module.transit_gateway.tgw_default_route_table_id
  cgw_instance_type  = var.cgw_instance_type
}

# =============================================================================
# Monitoring (Phase 5D) - CloudTrail + S3 + SNS + CloudWatch alarms + dashboard
# =============================================================================
module "monitoring" {
  source             = "./modules/monitoring"
  project_name       = var.project_name
  notification_email = var.notification_email
  aws_region         = var.aws_region

  alb_arn_suffix     = module.app_fargate.alb_arn_suffix
  ecs_cluster_name   = module.app_fargate.ecs_cluster_name
  ecs_service_name   = module.app_fargate.ecs_service_name
  rds_instance_id    = module.database.db_instance_id
  rds_dr_instance_id = module.database_dr.replica_id
}

# =============================================================================
# DR Region (Phase 5A) - VPC Core/Data DR + TGW DR + inter-region peering
# =============================================================================
module "dr_region" {
  source       = "./modules/dr_region"
  project_name = var.project_name

  primary_tgw_id     = module.transit_gateway.tgw_id
  primary_aws_region = var.aws_region
  dr_aws_region      = var.dr_aws_region

  providers = {
    aws    = aws
    aws.dr = aws.dr
  }
}

# =============================================================================
# DR Database (Phase 5B) - cross-region read replica of primary RDS
# =============================================================================
module "database_dr" {
  source       = "./modules/database_dr"
  project_name = var.project_name

  source_db_arn        = module.database.db_instance_arn
  vpc_data_dr_id       = module.dr_region.vpc_data_dr_id
  db_subnet_group_name = module.dr_region.vpc_data_dr_db_subnet_group

  providers = {
    aws    = aws
    aws.dr = aws.dr
  }
}

# =============================================================================
# App Fargate DR (Phase 5C) - standby Fargate + ALB in DR region
# =============================================================================
module "app_fargate_dr" {
  source       = "./modules/app_fargate_dr"
  project_name = var.project_name

  vpc_id             = module.dr_region.vpc_core_dr_id
  public_subnet_ids  = module.dr_region.vpc_core_dr_public_subnet_ids
  private_subnet_ids = module.dr_region.vpc_core_dr_private_subnet_ids

  providers = {
    aws    = aws
    aws.dr = aws.dr
  }
}

# =============================================================================
# Edge (Phase 4D + 5C) - CloudFront + WAF + Origin Group failover to DR
# =============================================================================
module "edge" {
  source          = "./modules/edge"
  project_name    = var.project_name
  alb_dns_name    = module.app_fargate.alb_dns_name
  alb_dr_dns_name = module.app_fargate_dr.alb_dns_name # enables origin group failover

  providers = {
    aws           = aws
    aws.us_east_1 = aws.us_east_1
  }
}

# =============================================================================
# API Gateway + Lambda + SQS (Phase 4C) - driver mobile endpoint (Y9)
# =============================================================================
module "api_lambda" {
  source       = "./modules/api_lambda"
  project_name = var.project_name
}

# =============================================================================
# Aurora (Phase 4B) - 1 Writer + 2 Reader across 3 AZ in VPC Data
# =============================================================================
module "database" {
  source       = "./modules/database"
  project_name = var.project_name

  db_subnet_group_name = module.vpc_data.db_subnet_group_name
  security_group_id    = module.security_groups.sg_aurora_id
}

# =============================================================================
# App Fargate (Phase 4A) - Nginx "Hello VietMove" + ALB
# =============================================================================
module "app_fargate" {
  source       = "./modules/app_fargate"
  project_name = var.project_name

  vpc_id             = module.vpc_core.vpc_id
  public_subnet_ids  = module.vpc_core.public_subnet_ids
  private_subnet_ids = module.vpc_core.private_subnet_ids

  alb_security_group_id     = module.security_groups.sg_alb_id
  fargate_security_group_id = module.security_groups.sg_fargate_id
}

# =============================================================================
# Client VPN - remote employee access (Part 3B)
# =============================================================================
module "client_vpn" {
  source            = "./modules/client_vpn"
  project_name      = var.project_name
  vpc_id            = module.vpc_core.vpc_id
  security_group_id = module.security_groups.sg_vpn_id
  # Single subnet for demo (1 association = $0.10/h). Add more for HA.
  associated_subnet_ids = [module.vpc_core.private_subnet_ids[0]]
  client_cidr_block     = var.client_vpn_cidr_block

  # Routes for the OTHER VPCs that clients should reach via TGW.
  # Exclude the associated VPC's CIDR (auto-created) and the client_vpn_cidr_block (overlap).
  cross_vpc_cidrs = concat(
    [var.vpc_data_cidr, var.vpc_mgmt_cidr],
    [for o in var.offices : o.cidr]
  )
}
