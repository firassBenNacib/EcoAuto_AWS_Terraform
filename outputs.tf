output "backend_cloudfront_url" {
  value = module.cloudfront_backend.backend_url
}

output "frontend_cloudfront_url" {
  value = module.cloudfront_frontend.frontend_url
}


output "rds_endpoint" {
  value = module.rds.endpoint
}

output "ec2_asg_name" {
  value = module.ec2.asg_name
}
