# =============================================================================
# 5D - Monitoring + Logging (CloudWatch, SNS, CloudTrail, S3)
# =============================================================================
# Resources:
#   - S3 bucket for CloudTrail logs (versioning off, lifecycle 90d)
#   - CloudTrail multi-region trail capturing management events
#   - SNS topic + email subscription for alarms
#   - 4 CloudWatch alarms (ECS task count, ALB 5xx, RDS CPU, RDS replica lag)
#   - CloudWatch dashboard with widgets per service
# =============================================================================

data "aws_caller_identity" "current" {}

resource "random_id" "bucket_suffix" {
  byte_length = 4
}


# -----------------------------------------------------------------------------
# 1. S3 bucket for CloudTrail
# -----------------------------------------------------------------------------
resource "aws_s3_bucket" "logs" {
  bucket        = "${lower(var.project_name)}-logs-${random_id.bucket_suffix.hex}"
  force_destroy = true # demo: allow terraform destroy

  tags = { Name = "${var.project_name}-logs" }
}

resource "aws_s3_bucket_public_access_block" "logs" {
  bucket                  = aws_s3_bucket.logs.id
  block_public_acls       = true
  block_public_policy     = true
  ignore_public_acls      = true
  restrict_public_buckets = true
}

resource "aws_s3_bucket_lifecycle_configuration" "logs" {
  bucket = aws_s3_bucket.logs.id

  rule {
    id     = "expire-old-logs"
    status = "Enabled"
    filter {}
    expiration {
      days = var.log_retention_days
    }
  }
}

data "aws_iam_policy_document" "cloudtrail_s3" {
  statement {
    sid       = "AWSCloudTrailAclCheck"
    actions   = ["s3:GetBucketAcl"]
    resources = [aws_s3_bucket.logs.arn]
    principals {
      type        = "Service"
      identifiers = ["cloudtrail.amazonaws.com"]
    }
  }
  statement {
    sid       = "AWSCloudTrailWrite"
    actions   = ["s3:PutObject"]
    resources = ["${aws_s3_bucket.logs.arn}/AWSLogs/${data.aws_caller_identity.current.account_id}/*"]
    principals {
      type        = "Service"
      identifiers = ["cloudtrail.amazonaws.com"]
    }
    condition {
      test     = "StringEquals"
      variable = "s3:x-amz-acl"
      values   = ["bucket-owner-full-control"]
    }
  }
}

resource "aws_s3_bucket_policy" "logs" {
  bucket = aws_s3_bucket.logs.id
  policy = data.aws_iam_policy_document.cloudtrail_s3.json
}


# -----------------------------------------------------------------------------
# 2. CloudTrail (multi-region, management events)
# -----------------------------------------------------------------------------
resource "aws_cloudtrail" "main" {
  name                          = "${var.project_name}-trail"
  s3_bucket_name                = aws_s3_bucket.logs.id
  include_global_service_events = true
  is_multi_region_trail         = true
  enable_log_file_validation    = true

  depends_on = [aws_s3_bucket_policy.logs]

  tags = { Name = "${var.project_name}-trail" }
}


# -----------------------------------------------------------------------------
# 3. SNS topic + email subscription
# -----------------------------------------------------------------------------
resource "aws_sns_topic" "alarms" {
  name = "${var.project_name}-alarms"
  tags = { Name = "${var.project_name}-alarms" }
}

resource "aws_sns_topic_subscription" "email" {
  topic_arn = aws_sns_topic.alarms.arn
  protocol  = "email"
  endpoint  = var.notification_email
  # NOTE: AWS sends a confirmation email - subscriber must click the link.
  # Until confirmed, alarms will not deliver to the inbox.
}


# -----------------------------------------------------------------------------
# 4. CloudWatch alarms
# -----------------------------------------------------------------------------

# Alarm 1: ECS running task count < 1 (Fargate down)
resource "aws_cloudwatch_metric_alarm" "ecs_task_count_low" {
  alarm_name          = "${var.project_name}-ECS-Tasks-Low"
  alarm_description   = "Fargate running tasks fell below 1 (service likely unhealthy)"
  comparison_operator = "LessThanThreshold"
  evaluation_periods  = 2
  metric_name         = "RunningTaskCount"
  namespace           = "ECS/ContainerInsights"
  period              = 60
  statistic           = "Average"
  threshold           = 1
  treat_missing_data  = "breaching"

  dimensions = {
    ClusterName = var.ecs_cluster_name
    ServiceName = var.ecs_service_name
  }

  alarm_actions = [aws_sns_topic.alarms.arn]
  ok_actions    = [aws_sns_topic.alarms.arn]
}

