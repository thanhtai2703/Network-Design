output "global_cluster_id" {
  description = "Aurora Global Database identifier (DR secondary cluster joins this)"
  value       = aws_rds_global_cluster.main.id
}

output "cluster_id" {
  description = "Primary Aurora cluster identifier (used by monitoring dimensions)"
  value       = aws_rds_cluster.main.cluster_identifier
}

output "cluster_arn" {
  description = "Primary Aurora cluster ARN"
  value       = aws_rds_cluster.main.arn
}

# Kept for naming compatibility with callers that still pass db_instance_id /
# db_instance_arn (root main.tf, monitoring).
output "db_instance_id" {
  description = "Alias of cluster_id - Aurora CloudWatch metrics use DBClusterIdentifier"
  value       = aws_rds_cluster.main.cluster_identifier
}

output "db_instance_arn" {
  description = "Alias of cluster_arn"
  value       = aws_rds_cluster.main.arn
}

output "writer_endpoint" {
  description = "Cluster writer endpoint (always points at the current primary instance)"
  value       = aws_rds_cluster.main.endpoint
}

output "reader_endpoint" {
  description = "Cluster reader endpoint - load-balances reads across the 2 reader instances"
  value       = aws_rds_cluster.main.reader_endpoint
}

output "database_name" {
  value = aws_rds_cluster.main.database_name
}

output "master_username" {
  value = aws_rds_cluster.main.master_username
}

output "master_user_secret_arn" {
  description = "Secrets Manager ARN with master password (JSON: {username, password})"
  value       = aws_secretsmanager_secret.master.arn
}

output "port" {
  value = aws_rds_cluster.main.port
}
