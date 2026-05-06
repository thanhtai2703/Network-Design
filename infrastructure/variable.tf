variable "aws_region" {
  description = "AWS Region cho trụ sở chính"
  default     = "ap-southeast-1"
}

variable "vpc_core_cidr" {
  description = "CIDR block cho VPC Core"
  default     = "10.1.0.0/16"
}
