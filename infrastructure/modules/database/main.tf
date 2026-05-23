# =============================================================================
# RDS PostgreSQL Single-AZ (4B) - free-tier compatible
# =============================================================================
# Original plan: Aurora 1 Writer + 2 Reader, 3 AZ.
# Free-tier account does not allow Aurora clusters or Multi-AZ DB Clusters.
# Falling back to single instance RDS PostgreSQL (db.t3.micro, gp3 20 GB).
#
# Trade-off acknowledged for the demo:
#   - Lose: read replicas, multi-AZ failover, reader endpoint
#   - Keep: encrypted storage, Secrets Manager managed password,
#           same security group + cross-VPC access via TGW,
#           same connection workflow from Bastion
# When presenting, frame this as "scope-down for free-tier; production
# would use Multi-AZ DB Cluster or Aurora with 2 read replicas."
# =============================================================================

resource "aws_db_instance" "main" {
  identifier = "${lower(var.project_name)}-postgres"

  engine         = var.engine
  engine_version = var.engine_version
  port           = var.port

  instance_class    = var.instance_class
  allocated_storage = var.allocated_storage
  storage_type      = var.storage_type
  storage_encrypted = true

  db_name  = var.database_name
  username = var.master_username

  # Managed master password -> Secrets Manager (same as Aurora plan)
  manage_master_user_password = true

  db_subnet_group_name   = var.db_subnet_group_name
  vpc_security_group_ids = [var.security_group_id]
  publicly_accessible    = false
  multi_az               = false # Single-AZ for free tier

  backup_retention_period      = 1
  backup_window                = "17:00-18:00"
  maintenance_window           = "sun:18:00-sun:19:00"
  auto_minor_version_upgrade   = true
  performance_insights_enabled = false

  skip_final_snapshot = true
  apply_immediately   = true
  deletion_protection = false

  tags = { Name = "${var.project_name}-RDS-Postgres" }
}
