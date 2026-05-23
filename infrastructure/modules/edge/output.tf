output "cloudfront_domain" {
  description = "CloudFront default domain (e.g. dxxxxx.cloudfront.net)"
  value       = aws_cloudfront_distribution.main.domain_name
}

output "cloudfront_url" {
  description = "Full HTTPS URL to test in browser"
  value       = "https://${aws_cloudfront_distribution.main.domain_name}"
}

output "cloudfront_distribution_id" {
  value = aws_cloudfront_distribution.main.id
}

output "waf_web_acl_id" {
  value = aws_wafv2_web_acl.cloudfront.id
}

output "waf_web_acl_arn" {
  value = aws_wafv2_web_acl.cloudfront.arn
}
