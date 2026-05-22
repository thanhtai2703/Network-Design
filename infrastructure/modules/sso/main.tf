# =============================================================================
# IAM Identity Center (SSO) - intentionally empty
# =============================================================================
# SSO setup is a one-time account-wide manual step.
# See README.md in this directory for the procedure.
#
# Future Terraform resources to add here once SSO is enabled and you know
# the instance ARN and identity store ID:
#
#   data "aws_ssoadmin_instances" "main" {}
#
#   resource "aws_identitystore_user" "admin" { ... }
#   resource "aws_identitystore_group" "admins" { ... }
#   resource "aws_identitystore_group_membership" "admin_in_admins" { ... }
#   resource "aws_ssoadmin_permission_set" "admin" { ... }
#   resource "aws_ssoadmin_managed_policy_attachment" "admin" { ... }
#   resource "aws_ssoadmin_account_assignment" "admin" { ... }
#
# This stub keeps the module path valid and CI-friendly.
# =============================================================================
