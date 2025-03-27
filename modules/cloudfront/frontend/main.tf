resource "aws_cloudfront_origin_access_control" "frontend_oac" {
  name                              = "frontend-oac"
  description                       = "Origin Access Control for CloudFront"
  origin_access_control_origin_type = "s3"
  signing_behavior                  = "always"
  signing_protocol                  = "sigv4"
}

resource "aws_cloudfront_distribution" "frontend" {
  origin {
    domain_name              = var.frontend_bucket_domain
    origin_id                = "S3-frontend-origin"
    origin_access_control_id = aws_cloudfront_origin_access_control.frontend_oac.id
  }

  enabled         = true
  is_ipv6_enabled = true
  comment         = "CloudFront Distribution for Frontend"
  aliases         = var.frontend_aliases

  default_cache_behavior {
    target_origin_id           = "S3-frontend-origin"
    viewer_protocol_policy     = "https-only"
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
    Name = "cloudfront-frontend"
  }

}