# Alarm 2: ALB 5xx count > 5 per minute
resource "aws_cloudwatch_metric_alarm" "alb_5xx" {
  alarm_name          = "${var.project_name}-ALB-5xx-High"
  alarm_description   = "ALB returned > 5 HTTP 5xx in the last minute"
  comparison_operator = "GreaterThanThreshold"
  evaluation_periods  = 1
  metric_name         = "HTTPCode_Target_5XX_Count"
  namespace           = "AWS/ApplicationELB"
  period              = 60
  statistic           = "Sum"
  threshold           = 5
  treat_missing_data  = "notBreaching"

  dimensions = {
    LoadBalancer = var.alb_arn_suffix
  }

  alarm_actions = [aws_sns_topic.alarms.arn]
}

# Alarm 3: Aurora primary cluster CPU > 80%
resource "aws_cloudwatch_metric_alarm" "rds_cpu_high" {
  alarm_name          = "${var.project_name}-Aurora-CPU-High"
  alarm_description   = "Aurora primary cluster CPU > 80% for 5 minutes"
  comparison_operator = "GreaterThanThreshold"
  evaluation_periods  = 5
  metric_name         = "CPUUtilization"
  namespace           = "AWS/RDS"
  period              = 60
  statistic           = "Average"
  threshold           = 80
  treat_missing_data  = "notBreaching"

  # Aurora metrics are keyed by DBClusterIdentifier (not DBInstanceIdentifier).
  dimensions = {
    DBClusterIdentifier = var.rds_instance_id
  }

  alarm_actions = [aws_sns_topic.alarms.arn]
}

# Alarm 4: Aurora Global Database cross-region replication lag > 60s
# AuroraGlobalDBReplicationLag is reported in MILLISECONDS on the secondary
# cluster, so the 60s threshold is 60000 ms.
resource "aws_cloudwatch_metric_alarm" "rds_dr_lag" {
  alarm_name          = "${var.project_name}-Aurora-DR-Replication-Lag-High"
  alarm_description   = "Aurora Global DB cross-region replication lag > 60s"
  comparison_operator = "GreaterThanThreshold"
  evaluation_periods  = 3
  metric_name         = "AuroraGlobalDBReplicationLag"
  namespace           = "AWS/RDS"
  period              = 60
  statistic           = "Average"
  threshold           = 60000
  treat_missing_data  = "notBreaching"

  dimensions = {
    DBClusterIdentifier = var.rds_dr_instance_id
  }

  alarm_actions = [aws_sns_topic.alarms.arn]
}


# -----------------------------------------------------------------------------
# 5. CloudWatch dashboard
# -----------------------------------------------------------------------------
resource "aws_cloudwatch_dashboard" "main" {
  dashboard_name = "${var.project_name}-Overview"

  dashboard_body = jsonencode({
    widgets = [
      {
        type   = "metric"
        x      = 0
        y      = 0
        width  = 12
        height = 6
        properties = {
          title  = "ALB - Request count + 5xx"
          region = var.aws_region
          view   = "timeSeries"
          stat   = "Sum"
          period = 60
          metrics = var.alb_arn_suffix != "" ? [
            ["AWS/ApplicationELB", "RequestCount", "LoadBalancer", var.alb_arn_suffix],
            [".", "HTTPCode_Target_5XX_Count", ".", "."],
            [".", "HTTPCode_Target_2XX_Count", ".", "."],
          ] : []
        }
      },
      {
        type   = "metric"
        x      = 12
        y      = 0
        width  = 12
        height = 6
        properties = {
          title  = "ECS - Running task count"
          region = var.aws_region
          view   = "timeSeries"
          stat   = "Average"
          period = 60
          metrics = var.ecs_cluster_name != "" ? [
            ["ECS/ContainerInsights", "RunningTaskCount", "ClusterName", var.ecs_cluster_name, "ServiceName", var.ecs_service_name],
          ] : []
        }
      },
      {
        type   = "metric"
        x      = 0
        y      = 6
        width  = 12
        height = 6
        properties = {
          title  = "Aurora Primary - CPU + Connections"
          region = var.aws_region
          view   = "timeSeries"
          stat   = "Average"
          period = 60
          metrics = var.rds_instance_id != "" ? [
            ["AWS/RDS", "CPUUtilization", "DBClusterIdentifier", var.rds_instance_id],
            [".", "DatabaseConnections", ".", "."],
          ] : []
        }
      },
      {
        type   = "metric"
        x      = 12
        y      = 6
        width  = 12
        height = 6
        properties = {
          title  = "Aurora DR - Global replication lag (ms)"
          region = "ap-southeast-2"
          view   = "timeSeries"
          stat   = "Average"
          period = 60
          metrics = var.rds_dr_instance_id != "" ? [
            ["AWS/RDS", "AuroraGlobalDBReplicationLag", "DBClusterIdentifier", var.rds_dr_instance_id],
          ] : []
        }
      },
    ]
  })
}
