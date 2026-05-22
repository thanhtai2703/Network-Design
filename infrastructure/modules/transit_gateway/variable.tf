variable "project_name" {
  description = "Project name used for tags"
  type        = string
}

# VPC Core
variable "vpc_core_id" {
  description = "ID of VPC Core"
  type        = string
}

variable "vpc_core_attach_subnet_ids" {
  description = "Subnet IDs in VPC Core for TGW attachment (one per AZ, private subnets)"
  type        = list(string)
}

variable "vpc_core_private_route_table_ids" {
  description = "Private route table IDs in VPC Core (one per AZ)"
  type        = list(string)
}

# VPC Data
variable "vpc_data_id" {
  description = "ID of VPC Data Layer"
  type        = string
}

variable "vpc_data_attach_subnet_ids" {
  description = "Subnet IDs in VPC Data for TGW attachment"
  type        = list(string)
}

variable "vpc_data_private_route_table_id" {
  description = "Private route table ID in VPC Data"
  type        = string
}

# VPC Mgmt
variable "vpc_mgmt_id" {
  description = "ID of VPC Mgmt"
  type        = string
}

variable "vpc_mgmt_attach_subnet_ids" {
  description = "Subnet IDs in VPC Mgmt for TGW attachment"
  type        = list(string)
}

variable "vpc_mgmt_public_route_table_id" {
  description = "Public route table ID in VPC Mgmt"
  type        = string
}
