# IAM Identity Center (SSO) - Manual Setup

IAM Identity Center (formerly AWS SSO) is **account-wide** and requires
AWS Organizations to be enabled. The setup is one-time and must be done in the
AWS Console, after which Terraform resources (groups, users, permission sets,
assignments) can be added in the future.

This module is intentionally a stub. Follow these steps in the AWS Console.

## Prerequisites
- AWS account is a management account in an Organization
  (or run `aws organizations create-organization --feature-set ALL`)

## One-time setup

1. Open https://console.aws.amazon.com/singlesignon
2. Click **Enable IAM Identity Center**
3. Choose **Identity source**: Identity Center directory (built-in)
4. Note the **AWS access portal URL** (e.g. `https://d-xxxxx.awsapps.com/start`)

## Create user + group

1. **Users** → Add user → fill in admin@vietmove.demo, etc.
2. **Groups** → Create group `VietMove-Admins` → add the user
3. Confirm activation email and set password

## Permission set (gives the user permissions inside the AWS account)

1. **Multi-account permissions** → Permission sets → Create
2. Predefined permission set: `AdministratorAccess` (for demo) or
   create a custom one allowing only `AmazonEC2ReadOnlyAccess`, `AmazonSSMManagedInstanceCore`, etc.

## Account assignment

1. **AWS accounts** → select your account
2. **Assign users or groups** → choose `VietMove-Admins` group
3. **Permission set** → choose the one created above
4. Submit

After ~1 minute the user can log into the AWS access portal and assume the role.

## Wire Client VPN to SSO (SAML federation) - optional

Client VPN does NOT use SSO directly. It accepts SAML 2.0. To wire it up:

1. In IAM Identity Center: **Applications** → Add application → Catalog → "AWS Client VPN"
2. Configure the application:
   - **ACS URL**: `https://self-service.clientvpn.amazonaws.com/api/auth/sso/saml`
   - **Audience**: `urn:amazon:webservices:clientvpn`
3. Assign the `VietMove-Admins` group to this application
4. Download the SAML metadata XML (`metadata.xml`)
5. In IAM (separate from Identity Center): **Identity providers** → Add SAML provider
   - Name: `IdentityCenter-ClientVPN`
   - Upload the `metadata.xml`
   - Note the SAML provider ARN
6. Recreate the Client VPN endpoint with:
   ```hcl
   authentication_options {
     type              = "federated-authentication"
     saml_provider_arn = "<the ARN from step 5>"
   }
   ```
7. Users now connect to Client VPN by opening AWS VPN Client → "Use SSO" →
   browser redirects to the SSO portal → authenticates → returns SAML assertion → connected

## Useful AWS CLI commands

```bash
# List SSO instances
aws sso-admin list-instances

# List permission sets
aws sso-admin list-permission-sets --instance-arn arn:aws:sso:::instance/ssoins-xxxx

# List users in Identity Store
aws identitystore list-users --identity-store-id d-xxxxxxxxxx
```
