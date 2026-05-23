# =============================================================================
# 4D - CloudFront distribution with WAF, fronting the ALB
# =============================================================================

terraform {
  required_providers {
    aws = {
      source = "hashicorp/aws"
      # Explicit configuration_aliases so this module can use both default
      # AWS provider AND the us-east-1 alias (required for CLOUDFRONT-scope WAF).
      configuration_aliases = [aws.us_east_1]
    }
  }
}

resource "aws_cloudfront_distribution" "main" {
  enabled         = true
  is_ipv6_enabled = true
  comment         = "${var.project_name} TMS CDN"
  price_class     = "PriceClass_200" # NA + EU + Asia (skips SA/AU - cheaper)
  web_acl_id      = aws_wafv2_web_acl.cloudfront.arn

  origin {
    domain_name = var.alb_dns_name
    origin_id   = "alb-origin"

    custom_origin_config {
      http_port              = 80
      https_port             = 443
      origin_protocol_policy = "http-only" # ALB has no ACM cert (no domain) -> HTTP only
      origin_ssl_protocols   = ["TLSv1.2"]
    }
  }

  default_cache_behavior {
    target_origin_id       = "alb-origin"
    viewer_protocol_policy = "redirect-to-https" # Force HTTPS at the edge
    allowed_methods        = ["GET", "HEAD", "OPTIONS"]
    cached_methods         = ["GET", "HEAD"]
    compress               = true

    # AWS managed cache policy "CachingDisabled" — for a dynamic app like TMS,
    # we don't want CloudFront caching HTML. Switch to a caching policy later
    # for static assets.
    cache_policy_id = "4135ea2d-6df8-44a3-9df3-4b5a84be39ad"

    # AWS managed origin request policy "AllViewer" — forward all headers,
    # query strings, cookies to ALB (needed for the nginx Host header etc).
    origin_request_policy_id = "216adef6-5c7f-47e4-b989-5492eafa07d3"
  }

  restrictions {
    geo_restriction {
      restriction_type = "none"
    }
  }

  viewer_certificate {
    # Default CloudFront cert (*.cloudfront.net). No custom domain.
    cloudfront_default_certificate = true
  }

  tags = { Name = "${var.project_name}-cdn" }
}
