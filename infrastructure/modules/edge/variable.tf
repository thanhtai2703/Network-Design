variable "project_name" {
  type = string
}

variable "alb_dns_name" {
  description = "Primary ALB DNS (CloudFront primary origin)"
  type        = string
}

variable "alb_dr_dns_name" {
  description = "DR ALB DNS (CloudFront secondary origin for failover). Empty string = no failover."
  type        = string
  default     = ""
}

variable "waf_rate_limit" {
  description = "Per-5-min rate limit per source IP (rate-based rule)"
  type        = number
  default     = 2000
}
