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

# ---------------------------------------------------------------------------
# Transit Gateway
# ---------------------------------------------------------------------------
output "tgw_id" {
  value = module.transit_gateway.tgw_id
}

# ---------------------------------------------------------------------------
# VPC Endpoints
# ---------------------------------------------------------------------------
output "vpc_endpoints" {
  description = "IDs of all VPC Endpoints, grouped by VPC"
  value = {
    core_gateway   = module.vpc_endpoint_core.gateway_endpoint_ids
    core_interface = module.vpc_endpoint_core.interface_endpoint_ids
    data_gateway   = module.vpc_endpoint_data.gateway_endpoint_ids
    mgmt_interface = module.vpc_endpoint_mgmt.interface_endpoint_ids
  }
}

# ---------------------------------------------------------------------------
# Bastion
# ---------------------------------------------------------------------------
output "bastion_instance_ids" {
  value = module.bastion.instance_ids
}

output "bastion_public_ips" {
  value = module.bastion.public_ips
}

output "bastion_ssm_commands" {
  description = "Copy-paste these to start SSM session into each Bastion"
  value       = module.bastion.ssm_start_session_commands
}

# ---------------------------------------------------------------------------
# Office VPN (per office)
# ---------------------------------------------------------------------------
output "office_vpn_summary" {
  description = "Per-office VPN details (EIP, instance IDs, SSM commands)"
  value = {
    for k, m in module.office_vpn : k => {
      cgw_public_ip       = m.cgw_eip
      cgw_instance_id     = m.cgw_instance_id
      workstation_id      = m.workstation_instance_id
      ssm_workstation_cmd = m.ssm_session_workstation
      vpn_connection_id   = m.vpn_connection_id
    }
  }
}

# ---------------------------------------------------------------------------
# Client VPN
# ---------------------------------------------------------------------------
output "client_vpn_endpoint_id" {
  value = module.client_vpn.endpoint_id
}

output "client_vpn_endpoint_dns" {
  value = module.client_vpn.endpoint_dns
}

output "client_vpn_ovpn_file" {
  description = "Path to the .ovpn file - import into AWS VPN Client"
  value       = module.client_vpn.ovpn_file_path
}
