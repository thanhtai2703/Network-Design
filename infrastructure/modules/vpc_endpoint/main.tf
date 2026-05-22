# =============================================================================
# VPC Endpoints - reusable module
# =============================================================================
# Supports:
# - Gateway endpoints (free): S3, DynamoDB
#     attach to route_table_ids; AWS adds prefix list route automatically
# - Interface endpoints (paid, ~$0.01/h/AZ): SSM, ECR, CloudWatch, etc.
#     create ENI in each subnet_id; access via private DNS
# =============================================================================

data "aws_region" "current" {}


# Gateway endpoints (S3 / DynamoDB only)
resource "aws_vpc_endpoint" "gateway" {
  for_each = toset(var.gateway_services)

  vpc_id            = var.vpc_id
  service_name      = "com.amazonaws.${data.aws_region.current.region}.${each.value}"
  vpc_endpoint_type = "Gateway"
  route_table_ids   = var.route_table_ids

  tags = { Name = "${var.name_prefix}-vpce-${each.value}" }
}


# Interface endpoints
resource "aws_vpc_endpoint" "interface" {
  for_each = toset(var.interface_services)

  vpc_id              = var.vpc_id
  service_name        = "com.amazonaws.${data.aws_region.current.region}.${each.value}"
  vpc_endpoint_type   = "Interface"
  subnet_ids          = var.subnet_ids
  security_group_ids  = [var.security_group_id]
  private_dns_enabled = true

  tags = { Name = "${var.name_prefix}-vpce-${replace(each.value, ".", "-")}" }
}
