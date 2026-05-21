output "vpc_id" {
  description = "ID of VPC Data Layer"
  value       = aws_vpc.main.id
}

output "private_subnet_ids" {
  description = "List of private subnet IDs"
  value       = aws_subnet.private[*].id
}

output "private_subnet_cidrs" {
  description = "List of private subnet CIDRs for cross-VPC SG and NACL rules"
  value       = aws_subnet.private[*].cidr_block
}

output "private_route_table_id" {
  description = "Private route table ID for TGW route propagation"
  value       = aws_route_table.private.id
}

output "db_subnet_group_name" {
  description = "DB Subnet Group name for Aurora"
  value       = aws_db_subnet_group.aurora.name
}

output "elasticache_subnet_group_name" {
  description = "ElastiCache Subnet Group name for Redis"
  value       = aws_elasticache_subnet_group.redis.name
}
