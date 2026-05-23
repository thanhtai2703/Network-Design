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
  type    = string
  default = "postgres"
}

variable "engine_version" {
  type    = string
  default = "17.10"
}

variable "port" {
  type    = number
  default = 5432
}

variable "instance_class" {
  description = "RDS instance class. Free tier supports db.t3.micro / db.t4g.micro."
  type        = string
  default     = "db.t3.micro"
}

variable "allocated_storage" {
  description = "Storage size in GB. Free tier allows up to 20 GB."
  type        = number
  default     = 20
}

variable "storage_type" {
  type    = string
  default = "gp3"
}

variable "database_name" {
  type    = string
  default = "vietmove"
}

variable "master_username" {
  type    = string
  default = "vietmove_admin"
}
