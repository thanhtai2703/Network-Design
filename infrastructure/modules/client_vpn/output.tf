output "endpoint_id" {
  value = aws_ec2_client_vpn_endpoint.main.id
}

output "endpoint_dns" {
  description = "Hostname clients connect to (prefix with a random subdomain in the .ovpn)"
  value       = aws_ec2_client_vpn_endpoint.main.dns_name
}

output "ovpn_file_path" {
  description = "Path to the generated .ovpn file - import into AWS VPN Client or OpenVPN"
  value       = local_sensitive_file.client_ovpn.filename
}

output "ca_cert_pem" {
  description = "CA cert (used to verify additional client certs you generate later)"
  value       = tls_self_signed_cert.ca.cert_pem
  sensitive   = true
}

output "ca_private_key_pem" {
  description = "CA private key (keep secret. Use to sign more client certs.)"
  value       = tls_private_key.ca.private_key_pem
  sensitive   = true
}
