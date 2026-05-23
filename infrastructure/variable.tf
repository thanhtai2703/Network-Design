variable "aws_region" {
  description = "Primary AWS Region for HQ"
  default     = "ap-southeast-1"
}

variable "dr_aws_region" {
  description = "DR AWS Region (Phase 5)"
  default     = "ap-southeast-2"
}

variable "project_name" {
  description = "Project name used for resource tags"
  default     = "VietMove"
}

variable "vpc_core_cidr" {
  description = "CIDR block for VPC Core"
  default     = "10.1.0.0/16"
}

variable "vpc_data_cidr" {
  description = "CIDR block for VPC Data Layer"
  default     = "10.2.0.0/16"
}

variable "vpc_mgmt_cidr" {
  description = "CIDR block for VPC Security and Management"
  default     = "10.3.0.0/16"
}

variable "admin_ssh_cidrs" {
  description = "List of CIDRs allowed to SSH into Bastion (office or admin IPs)"
  type        = list(string)
  default     = []
}

variable "bastion_instance_type" {
  description = "EC2 instance type for Bastion hosts"
  type        = string
  default     = "t3.micro"
}

# =============================================================================
# Part 3B - VPN and offices
# =============================================================================

variable "offices" {
  description = "Map of remote offices that connect via S2S VPN. Key is the office short name (used in resource names)."
  type = map(object({
    cidr = string
  }))
  default = {
    danang = { cidr = "10.100.0.0/16" }
    hanoi  = { cidr = "10.101.0.0/16" }
  }
}

variable "cgw_instance_type" {
  description = "EC2 instance type for CGW simulators (strongSwan)"
  type        = string
  default     = "t3.micro"
}

variable "client_vpn_cidr_block" {
  description = "CIDR for AWS Client VPN to assign to connecting clients (must be >= /22, must not overlap with internal CIDRs)"
  type        = string
  default     = "10.200.0.0/22"
}

# =============================================================================
# Phase 5D - Monitoring
# =============================================================================

variable "notification_email" {
  description = "Email to receive CloudWatch alarm notifications (Phase 5D). AWS will send a confirmation link after apply - must be clicked."
  type        = string
  default     = "23521380@gm.uit.edu.vn"
}
