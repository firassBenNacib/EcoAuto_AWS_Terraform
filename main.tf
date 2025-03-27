data "aws_vpc" "default" {
  default = true
}

data "aws_subnets" "default" {
  filter {
    name   = "vpc-id"
    values = [data.aws_vpc.default.id]
  }
}

data "aws_caller_identity" "current" {}

module "iam" {
  source = "./modules/iam"
}

module "security_groups" {
  source = "./modules/security_groups"
  vpc_id = data.aws_vpc.default.id
}

module "s3" {
  source         = "./modules/s3"
  bucket_name    = "your-s3-bucket-name"
  cloudfront_arn = module.cloudfront_frontend.frontend_distribution_id
}

module "rds" {
  source          = "./modules/rds"
  username        = var.rds_username
  password        = var.rds_password
  kms_key_id      = var.kms_key_id
  db_name         = "your-db-name"
  rds_sg_id       = module.security_groups.rds_ec2_sg_id
  db_subnet_group = "your-db-subnet-group"
}

module "ec2" {
  source               = "./modules/ec2"
  ami_id               = var.ec2_ami_id
  instance_type        = var.instance_type
  key_name             = var.ec2_key_name
  rds_endpoint         = module.rds.endpoint
  security_group_ids   = concat([module.security_groups.ec2_rds_sg_id], module.security_groups.cloudfront_sg_ids)
  iam_instance_profile = module.iam.ec2_instance_profile_name
  subnet_ids           = data.aws_subnets.default.ids
}

module "cloudfront_backend" {
  source              = "./modules/cloudfront/backend"
  backend_domain_name = "your-backend-domain.com"
  backend_alias       = "api.your-domain.com"
  backend_cert_arn    = var.acm_cert_backend
  lambda_edge_arn     = module.lambda.lambda_edge_selector_arn
}

module "cloudfront_frontend" {
  source                 = "./modules/cloudfront/frontend"
  frontend_bucket_domain = module.s3.bucket_domain_name
  frontend_aliases       = ["your-domain.com", "www.your-domain.com"]
  frontend_cert_arn      = var.acm_cert_frontend
}

module "lambda" {
  source = "./modules/lambda"

  rds_instance_id              = "your-rds-instance-id"
  asg_name                     = module.ec2.asg_name
  security_group_ids           = module.security_groups.cloudfront_sg_ids
  lambda_sg_update_role_arn    = module.iam.lambda_sg_update_role_arn
  infra_update_lambda_role_arn = module.iam.infra_update_lambda_role_arn
  scheduler_lambda_role_arn    = module.iam.scheduler_lambda_role_arn
  lambda_edge_role_arn         = module.iam.lambda_edge_role_arn
  backend_cf_dist_id           = module.cloudfront_backend.backend_distribution_id
  route53_zone_id              = var.route53_zone_id
  frontend_cf_domain           = module.cloudfront_frontend.frontend_url
  backend_alias                = "api.your-domain.com"
  frontend_alias               = "your-domain.com"
}

module "cloudwatch_events" {
  source = "./modules/cloudwatch_events"

  start_lambda_arn        = module.lambda.start_lambda_arn
  stop_lambda_arn         = module.lambda.stop_lambda_arn
  infra_update_lambda_arn = module.lambda.update_infra_lambda_arn
  update_sgs_lambda_arn   = module.lambda.update_sgs_lambda_arn
}
