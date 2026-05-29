variable "project_name" {
  type = string
}

variable "global_cluster_id" {
  description = "Aurora Global Database identifier from the primary `database` module - this secondary cluster joins it"
  type        = string
}

variable "vpc_data_dr_id" {
  description = "VPC Data DR ID"
  type        = string
}

variable "vpc_data_dr_cidr" {
  description = "VPC Data DR CIDR block (for SG description)"
  type        = string
  default     = "10.12.0.0/16"
}

variable "db_subnet_group_name" {
  description = "DR DB Subnet Group (from dr_region module)"
  type        = string
}

variable "engine" {
  description = "Must match the global cluster engine"
  type        = string
  default     = "aurora-postgresql"
}

variable "engine_version" {
  description = "Must match the global cluster engine version"
  type        = string
  default     = "16.4"
}

variable "instance_class" {
  description = "Aurora instance class for the DR cluster. Aurora Global Database does NOT support burstable (t3/t4g) classes - use db.r5.large / db.r6g.large. Must match the primary's family."
  type        = string
  default     = "db.r6g.large"
}

variable "instance_count" {
  description = "Number of read instances in the DR secondary cluster"
  type        = number
  default     = 1
}

variable "port" {
  type    = number
  default = 5432
}
