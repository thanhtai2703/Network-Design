terraform {
  required_version = ">= 1.0.0"
}

provider "aws" {
  region = var.aws_region
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
