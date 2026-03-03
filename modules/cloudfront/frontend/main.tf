locals {
  workspace = terraform.workspace
  is_prod   = local.workspace == "prod"

  frontend_aliases_final = var.enable_workspace_suffix && var.workspace_domain != "" ? (
    local.is_prod ? [var.workspace_domain, "www.${var.workspace_domain}"] : ["${local.workspace}.${var.workspace_domain}", "www.${local.workspace}.${var.workspace_domain}"]
  ) : var.frontend_aliases

  environment_tag = var.enable_workspace_suffix ? upper(local.workspace) : "DEFAULT"
  oac_name        = var.enable_workspace_suffix ? "frontend-oac-${local.workspace}" : "frontend-oac"
}

resource "aws_cloudfront_origin_access_control" "frontend_oac" {
  name                              = local.oac_name
  description                       = "Origin Access Control for CloudFront"
  origin_access_control_origin_type = "s3"
  signing_behavior                  = "always"
  signing_protocol                  = "sigv4"
}

#tfsec:ignore:aws-cloudfront-enable-logging Access logging is controlled by enable_access_logs for cost-optimized deployments.
resource "aws_cloudfront_distribution" "frontend" {
  origin {
    domain_name              = var.frontend_bucket_domain
    origin_id                = "S3-frontend-origin"
    origin_access_control_id = aws_cloudfront_origin_access_control.frontend_oac.id
  }

  enabled         = true
  is_ipv6_enabled = true
  price_class     = var.price_class
  web_acl_id      = var.web_acl_id
  comment         = var.enable_workspace_suffix ? "CloudFront Distribution for Frontend (${local.environment_tag})" : "CloudFront Distribution for Frontend"
  aliases         = local.frontend_aliases_final

  dynamic "logging_config" {
    for_each = var.enable_access_logs ? [1] : []
    content {
      bucket          = var.access_logs_bucket
      include_cookies = false
      prefix          = var.access_logs_prefix
    }
  }

  default_cache_behavior {
    target_origin_id           = "S3-frontend-origin"
    viewer_protocol_policy     = var.viewer_protocol_policy
    allowed_methods            = ["GET", "HEAD", "OPTIONS"]
    cached_methods             = ["GET", "HEAD"]
    cache_policy_id            = var.cache_policy_id
    response_headers_policy_id = var.response_headers_policy_id
    compress                   = true
  }

  viewer_certificate {
    acm_certificate_arn      = var.frontend_cert_arn
    ssl_support_method       = "sni-only"
    minimum_protocol_version = "TLSv1.2_2021"
  }

  restrictions {
    geo_restriction {
      restriction_type = "none"
    }
  }

  custom_error_response {
    error_code            = 403
    response_page_path    = "/index.html"
    response_code         = 200
    error_caching_min_ttl = 10
  }

  custom_error_response {
    error_code            = 404
    response_page_path    = "/index.html"
    response_code         = 200
    error_caching_min_ttl = 10
  }

  tags = {
    Name        = var.enable_workspace_suffix ? "cloudfront-frontend-${local.workspace}" : "cloudfront-frontend"
    Environment = local.environment_tag
  }
}
