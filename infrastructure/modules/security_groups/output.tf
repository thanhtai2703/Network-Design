output "sg_alb_id" {
  description = "ID of sg-alb (attach to ALB)"
  value       = aws_security_group.alb.id
}

output "sg_fargate_id" {
  description = "ID of sg-fargate (attach to Fargate task)"
  value       = aws_security_group.fargate.id
}

output "sg_lambda_id" {
  description = "ID of sg-lambda (attach to Lambda ENI)"
  value       = aws_security_group.lambda.id
}

output "sg_vpn_id" {
  description = "ID of sg-vpn (attach to Client VPN endpoint)"
  value       = aws_security_group.vpn.id
}

output "sg_vpc_endpoint_core_id" {
  description = "ID of SG for VPC Endpoint in Core"
  value       = aws_security_group.vpc_endpoint_core.id
}

output "sg_aurora_id" {
  description = "ID of sg-aurora"
  value       = aws_security_group.aurora.id
}

output "sg_vpc_endpoint_data_id" {
  description = "ID of SG for VPC Endpoint in Data"
  value       = aws_security_group.vpc_endpoint_data.id
}

output "sg_bastion_id" {
  description = "ID of sg-bastion"
  value       = aws_security_group.bastion.id
}

output "sg_vpc_endpoint_mgmt_id" {
  description = "ID of SG for VPC Endpoint in Mgmt"
  value       = aws_security_group.vpc_endpoint_mgmt.id
}
