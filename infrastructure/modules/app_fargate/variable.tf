variable "project_name" {
  type = string
}

variable "vpc_id" {
  description = "VPC Core ID (where Fargate + ALB live)"
  type        = string
}

variable "public_subnet_ids" {
  description = "Public subnet IDs for ALB (>= 2 AZ)"
  type        = list(string)
}

variable "private_subnet_ids" {
  description = "Private subnet IDs for Fargate tasks (>= 2 AZ)"
  type        = list(string)
}

variable "alb_security_group_id" {
  type = string
}

variable "fargate_security_group_id" {
  type = string
}

variable "desired_count" {
  description = "Number of Fargate tasks"
  type        = number
  default     = 2
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
  description = "Region label shown on the web page (e.g. Sai Gon)"
  type        = string
  default     = "Sai Gon"
}
