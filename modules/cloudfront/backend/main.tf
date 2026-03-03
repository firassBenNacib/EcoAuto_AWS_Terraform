locals {
  workspace       = terraform.workspace
  environment_tag = var.enable_workspace_suffix ? upper(local.workspace) : "DEFAULT"
}

#tfsec:ignore:aws-cloudfront-enable-logging Access logging is controlled by enable_access_logs for cost-optimized deployments.
resource "aws_cloudfront_distribution" "backend_dynamic" {
  count = var.ignore_dynamic_origin_drift ? 1 : 0

  origin {
    domain_name = var.backend_domain_name
    origin_id   = "backend-origin"

    custom_origin_config {
      http_port              = var.app_port
      origin_protocol_policy = var.origin_protocol_policy
      https_port             = var.app_port
      origin_ssl_protocols   = ["TLSv1.2"]
    }

    dynamic "custom_header" {
      for_each = var.enable_origin_auth_header && var.origin_auth_header_value != "" ? [1] : []
      content {
        name  = var.origin_auth_header_name
        value = var.origin_auth_header_value
      }
    }

    dynamic "custom_header" {
      for_each = var.enable_origin_auth_header && var.origin_auth_previous_header_value != "" ? [1] : []
      content {
        name  = var.origin_auth_previous_header_name
        value = var.origin_auth_previous_header_value
      }
    }
  }

  enabled         = true
  is_ipv6_enabled = true
  price_class     = var.price_class
  web_acl_id      = var.web_acl_id
  comment         = var.enable_workspace_suffix ? "CloudFront Distribution for Backend API (${local.environment_tag})" : "CloudFront Distribution for Backend API"
  aliases         = [var.backend_alias]

  dynamic "logging_config" {
    for_each = var.enable_access_logs ? [1] : []
    content {
      bucket          = var.access_logs_bucket
      include_cookies = false
      prefix          = var.access_logs_prefix
    }
  }

  default_cache_behavior {
    target_origin_id         = "backend-origin"
    viewer_protocol_policy   = var.viewer_protocol_policy
    allowed_methods          = ["GET", "HEAD", "OPTIONS", "PUT", "POST", "PATCH", "DELETE"]
    cached_methods           = ["GET", "HEAD"]
    cache_policy_id          = var.cache_policy_id
    compress                 = true
    origin_request_policy_id = var.origin_request_policy_id

    lambda_function_association {
      event_type   = "origin-request"
      lambda_arn   = var.lambda_edge_arn
      include_body = false
    }
  }

  viewer_certificate {
    acm_certificate_arn      = var.backend_cert_arn
    ssl_support_method       = "sni-only"
    minimum_protocol_version = "TLSv1.2_2021"
  }

  restrictions {
    geo_restriction {
      restriction_type = "whitelist"
      locations        = var.geo_locations
    }
  }

  lifecycle {
    ignore_changes = [
      origin,
      default_cache_behavior[0].target_origin_id
    ]
  }

  tags = {
    Name        = var.enable_workspace_suffix ? "cloudfront-backend-${local.workspace}" : "cloudfront-backend"
    Environment = local.environment_tag
  }
}

#tfsec:ignore:aws-cloudfront-enable-logging Access logging is controlled by enable_access_logs for cost-optimized deployments.
resource "aws_cloudfront_distribution" "backend_strict" {
  count = var.ignore_dynamic_origin_drift ? 0 : 1

  origin {
    domain_name = var.backend_domain_name
    origin_id   = "backend-origin"

    custom_origin_config {
      http_port              = var.app_port
      origin_protocol_policy = var.origin_protocol_policy
      https_port             = var.app_port
      origin_ssl_protocols   = ["TLSv1.2"]
    }

    dynamic "custom_header" {
      for_each = var.enable_origin_auth_header && var.origin_auth_header_value != "" ? [1] : []
      content {
        name  = var.origin_auth_header_name
        value = var.origin_auth_header_value
      }
    }

    dynamic "custom_header" {
      for_each = var.enable_origin_auth_header && var.origin_auth_previous_header_value != "" ? [1] : []
      content {
        name  = var.origin_auth_previous_header_name
        value = var.origin_auth_previous_header_value
      }
    }
  }

  enabled         = true
  is_ipv6_enabled = true
  price_class     = var.price_class
  web_acl_id      = var.web_acl_id
  comment         = var.enable_workspace_suffix ? "CloudFront Distribution for Backend API (${local.environment_tag})" : "CloudFront Distribution for Backend API"
  aliases         = [var.backend_alias]

  dynamic "logging_config" {
    for_each = var.enable_access_logs ? [1] : []
    content {
      bucket          = var.access_logs_bucket
      include_cookies = false
      prefix          = var.access_logs_prefix
    }
  }

  default_cache_behavior {
    target_origin_id         = "backend-origin"
    viewer_protocol_policy   = var.viewer_protocol_policy
    allowed_methods          = ["GET", "HEAD", "OPTIONS", "PUT", "POST", "PATCH", "DELETE"]
    cached_methods           = ["GET", "HEAD"]
    cache_policy_id          = var.cache_policy_id
    compress                 = true
    origin_request_policy_id = var.origin_request_policy_id

    lambda_function_association {
      event_type   = "origin-request"
      lambda_arn   = var.lambda_edge_arn
      include_body = false
    }
  }

  viewer_certificate {
    acm_certificate_arn      = var.backend_cert_arn
    ssl_support_method       = "sni-only"
    minimum_protocol_version = "TLSv1.2_2021"
  }

  restrictions {
    geo_restriction {
      restriction_type = "whitelist"
      locations        = var.geo_locations
    }
  }

  tags = {
    Name        = var.enable_workspace_suffix ? "cloudfront-backend-${local.workspace}" : "cloudfront-backend"
    Environment = local.environment_tag
  }
}
