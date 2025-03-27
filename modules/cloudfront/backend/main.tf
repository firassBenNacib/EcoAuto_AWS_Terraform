resource "aws_cloudfront_distribution" "backend" {
  origin {
    domain_name = var.backend_domain_name
    origin_id   = "backend-origin"

    custom_origin_config {
      http_port              = 8080
      origin_protocol_policy = "http-only"
      https_port             = 443
      origin_ssl_protocols   = ["TLSv1.2"]
    }
  }

  enabled         = true
  is_ipv6_enabled = true
  comment         = "CloudFront Distribution for Backend API"
  aliases         = [var.backend_alias]

  default_cache_behavior {
    target_origin_id         = "backend-origin"
    viewer_protocol_policy   = "redirect-to-https"
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
    Name = "cloudfront-backend"
  }

}
