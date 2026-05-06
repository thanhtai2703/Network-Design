output "vpc_id" {
  description = "ID của VPC Core"
  value       = aws_vpc.main.id
}

output "public_subnet_ids" {
  description = "Danh sách ID các Public Subnets"
  value       = aws_subnet.public[*].id
}

output "private_subnet_ids" {
  description = "Danh sách ID các Private Subnets"
  value       = aws_subnet.private[*].id
}

output "nat_gateway_ips" {
  description = "Địa chỉ IP Public của các NAT Gateways"
  value       = aws_eip.nat[*].public_ip
}
