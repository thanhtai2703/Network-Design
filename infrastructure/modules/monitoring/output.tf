output "s3_logs_bucket" {
  value = aws_s3_bucket.logs.id
}

output "s3_logs_bucket_arn" {
  value = aws_s3_bucket.logs.arn
}

output "cloudtrail_name" {
  value = aws_cloudtrail.main.name
}

output "sns_topic_arn" {
  value = aws_sns_topic.alarms.arn
}

output "dashboard_url" {
  description = "Open this in browser to see the CloudWatch dashboard"
  value       = "https://${var.aws_region}.console.aws.amazon.com/cloudwatch/home?region=${var.aws_region}#dashboards:name=${aws_cloudwatch_dashboard.main.dashboard_name}"
}
