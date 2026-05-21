# ---------------------------------------------------------------------------
# VPC Core
# ---------------------------------------------------------------------------
output "vpc_core_id" {
  value = module.vpc_core.vpc_id
}

output "vpc_core_public_subnets" {
  value = module.vpc_core.public_subnet_ids
}

output "vpc_core_private_subnets" {
  value = module.vpc_core.private_subnet_ids
}

output "vpc_core_nat_ips" {
  value = module.vpc_core.nat_gateway_ips
}

# ---------------------------------------------------------------------------
# VPC Data
# ---------------------------------------------------------------------------
output "vpc_data_id" {
  value = module.vpc_data.vpc_id
}

output "vpc_data_private_subnets" {
  value = module.vpc_data.private_subnet_ids
}

output "vpc_data_db_subnet_group" {
  value = module.vpc_data.db_subnet_group_name
}

output "vpc_data_redis_subnet_group" {
  value = module.vpc_data.elasticache_subnet_group_name
}

# ---------------------------------------------------------------------------
# VPC Mgmt
# ---------------------------------------------------------------------------
output "vpc_mgmt_id" {
  value = module.vpc_mgmt.vpc_id
}

output "vpc_mgmt_public_subnets" {
  value = module.vpc_mgmt.public_subnet_ids
}

# ---------------------------------------------------------------------------
# Security Groups
# ---------------------------------------------------------------------------
output "sg_ids" {
  description = "IDs of all Security Groups"
  value = {
    alb       = module.security_groups.sg_alb_id
    fargate   = module.security_groups.sg_fargate_id
    lambda    = module.security_groups.sg_lambda_id
    vpn       = module.security_groups.sg_vpn_id
    vpce_core = module.security_groups.sg_vpc_endpoint_core_id
    aurora    = module.security_groups.sg_aurora_id
    redis     = module.security_groups.sg_redis_id
    vpce_data = module.security_groups.sg_vpc_endpoint_data_id
    bastion   = module.security_groups.sg_bastion_id
    vpce_mgmt = module.security_groups.sg_vpc_endpoint_mgmt_id
  }
}
