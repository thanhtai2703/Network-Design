output "replica_id" {
  value = aws_db_instance.replica.id
}

output "replica_endpoint" {
  value = aws_db_instance.replica.address
}

output "replica_arn" {
  value = aws_db_instance.replica.arn
}

output "replica_port" {
  value = aws_db_instance.replica.port
}

output "security_group_id" {
  value = aws_security_group.rds_dr.id
}
