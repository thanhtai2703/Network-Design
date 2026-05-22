output "office_vpc_id" {
  value = aws_vpc.office.id
}

output "cgw_eip" {
  description = "Public IP of CGW (registered as AWS Customer Gateway IP)"
  value       = aws_eip.cgw.public_ip
}

output "cgw_instance_id" {
  value = aws_instance.cgw.id
}

output "workstation_instance_id" {
  description = "Workstation EC2 - use with: aws ssm start-session --target <id>"
  value       = aws_instance.workstation.id
}

output "vpn_connection_id" {
  value = aws_vpn_connection.office.id
}

output "vpn_tunnel1_address" {
  description = "AWS-side tunnel 1 outside IP"
  value       = aws_vpn_connection.office.tunnel1_address
}

output "vpn_tunnel1_preshared_key" {
  description = "PSK for tunnel 1 (sensitive)"
  value       = aws_vpn_connection.office.tunnel1_preshared_key
  sensitive   = true
}

output "ssm_session_workstation" {
  value = "aws ssm start-session --target ${aws_instance.workstation.id}"
}
