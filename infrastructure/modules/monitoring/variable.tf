variable "project_name" {
  type = string
}

variable "notification_email" {
  description = "Email address to receive alarm notifications. AWS sends a confirmation email after apply - you MUST click the link to start receiving alerts."
  type        = string
}

variable "aws_region" {
  description = "Primary AWS region (for ARNs / metric dimensions)"
  type        = string
}

# Metric dimension inputs - keep optional so the module degrades gracefully
# if any of these aren't deployed yet.
variable "alb_arn_suffix" {
  description = "ALB ARN suffix (everything after :loadbalancer/) - for ALB metrics"
  type        = string
  default     = ""
}

variable "ecs_cluster_name" {
  type    = string
  default = ""
}

variable "ecs_service_name" {
  type    = string
  default = ""
}

variable "rds_instance_id" {
  description = "Primary RDS instance identifier"
  type        = string
  default     = ""
}

variable "rds_dr_instance_id" {
  description = "DR RDS read replica identifier (for ReplicaLag alarm)"
  type        = string
  default     = ""
}

variable "log_retention_days" {
  type    = number
  default = 90
}
