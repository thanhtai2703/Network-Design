variable "project_name" {
  type = string
}

variable "source_db_arn" {
  description = "ARN of the primary RDS instance to replicate from (cross-region ARN)"
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

variable "instance_class" {
  type    = string
  default = "db.t3.micro"
}

variable "port" {
  type    = number
  default = 5432
}
