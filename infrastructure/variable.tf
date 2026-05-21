variable "aws_region" {
  description = "AWS Region for HQ"
  default     = "ap-southeast-1"
}

variable "project_name" {
  description = "Project name used for resource tags"
  default     = "VietMove"
}

variable "vpc_core_cidr" {
  description = "CIDR block for VPC Core"
  default     = "10.1.0.0/16"
}

variable "vpc_data_cidr" {
  description = "CIDR block for VPC Data Layer"
  default     = "10.2.0.0/16"
}

variable "vpc_mgmt_cidr" {
  description = "CIDR block for VPC Security and Management"
  default     = "10.3.0.0/16"
}

variable "admin_ssh_cidrs" {
  description = "List of CIDRs allowed to SSH into Bastion (office or admin IPs)"
  type        = list(string)
  default     = []
}
