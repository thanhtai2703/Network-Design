# =============================================================================
# Office VPN - simulates one remote office connecting to AWS via S2S VPN
# =============================================================================
# Each office gets:
# - Own VPC (e.g. 10.100.0.0/16 for Da Nang)
# - 1 public subnet with IGW
# - EIP (used as Customer Gateway public IP)
# - CGW EC2 with strongSwan auto-configured for tunnel UP
# - 1 workstation EC2 inside office subnet (for ping testing)
# - AWS Customer Gateway + S2S VPN connection attached to TGW
# - Static route on TGW back to office CIDR
# =============================================================================

data "aws_availability_zones" "available" {
  state = "available"
}

# Latest Amazon Linux 2023 AMI for CGW and workstation test hosts.
# AL2023 has a reliable systemd-based SSM Agent path, matching the Bastion hosts.
data "aws_ami" "al2023" {
  most_recent = true
  owners      = ["amazon"]
  filter {
    name   = "name"
    values = ["al2023-ami-*-x86_64"]
  }

  filter {
    name   = "architecture"
    values = ["x86_64"]
  }
}


# ---------------------------------------------------------------------------
# Office VPC
# ---------------------------------------------------------------------------
resource "aws_vpc" "office" {
  cidr_block           = var.office_cidr
  enable_dns_hostnames = true
  enable_dns_support   = true

  tags = { Name = "${var.project_name}-Office-${var.office_name}" }
}

resource "aws_internet_gateway" "office" {
  vpc_id = aws_vpc.office.id
  tags   = { Name = "${var.project_name}-Office-${var.office_name}-IGW" }
}

# Public subnet (CGW lives here, has EIP)
resource "aws_subnet" "office_public" {
  vpc_id                  = aws_vpc.office.id
  cidr_block              = cidrsubnet(var.office_cidr, 8, 1)
  availability_zone       = data.aws_availability_zones.available.names[0]
  map_public_ip_on_launch = true
  tags                    = { Name = "Office-${var.office_name}-Public" }
}

# Private subnet (workstation lives here, traffic to AWS goes via CGW)
resource "aws_subnet" "office_private" {
  vpc_id            = aws_vpc.office.id
  cidr_block        = cidrsubnet(var.office_cidr, 8, 10)
  availability_zone = data.aws_availability_zones.available.names[0]
  tags              = { Name = "Office-${var.office_name}-Private" }
}

resource "aws_route_table" "office_public" {
  vpc_id = aws_vpc.office.id
  route {
    cidr_block = "0.0.0.0/0"
    gateway_id = aws_internet_gateway.office.id
  }
  tags = { Name = "Office-${var.office_name}-Public-RT" }
}

resource "aws_route_table_association" "office_public" {
  subnet_id      = aws_subnet.office_public.id
  route_table_id = aws_route_table.office_public.id
}

# Private RT: 0.0.0.0/0 via IGW for general Internet (yum), 10.0.0.0/8 via CGW EC2
resource "aws_route_table" "office_private" {
  vpc_id = aws_vpc.office.id
  tags   = { Name = "Office-${var.office_name}-Private-RT" }
}

resource "aws_route" "office_private_to_aws" {
  route_table_id         = aws_route_table.office_private.id
  destination_cidr_block = "10.0.0.0/8"
  network_interface_id   = aws_instance.cgw.primary_network_interface_id
}

resource "aws_route_table_association" "office_private" {
  subnet_id      = aws_subnet.office_private.id
  route_table_id = aws_route_table.office_private.id
}


