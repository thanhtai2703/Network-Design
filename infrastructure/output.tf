output "vpc_core_id" {
  value = module.vpc_core.vpc_id
}

output "vpc_core_public_subnets" {
  value = module.vpc_core.public_subnet_ids
}

output "vpc_core_private_subnets" {
  value = module.vpc_core.private_subnet_ids
}
