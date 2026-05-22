variable "project_name" {
  description = "Project name used for tags"
  type        = string
}

variable "subnet_ids" {
  description = "Public subnet IDs in VPC Mgmt (one Bastion per subnet)"
  type        = list(string)
}

variable "security_group_id" {
  description = "Security group ID for Bastion (sg-bastion)"
  type        = string
}

variable "instance_type" {
  description = "EC2 instance type"
  type        = string
  default     = "t3.micro"
}

variable "key_name" {
  description = "SSH key pair name (optional; SSM Session Manager works without it)"
  type        = string
  default     = null
}