# ---------------------------------------------------------------------------
# Security Groups for office EC2
# ---------------------------------------------------------------------------
resource "aws_security_group" "cgw" {
  name        = "${var.project_name}-sg-cgw-${var.office_name}"
  description = "CGW simulator EC2, allow IPsec from AWS VPN endpoints"
  vpc_id      = aws_vpc.office.id

  ingress {
    description = "IKE from anywhere"
    from_port   = 500
    to_port     = 500
    protocol    = "udp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  ingress {
    description = "IPsec NAT-T from anywhere"
    from_port   = 4500
    to_port     = 4500
    protocol    = "udp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  ingress {
    description = "ESP from anywhere"
    from_port   = -1
    to_port     = -1
    protocol    = "50"
    cidr_blocks = ["0.0.0.0/0"]
  }

  ingress {
    description = "Traffic from office private subnet (forwarded to AWS)"
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = [aws_vpc.office.cidr_block]
  }

  ingress {
    description = "ICMP from AWS VPCs (for ping testing)"
    from_port   = -1
    to_port     = -1
    protocol    = "icmp"
    cidr_blocks = ["10.0.0.0/8"]
  }

  egress {
    description = "All outbound"
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = { Name = "${var.project_name}-sg-cgw-${var.office_name}" }
}

resource "aws_security_group" "workstation" {
  name        = "${var.project_name}-sg-workstation-${var.office_name}"
  description = "Office workstation EC2 - SSM access, ping AWS"
  vpc_id      = aws_vpc.office.id

  egress {
    description = "All outbound"
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  ingress {
    description = "ICMP from AWS VPCs (return traffic)"
    from_port   = -1
    to_port     = -1
    protocol    = "icmp"
    cidr_blocks = ["10.0.0.0/8"]
  }

  tags = { Name = "${var.project_name}-sg-workstation-${var.office_name}" }
}


# ---------------------------------------------------------------------------
# Pre-allocated ENI + EIP. EIP attaches to ENI BEFORE instance launches,
# so the instance has a stable public IP from first boot (no race with EIP).
# ---------------------------------------------------------------------------
resource "aws_network_interface" "cgw" {
  subnet_id         = aws_subnet.office_public.id
  security_groups   = [aws_security_group.cgw.id]
  source_dest_check = false
  tags              = { Name = "${var.project_name}-CGW-ENI-${var.office_name}" }
}

resource "aws_eip" "cgw" {
  domain = "vpc"
  tags   = { Name = "${var.project_name}-CGW-EIP-${var.office_name}" }
}

# Renamed from aws_eip_association.cgw to break cycle when migrating from
# instance_id-attached EIP to network_interface_id-attached EIP. The old
# resource is destroyed standalone; this new resource has its own address.
resource "aws_eip_association" "cgw_eni" {
  network_interface_id = aws_network_interface.cgw.id
  allocation_id        = aws_eip.cgw.id
}


# ---------------------------------------------------------------------------
# AWS Customer Gateway and S2S VPN connection
# ---------------------------------------------------------------------------
resource "aws_customer_gateway" "office" {
  bgp_asn    = 65000
  ip_address = aws_eip.cgw.public_ip
  type       = "ipsec.1"
  tags       = { Name = "${var.project_name}-CGW-${var.office_name}" }
}

resource "aws_vpn_connection" "office" {
  customer_gateway_id = aws_customer_gateway.office.id
  transit_gateway_id  = var.transit_gateway_id
  type                = "ipsec.1"
  static_routes_only  = true
  tags                = { Name = "${var.project_name}-VPN-${var.office_name}" }
}

# TGW route: send traffic for office CIDR via the VPN attachment.
# Note: aws_vpn_connection_route is ONLY for VGW-attached VPNs.
# For TGW-attached VPNs, routing is fully managed via TGW route tables.
resource "aws_ec2_transit_gateway_route" "office" {
  destination_cidr_block         = var.office_cidr
  transit_gateway_attachment_id  = aws_vpn_connection.office.transit_gateway_attachment_id
  transit_gateway_route_table_id = var.tgw_route_table_id
}


# ---------------------------------------------------------------------------
# IAM role for SSM (both CGW and workstation EC2 need it)
# ---------------------------------------------------------------------------
resource "aws_iam_role" "ec2_ssm" {
  name = "${var.project_name}-office-${var.office_name}-ssm-role"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Effect    = "Allow"
      Principal = { Service = "ec2.amazonaws.com" }
      Action    = "sts:AssumeRole"
    }]
  })
}

resource "aws_iam_role_policy_attachment" "ssm_core" {
  role       = aws_iam_role.ec2_ssm.name
  policy_arn = "arn:aws:iam::aws:policy/AmazonSSMManagedInstanceCore"
}

resource "aws_iam_instance_profile" "ec2_ssm" {
  name = "${var.project_name}-office-${var.office_name}-ssm-profile"
  role = aws_iam_role.ec2_ssm.name
}


# ---------------------------------------------------------------------------
# CGW EC2 (strongSwan auto-configured via user_data)
# ---------------------------------------------------------------------------
resource "aws_instance" "cgw" {
  ami                  = data.aws_ami.al2023.id
  instance_type        = var.cgw_instance_type
  iam_instance_profile = aws_iam_instance_profile.ec2_ssm.name

  # Use pre-allocated ENI that already has EIP attached.
  # subnet_id, vpc_security_group_ids, associate_public_ip_address, source_dest_check
  # all live on the ENI now and cannot be set on the instance.
  network_interface {
    network_interface_id = aws_network_interface.cgw.id
    device_index         = 0
  }

  user_data = templatefile("${path.module}/templates/strongswan_userdata.sh.tpl", {
    cgw_eip                    = aws_eip.cgw.public_ip
    office_cidr                = var.office_cidr
    aws_internal_cidr          = "10.0.0.0/8"
    tunnel1_address            = aws_vpn_connection.office.tunnel1_address
    tunnel1_preshared_key      = aws_vpn_connection.office.tunnel1_preshared_key
    tunnel1_cgw_inside_address = aws_vpn_connection.office.tunnel1_cgw_inside_address
    tunnel1_vgw_inside_address = aws_vpn_connection.office.tunnel1_vgw_inside_address
  })
  user_data_replace_on_change = true

  metadata_options {
    http_endpoint = "enabled"
    http_tokens   = "required"
  }

  # Ensure the stable EIP is attached and the SSM policy is usable before first boot.
  depends_on = [
    aws_eip_association.cgw_eni,
    aws_iam_role_policy_attachment.ssm_core
  ]

  tags = { Name = "${var.project_name}-CGW-EC2-${var.office_name}" }
}


# ---------------------------------------------------------------------------
# Workstation EC2 - simulates an employee in the office
# Used to ping AWS resources through the VPN tunnel
# ---------------------------------------------------------------------------
resource "aws_instance" "workstation" {
  ami                    = data.aws_ami.al2023.id
  instance_type          = "t3.micro"
  subnet_id              = aws_subnet.office_private.id
  vpc_security_group_ids = [aws_security_group.workstation.id]
  iam_instance_profile   = aws_iam_instance_profile.ec2_ssm.name

  metadata_options {
    http_endpoint = "enabled"
    http_tokens   = "required"
  }

  tags = { Name = "${var.project_name}-Workstation-${var.office_name}" }
}
