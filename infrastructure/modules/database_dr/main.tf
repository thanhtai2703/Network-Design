# =============================================================================
# 5B - RDS PostgreSQL cross-region read replica
# =============================================================================
# - Source: primary RDS in ap-southeast-1 (vietmove-postgres)
# - Replica: this module creates an instance in ap-southeast-2
# - Replication is async (typical lag <2s)
# - To failover: aws rds promote-read-replica --db-instance-identifier <id>
# =============================================================================

terraform {
  required_providers {
    aws = {
      source                = "hashicorp/aws"
      configuration_aliases = [aws.dr]
    }
  }
}

# AWS-managed KMS key for RDS in DR region. Used to encrypt the cross-region
# replica - cross-region replicas MUST specify a key in the destination region
# (the source key in the primary region is not reachable).
data "aws_kms_alias" "rds_dr" {
  provider = aws.dr
  name     = "alias/aws/rds"
}


# -----------------------------------------------------------------------------
# 1. Security Group for DR replica
# Allow :5432 from any internal CIDR (10/8) - reached via TGW peering from
# primary VPCs or from DR VPC Core (future Fargate DR).
# -----------------------------------------------------------------------------
resource "aws_security_group" "rds_dr" {
  provider    = aws.dr
  name        = "${var.project_name}-sg-rds-dr"
  description = "RDS read replica in DR region, accept PostgreSQL from internal"
  vpc_id      = var.vpc_data_dr_id

  tags = { Name = "${var.project_name}-sg-rds-dr" }
}

resource "aws_vpc_security_group_ingress_rule" "rds_dr_pg" {
  provider          = aws.dr
  security_group_id = aws_security_group.rds_dr.id
  cidr_ipv4         = "10.0.0.0/8"
  from_port         = var.port
  to_port           = var.port
  ip_protocol       = "tcp"
  description       = "PostgreSQL from any internal CIDR (via TGW peering)"
}


# -----------------------------------------------------------------------------
# 2. Read replica instance
# Cross-region replica via replicate_source_db = source ARN
# -----------------------------------------------------------------------------
resource "aws_db_instance" "replica" {
  provider   = aws.dr
  identifier = "${lower(var.project_name)}-postgres-dr"

  # Replicate from primary - all engine/version/storage settings inherited from source
  replicate_source_db = var.source_db_arn

  instance_class = var.instance_class

  db_subnet_group_name   = var.db_subnet_group_name
  vpc_security_group_ids = [aws_security_group.rds_dr.id]
  publicly_accessible    = false
  multi_az               = false

  # Required > 0 so this replica could be promoted in future
  backup_retention_period = 1

  # Cross-region replica from an encrypted source MUST set kms_key_id to a key
  # in the DESTINATION region. Using the AWS-managed RDS key (free, simplest).
  kms_key_id = data.aws_kms_alias.rds_dr.target_key_arn

  skip_final_snapshot = true
  apply_immediately   = true
  deletion_protection = false

  performance_insights_enabled = false

  tags = { Name = "${var.project_name}-RDS-Postgres-DR" }
}
