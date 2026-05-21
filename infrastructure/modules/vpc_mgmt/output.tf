output "vpc_id" {
  description = "ID of VPC Mgmt"
  value       = aws_vpc.main.id
}

output "public_subnet_ids" {
  description = "List of public subnet IDs (Bastion)"
  value       = aws_subnet.public[*].id
}

output "public_subnet_cidrs" {
  description = "List of public subnet CIDRs for cross-VPC SG and NACL rules"
  value       = aws_subnet.public[*].cidr_block
}

output "public_route_table_id" {
  description = "Public route table ID for TGW route propagation"
  value       = aws_route_table.public.id
}
