output "gateway_endpoint_ids" {
  description = "Map of Gateway endpoint service name to endpoint ID"
  value       = { for k, v in aws_vpc_endpoint.gateway : k => v.id }
}

output "interface_endpoint_ids" {
  description = "Map of Interface endpoint service name to endpoint ID"
  value       = { for k, v in aws_vpc_endpoint.interface : k => v.id }
}

output "interface_endpoint_dns_names" {
  description = "Map of Interface endpoint service name to private DNS name"
  value       = { for k, v in aws_vpc_endpoint.interface : k => v.dns_entry[0].dns_name }
}
