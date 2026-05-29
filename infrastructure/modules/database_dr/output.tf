output "cluster_id" {
  value = aws_rds_cluster.dr.cluster_identifier
}

output "cluster_arn" {
  value = aws_rds_cluster.dr.arn
}

# Kept for naming compatibility with callers that still read replica_* names.
output "replica_id" {
  description = "Alias of cluster_id - Aurora metrics use DBClusterIdentifier"
  value       = aws_rds_cluster.dr.cluster_identifier
}

output "replica_endpoint" {
  description = "DR cluster reader endpoint (ap-southeast-2)"
  value       = aws_rds_cluster.dr.reader_endpoint
}

output "writer_endpoint" {
  description = "DR cluster endpoint - becomes writable after a managed failover"
  value       = aws_rds_cluster.dr.endpoint
}

output "replica_port" {
  value = aws_rds_cluster.dr.port
}

output "security_group_id" {
  value = aws_security_group.rds_dr.id
}
