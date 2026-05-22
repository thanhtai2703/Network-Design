output "tgw_id" {
  description = "ID of Transit Gateway"
  value       = aws_ec2_transit_gateway.main.id
}

output "tgw_arn" {
  description = "ARN of Transit Gateway"
  value       = aws_ec2_transit_gateway.main.arn
}

output "tgw_default_route_table_id" {
  description = "ID of default TGW route table"
  value       = aws_ec2_transit_gateway.main.association_default_route_table_id
}

output "attachment_core_id" {
  value = aws_ec2_transit_gateway_vpc_attachment.core.id
}

output "attachment_data_id" {
  value = aws_ec2_transit_gateway_vpc_attachment.data.id
}

output "attachment_mgmt_id" {
  value = aws_ec2_transit_gateway_vpc_attachment.mgmt.id
}
