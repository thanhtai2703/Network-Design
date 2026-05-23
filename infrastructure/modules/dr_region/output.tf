output "vpc_core_dr_id" {
  value = aws_vpc.core_dr.id
}

output "vpc_core_dr_public_subnet_ids" {
  value = aws_subnet.core_dr_public[*].id
}

output "vpc_core_dr_private_subnet_ids" {
  value = aws_subnet.core_dr_private[*].id
}

output "vpc_data_dr_id" {
  value = aws_vpc.data_dr.id
}

output "vpc_data_dr_private_subnet_ids" {
  value = aws_subnet.data_dr_private[*].id
}

output "vpc_data_dr_db_subnet_group" {
  value = aws_db_subnet_group.data_dr.name
}

output "tgw_dr_id" {
  value = aws_ec2_transit_gateway.dr.id
}

output "tgw_peering_attachment_id" {
  value = aws_ec2_transit_gateway_peering_attachment.dr_to_primary.id
}

output "nat_dr_public_ip" {
  value = aws_eip.core_dr_nat.public_ip
}
