variable "project_name" {
  description = "Project name for tags"
  type        = string
}

variable "vpc_id" {
  description = "VPC ID where Client VPN endpoint is created (typically VPC Core)"
  type        = string
}

variable "security_group_id" {
  description = "Security group for Client VPN ENI (sg-vpn from security_groups module)"
  type        = string
}

variable "associated_subnet_ids" {
  description = "Subnets to associate Client VPN with (each association = $0.10/h, 1 OK for demo)"
  type        = list(string)
}

variable "client_cidr_block" {
  description = "CIDR for client IPs (must not overlap with any internal CIDR), minimum /22"
  type        = string
  default     = "10.200.0.0/22"
}

variable "cross_vpc_cidrs" {
  description = "CIDRs to route via TGW (other VPCs and offices). Do NOT include the associated VPC's CIDR or the client_cidr_block. Routes are added per associated subnet."
  type        = list(string)
  default     = []
}
