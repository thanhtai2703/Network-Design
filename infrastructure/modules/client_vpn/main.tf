# =============================================================================
# Client VPN Endpoint with mutual cert authentication
# =============================================================================
# Generates a self-signed CA in Terraform, uses it to sign:
#   - 1 server cert (used by Client VPN endpoint)
#   - 1 admin client cert (embedded in .ovpn for the operator's laptop)
# Both certs are uploaded to ACM. The .ovpn file is rendered to local disk.
# =============================================================================


# ---------------------------------------------------------------------------
# 1. Certificate Authority (self-signed root)
# ---------------------------------------------------------------------------
resource "tls_private_key" "ca" {
  algorithm = "RSA"
  rsa_bits  = 2048
}

resource "tls_self_signed_cert" "ca" {
  private_key_pem = tls_private_key.ca.private_key_pem

  subject {
    common_name  = "${var.project_name} ClientVPN CA"
    organization = var.project_name
  }

  validity_period_hours = 87600 # 10 years
  is_ca_certificate     = true

  allowed_uses = [
    "cert_signing",
    "crl_signing",
    "key_encipherment",
    "digital_signature",
  ]
}


# ---------------------------------------------------------------------------
# 2. Server certificate (signed by CA)
# ---------------------------------------------------------------------------
resource "tls_private_key" "server" {
  algorithm = "RSA"
  rsa_bits  = 2048
}

resource "tls_cert_request" "server" {
  private_key_pem = tls_private_key.server.private_key_pem
  subject {
    common_name  = "vpn.${var.project_name}.local"
    organization = var.project_name
  }
}

resource "tls_locally_signed_cert" "server" {
  cert_request_pem   = tls_cert_request.server.cert_request_pem
  ca_private_key_pem = tls_private_key.ca.private_key_pem
  ca_cert_pem        = tls_self_signed_cert.ca.cert_pem

  validity_period_hours = 17520 # 2 years
  allowed_uses = [
    "key_encipherment",
    "digital_signature",
    "server_auth",
  ]
}


# ---------------------------------------------------------------------------
# 3. Admin client certificate (signed by CA, used in .ovpn)
# ---------------------------------------------------------------------------
resource "tls_private_key" "client_admin" {
  algorithm = "RSA"
  rsa_bits  = 2048
}

resource "tls_cert_request" "client_admin" {
  private_key_pem = tls_private_key.client_admin.private_key_pem
  subject {
    common_name  = "admin@${var.project_name}.local"
    organization = var.project_name
  }
}

resource "tls_locally_signed_cert" "client_admin" {
  cert_request_pem   = tls_cert_request.client_admin.cert_request_pem
  ca_private_key_pem = tls_private_key.ca.private_key_pem
  ca_cert_pem        = tls_self_signed_cert.ca.cert_pem

  validity_period_hours = 17520
  allowed_uses = [
    "key_encipherment",
    "digital_signature",
    "client_auth",
  ]
}


# ---------------------------------------------------------------------------
# 4. ACM uploads
# ---------------------------------------------------------------------------
resource "aws_acm_certificate" "server" {
  private_key       = tls_private_key.server.private_key_pem
  certificate_body  = tls_locally_signed_cert.server.cert_pem
  certificate_chain = tls_self_signed_cert.ca.cert_pem
  tags              = { Name = "${var.project_name}-ClientVPN-Server" }
}


# ---------------------------------------------------------------------------
# 5. Client VPN Endpoint
# ---------------------------------------------------------------------------
resource "aws_ec2_client_vpn_endpoint" "main" {
  description            = "${var.project_name} remote employee VPN"
  server_certificate_arn = aws_acm_certificate.server.arn
  client_cidr_block      = var.client_cidr_block

  authentication_options {
    type                       = "certificate-authentication"
    root_certificate_chain_arn = aws_acm_certificate.server.arn
  }

  connection_log_options {
    enabled = false
  }

  vpc_id             = var.vpc_id
  security_group_ids = [var.security_group_id]
  split_tunnel       = true # only route 10/8 through VPN, regular Internet stays local

  dns_servers = ["10.1.0.2"] # VPC Core resolver - so clients can resolve internal DNS

  tags = { Name = "${var.project_name}-ClientVPN" }
}


# ---------------------------------------------------------------------------
# 6. Network association (one subnet = $0.10/h. Add more for HA, costs more)
#    Use count (not for_each) because subnet IDs are unknown until VPC is applied.
# ---------------------------------------------------------------------------
resource "aws_ec2_client_vpn_network_association" "subnets" {
  count                  = length(var.associated_subnet_ids)
  client_vpn_endpoint_id = aws_ec2_client_vpn_endpoint.main.id
  subnet_id              = var.associated_subnet_ids[count.index]
}


# ---------------------------------------------------------------------------
# 7. Authorization - allow access to internal AWS network
# ---------------------------------------------------------------------------
resource "aws_ec2_client_vpn_authorization_rule" "internal" {
  client_vpn_endpoint_id = aws_ec2_client_vpn_endpoint.main.id
  target_network_cidr    = "10.0.0.0/8"
  authorize_all_groups   = true
  description            = "Allow access to all internal networks"
}


# ---------------------------------------------------------------------------
# 8. Routes - so client traffic for other VPCs (via TGW) finds a path.
#    AWS auto-creates a route for the associated VPC's CIDR; do NOT add it again.
#    Routes here must not overlap with client_cidr_block.
#    One route per (subnet, cidr) pair. Each route sends packets out via that
#    subnet, whose VPC RT then forwards to TGW.
# ---------------------------------------------------------------------------
locals {
  route_pairs = flatten([
    for subnet_id in var.associated_subnet_ids : [
      for cidr in var.cross_vpc_cidrs : {
        subnet_id = subnet_id
        cidr      = cidr
      }
    ]
  ])
}

resource "aws_ec2_client_vpn_route" "cross_vpc" {
  count = length(local.route_pairs)

  client_vpn_endpoint_id = aws_ec2_client_vpn_endpoint.main.id
  destination_cidr_block = local.route_pairs[count.index].cidr
  target_vpc_subnet_id   = local.route_pairs[count.index].subnet_id

  depends_on = [aws_ec2_client_vpn_network_association.subnets]
}


# ---------------------------------------------------------------------------
# 9. Render .ovpn config file to local disk (operator's laptop)
# ---------------------------------------------------------------------------
resource "local_sensitive_file" "client_ovpn" {
  filename = "${path.root}/output/${var.project_name}-admin.ovpn"
  content = templatefile("${path.module}/templates/client.ovpn.tftpl", {
    endpoint_dns = aws_ec2_client_vpn_endpoint.main.dns_name
    ca_cert      = tls_self_signed_cert.ca.cert_pem
    client_cert  = tls_locally_signed_cert.client_admin.cert_pem
    client_key   = tls_private_key.client_admin.private_key_pem
  })
  file_permission = "0600"
}
