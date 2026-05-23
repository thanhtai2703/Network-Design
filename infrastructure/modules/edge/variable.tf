variable "project_name" {
  type = string
}

variable "alb_dns_name" {
  description = "ALB DNS name from app_fargate module (used as CloudFront origin)"
  type        = string
}

variable "waf_rate_limit" {
  description = "Per-5-min rate limit per source IP (rate-based rule)"
  type        = number
  default     = 2000
}
