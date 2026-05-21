variable "project_name" {
  description = "Project name used for tags and SG names"
  type        = string
}

# VPC Core
variable "vpc_core_id" {
  description = "ID of VPC Core"
  type        = string
}

variable "vpc_core_cidr" {
  description = "CIDR of VPC Core"
  type        = string
}

variable "vpc_core_private_cidrs" {
  description = "List of private subnet CIDRs in VPC Core (Fargate and Lambda)"
  type        = list(string)
}

# VPC Data
variable "vpc_data_id" {
  description = "ID of VPC Data Layer"
  type        = string
}

variable "vpc_data_cidr" {
  description = "CIDR of VPC Data Layer"
  type        = string
}

variable "vpc_data_private_cidrs" {
  description = "List of private subnet CIDRs in VPC Data (Aurora and Redis)"
  type        = list(string)
}

# VPC Mgmt
variable "vpc_mgmt_id" {
  description = "ID of VPC Mgmt"
  type        = string
}

variable "vpc_mgmt_cidr" {
  description = "CIDR of VPC Mgmt"
  type        = string
}

variable "vpc_mgmt_public_cidrs" {
  description = "List of public subnet CIDRs in VPC Mgmt (Bastion)"
  type        = list(string)
}

# Admin SSH whitelist
variable "admin_ssh_cidrs" {
  description = "List of CIDRs allowed to SSH into Bastion (office or admin IPs)"
  type        = list(string)
  default     = []
}
