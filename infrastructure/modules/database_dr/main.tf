# =============================================================================
# 5B - Aurora PostgreSQL cross-region SECONDARY cluster (Aurora Global Database)
# =============================================================================
# - Joins the global cluster created in the `database` module (primary region)
# - Async physical replication managed by Aurora (typical lag <1s)
# - Read-only until promoted. Failover (managed):
#     aws rds failover-global-cluster \
#       --global-cluster-identifier vietmove-aurora-global \
#       --target-db-cluster-identifier <this cluster ARN>
#
# Replaces the previous single-instance RDS read replica. Aurora cross-region
# replication is done via Global Database, NOT replicate_source_db.
# =============================================================================

terraform {
  required_providers {
    aws = {
      source                = "hashicorp/aws"
      configuration_aliases = [aws.dr]
    }
  }
}

# AWS-managed KMS key for RDS in the DR region. A cross-region Aurora secondary
# must encrypt with a key in its OWN region (the primary's key is not reachable).
data "aws_kms_alias" "rds_dr" {
  provider = aws.dr
  name     = "alias/aws/rds"
}


# -----------------------------------------------------------------------------
# 1. Security Group for the DR cluster
# Allow :5432 from any internal CIDR (10/8) - reached via TGW peering from
# primary VPCs or from DR VPC Core (Fargate DR).
# -----------------------------------------------------------------------------
resource "aws_security_group" "rds_dr" {
  provider    = aws.dr
  name        = "${var.project_name}-sg-aurora-dr"
  description = "Aurora secondary in DR region, accept PostgreSQL from internal"
  vpc_id      = var.vpc_data_dr_id

  tags = { Name = "${var.project_name}-sg-aurora-dr" }
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
# 2. Secondary Aurora cluster (DR region) joined to the global cluster
# No master credentials / database_name here - inherited from the global cluster.
# -----------------------------------------------------------------------------
resource "aws_rds_cluster" "dr" {
  provider                  = aws.dr
  cluster_identifier        = "${lower(var.project_name)}-aurora-dr"
  global_cluster_identifier = var.global_cluster_id

  engine         = var.engine
  engine_version = var.engine_version

  db_subnet_group_name   = var.db_subnet_group_name
  vpc_security_group_ids = [aws_security_group.rds_dr.id]
  storage_encrypted      = true
  kms_key_id             = data.aws_kms_alias.rds_dr.target_key_arn

  # Required >= 1 (Aurora minimum). Lets this cluster be promoted later.
  backup_retention_period = 1

  skip_final_snapshot = true
  apply_immediately   = true
  deletion_protection = false

  # The primary cluster owns the global membership; on a managed failover the
  # roles swap. Ignore so Terraform doesn't fight Aurora over who is primary.
  lifecycle {
    ignore_changes = [global_cluster_identifier, replication_source_identifier]
  }
}


# -----------------------------------------------------------------------------
# 3. At least one instance in the secondary cluster (the read node)
# -----------------------------------------------------------------------------
resource "aws_rds_cluster_instance" "dr" {
  provider           = aws.dr
  count              = var.instance_count
  identifier         = "${lower(var.project_name)}-aurora-dr-${count.index + 1}"
  cluster_identifier = aws_rds_cluster.dr.id

  instance_class = var.instance_class
  engine         = aws_rds_cluster.dr.engine
  engine_version = aws_rds_cluster.dr.engine_version

  db_subnet_group_name = var.db_subnet_group_name
  publicly_accessible  = false

  performance_insights_enabled = false

  tags = { Name = "${var.project_name}-Aurora-DR-${count.index + 1}" }
}
