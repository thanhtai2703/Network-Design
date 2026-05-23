variable "project_name" {
  type = string
}

variable "vpc_id" {
  description = "VPC Core DR ID"
  type        = string
}

variable "public_subnet_ids" {
  description = "Public subnets in VPC Core DR (>= 2 AZ) for ALB"
  type        = list(string)
}

variable "private_subnet_ids" {
  description = "Private subnets in VPC Core DR for Fargate tasks"
  type        = list(string)
}

variable "desired_count" {
  description = "Desired Fargate task count. 1 = warm standby; scale up on failover."
  type        = number
  default     = 1
}

variable "task_cpu" {
  type    = string
  default = "256"
}

variable "task_memory" {
  type    = string
  default = "512"
}

variable "region_label" {
  description = "Region label on the web page"
  type        = string
  default     = "Ha Noi (DR)"
}
