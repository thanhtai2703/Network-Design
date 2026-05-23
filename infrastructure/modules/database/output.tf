output "db_instance_id" {
  value = aws_db_instance.main.id
}

output "writer_endpoint" {
  description = "DB endpoint (single instance — same endpoint for read and write)"
  value       = aws_db_instance.main.address
}

# Kept for naming compatibility with the original plan. Points to the same
# single instance — there is no separate reader endpoint in this fallback.
output "reader_endpoint" {
  description = "Same as writer_endpoint (no replicas in free-tier deployment)"
  value       = aws_db_instance.main.address
}

output "database_name" {
  value = aws_db_instance.main.db_name
}

output "master_username" {
  value = aws_db_instance.main.username
}

output "master_user_secret_arn" {
  description = "Secrets Manager ARN with master password (JSON: {username, password})"
  value       = aws_db_instance.main.master_user_secret[0].secret_arn
}

output "port" {
  value = aws_db_instance.main.port
}
