variable "project_name" {
  type = string
}

variable "db_subnet_group_name" {
  description = "Existing DB Subnet Group (from vpc_data module) covering 3 AZ"
  type        = string
}

variable "security_group_id" {
  description = "sg-aurora ID (PostgreSQL :5432 ingress)"
  type        = string
}

variable "engine" {
  description = "Aurora engine. Must be aurora-postgresql for an Aurora cluster."
  type        = string
  default     = "aurora-postgresql"
}

variable "engine_version" {
  description = "Aurora PostgreSQL engine version (NOT the same as RDS PostgreSQL versions). Check: aws rds describe-db-engine-versions --engine aurora-postgresql"
  type        = string
  default     = "16.4"
}

variable "port" {
  type    = number
  default = 5432
}

variable "instance_class" {
  description = "Aurora instance class. Aurora Global Database does NOT support burstable (t3/t4g) classes - smallest valid class is db.r5.large (or db.r6g.large on Graviton)."
  type        = string
  default     = "db.r6g.large"
}

variable "instance_count" {
  description = "Number of cluster instances (1 Writer + the rest Readers). 3 = 1 writer + 2 readers across 3 AZ."
  type        = number
  default     = 3
}

variable "database_name" {
  type    = string
  default = "vietmove"
}

variable "master_username" {
  type    = string
  default = "vietmove_admin"
}
