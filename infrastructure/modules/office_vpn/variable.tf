variable "project_name" {
  description = "Project name for tags"
  type        = string
}

variable "office_name" {
  description = "Short identifier for the office (e.g. danang, hanoi)"
  type        = string
}

variable "office_cidr" {
  description = "CIDR for the simulated office VPC (e.g. 10.100.0.0/16)"
  type        = string
}

variable "transit_gateway_id" {
  description = "AWS TGW ID to attach this S2S VPN to"
  type        = string
}

variable "tgw_route_table_id" {
  description = "TGW route table ID where the static route for office CIDR is added"
  type        = string
}

variable "cgw_instance_type" {
  description = "EC2 instance type for CGW simulator (strongSwan)"
  type        = string
  default     = "t3.micro"
}
