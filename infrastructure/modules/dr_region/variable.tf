variable "project_name" {
  type = string
}

variable "vpc_core_dr_cidr" {
  description = "DR Core VPC CIDR (do not overlap with primary 10.1/16, 10.2/16, 10.3/16, 10.100/16, 10.200.0.0/22)"
  type        = string
  default     = "10.11.0.0/16"
}

variable "vpc_data_dr_cidr" {
  description = "DR Data VPC CIDR"
  type        = string
  default     = "10.12.0.0/16"
}

variable "primary_tgw_id" {
  description = "Transit Gateway ID in the primary region (for peering)"
  type        = string
}

variable "primary_aws_region" {
  description = "Primary region name (e.g. ap-southeast-1) — accepter side of TGW peering"
  type        = string
}

variable "dr_aws_region" {
  description = "DR region name (e.g. ap-southeast-2) — requester side"
  type        = string
}
