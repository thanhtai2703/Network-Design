variable "name_prefix" {
  description = "Prefix for endpoint names (e.g. VietMove-Core)"
  type        = string
}

variable "vpc_id" {
  description = "ID of the VPC where endpoints are created"
  type        = string
}

variable "route_table_ids" {
  description = "Route table IDs that Gateway endpoints (S3, DynamoDB) attach to"
  type        = list(string)
  default     = []
}

variable "subnet_ids" {
  description = "Subnet IDs for Interface endpoints (one per AZ)"
  type        = list(string)
  default     = []
}

variable "security_group_id" {
  description = "Security group ID for Interface endpoint ENIs"
  type        = string
  default     = null
}

variable "gateway_services" {
  description = "List of Gateway endpoint services (e.g. s3, dynamodb)"
  type        = list(string)
  default     = []
}

variable "interface_services" {
  description = "List of Interface endpoint services (e.g. ssm, ec2messages, ecr.api)"
  type        = list(string)
  default     = []
}
