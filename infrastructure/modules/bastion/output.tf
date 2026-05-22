output "instance_ids" {
  description = "List of Bastion EC2 instance IDs"
  value       = aws_instance.bastion[*].id
}

output "private_ips" {
  description = "List of Bastion private IPs"
  value       = aws_instance.bastion[*].private_ip
}

output "public_ips" {
  description = "List of Bastion public IPs"
  value       = aws_instance.bastion[*].public_ip
}

output "iam_role_arn" {
  description = "ARN of Bastion IAM role"
  value       = aws_iam_role.bastion.arn
}

output "ssm_start_session_commands" {
  description = "Ready-to-run AWS CLI commands to start SSM session into each Bastion"
  value       = [for id in aws_instance.bastion[*].id : "aws ssm start-session --target ${id}"]
}
