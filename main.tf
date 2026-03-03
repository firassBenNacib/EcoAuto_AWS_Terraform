data "aws_caller_identity" "current" {}

data "aws_vpc" "default" {
  count   = var.use_default_vpc ? 1 : 0
  default = true
}

data "aws_subnets" "default" {
  count = var.use_default_vpc ? 1 : 0

  filter {
    name   = "vpc-id"
    values = [data.aws_vpc.default[0].id]
  }
}

locals {
  workspace = terraform.workspace
  is_prod   = local.workspace == "prod"
  common_tags = merge(
    {
      ManagedBy   = "Terraform"
      Project     = var.project_name
      Environment = local.workspace
    },
    var.additional_tags
  )

  workspace_mode          = var.compatibility_mode == "workspace"
  enable_workspace_suffix = local.workspace_mode
  workspace_domain        = var.workspace_domain

  backend_alias_final = local.workspace_mode ? (
    local.is_prod ? "${var.workspace_backend_subdomain}.${var.workspace_domain}" : "${var.workspace_backend_subdomain}-${local.workspace}.${var.workspace_domain}"
  ) : var.backend_domain

  frontend_aliases_final = local.workspace_mode ? (
    local.is_prod ? [var.workspace_domain, "www.${var.workspace_domain}"] : ["${local.workspace}.${var.workspace_domain}", "www.${local.workspace}.${var.workspace_domain}"]
  ) : [var.frontend_domain, "www.${var.frontend_domain}"]

  backend_bootstrap_origin_domain_final = local.workspace_mode && var.workspace_bootstrap_origin_domain != "" ? var.workspace_bootstrap_origin_domain : var.backend_bootstrap_origin_domain
  bucket_name_final                     = local.workspace_mode && var.append_workspace_to_bucket_name ? "${var.bucket_name}-${local.workspace}" : var.bucket_name
  effective_backend_port                = var.app_port != null ? var.app_port : var.backend_port
  effective_enable_vpc_flow_logs        = var.enable_vpc_flow_logs || var.enable_observability_addons
  effective_enable_cloudfront_logs      = var.enable_cloudfront_access_logs || var.enable_observability_addons
  effective_enable_ssh_admin            = local.is_prod && !var.allow_ssh_admin_in_prod ? false : var.enable_ssh_admin
  effective_s3_force_destroy            = local.is_prod ? false : var.s3_force_destroy
  effective_rds_deletion_protection     = local.is_prod ? true : var.rds_deletion_protection
  effective_rds_skip_final_snapshot     = local.is_prod ? false : var.rds_skip_final_snapshot
  asg_name_final                        = local.enable_workspace_suffix ? "${var.asg_name}-${local.workspace}" : var.asg_name
  rds_identifier_final                  = local.enable_workspace_suffix ? "${var.rds_identifier}-${local.workspace}" : var.rds_identifier

  selected_vpc_id = var.use_default_vpc ? data.aws_vpc.default[0].id : module.network[0].vpc_id

  selected_public_subnet_ids    = var.use_default_vpc ? sort(data.aws_subnets.default[0].ids) : sort(module.network[0].public_app_subnet_ids)
  selected_db_subnet_ids        = var.use_default_vpc ? sort(data.aws_subnets.default[0].ids) : sort(module.network[0].private_db_subnet_ids)
  cloudfront_logs_bucket_domain = try(aws_s3_bucket.cloudfront_logs[0].bucket_domain_name, "")
  effective_update_infra_alarm_actions = distinct(concat(
    var.update_infra_alarm_actions,
    try([aws_sns_topic.update_infra_alarm[0].arn], [])
  ))
}

resource "null_resource" "guardrails" {
  triggers = {
    workspace = local.workspace
  }

  lifecycle {
    precondition {
      condition     = !(local.is_prod && var.use_default_vpc)
      error_message = "use_default_vpc=true is not allowed in prod. Prod must use dedicated VPC with private DB subnets."
    }

    precondition {
      condition     = !var.use_default_vpc || local.is_prod || var.allow_default_vpc_outside_prod
      error_message = "use_default_vpc=true outside prod is disabled by allow_default_vpc_outside_prod=false. Use dedicated VPC/subnets instead."
    }

    precondition {
      condition = var.use_default_vpc || (
        length(var.availability_zones) > 0 &&
        length(var.public_app_subnet_cidrs) == length(var.availability_zones) &&
        length(var.private_db_subnet_cidrs) == length(var.availability_zones)
      )
      error_message = "When use_default_vpc=false, set availability_zones and provide matching public_app_subnet_cidrs/private_db_subnet_cidrs lengths."
    }

    precondition {
      condition     = !var.enable_origin_auth_header || trimspace(var.origin_auth_header_value) != ""
      error_message = "enable_origin_auth_header=true requires origin_auth_header_value to be set."
    }

    precondition {
      condition     = !var.enable_origin_auth_header || lower(trimspace(var.origin_auth_header_name)) != lower(trimspace(var.origin_auth_previous_header_name))
      error_message = "origin_auth_header_name and origin_auth_previous_header_name must be different to support safe two-header rotation."
    }

    precondition {
      condition     = !local.is_prod || var.enable_origin_auth_header
      error_message = "Prod requires enable_origin_auth_header=true to prevent direct-origin bypass from other CloudFront distributions."
    }

    precondition {
      condition     = !var.enable_s3_kms_encryption || (var.s3_kms_key_id != null && trimspace(var.s3_kms_key_id) != "")
      error_message = "enable_s3_kms_encryption=true requires s3_kms_key_id."
    }

    precondition {
      condition     = !local.effective_enable_cloudfront_logs || trimspace(var.cloudfront_logs_bucket_name) != ""
      error_message = "enable_cloudfront_access_logs=true (or enable_observability_addons=true) requires cloudfront_logs_bucket_name."
    }

    precondition {
      condition     = var.backend_origin_protocol_policy != "https-only" || var.allow_backend_https_origin_with_dynamic_public_dns
      error_message = "backend_origin_protocol_policy=https-only requires origin TLS certificates that match dynamic EC2 PublicDnsName origins. Set allow_backend_https_origin_with_dynamic_public_dns=true only after implementing that strategy."
    }

    precondition {
      condition     = !(var.rds_multi_az && var.enable_compute_start_stop_schedule)
      error_message = "rds_multi_az=true cannot be combined with enable_compute_start_stop_schedule=true because stop/start automation uses StopDBInstance/StartDBInstance."
    }

    precondition {
      condition     = !var.enable_update_infra_alarm || var.create_update_infra_alarm_sns_topic || length(var.update_infra_alarm_actions) > 0
      error_message = "enable_update_infra_alarm=true requires at least one alarm action. Either keep create_update_infra_alarm_sns_topic=true or provide update_infra_alarm_actions."
    }

    precondition {
      condition     = var.create_update_infra_alarm_sns_topic || length(var.update_infra_alarm_email_endpoints) == 0
      error_message = "update_infra_alarm_email_endpoints requires create_update_infra_alarm_sns_topic=true."
    }
  }
}

#tfsec:ignore:aws-sns-topic-encryption-use-cmk Economic profile uses AWS-managed SNS key by default to avoid dedicated CMK monthly cost. Override update_infra_alarm_sns_kms_key_id with a customer-managed CMK if required.
resource "aws_sns_topic" "update_infra_alarm" {
  count = var.enable_update_infra_alarm && var.create_update_infra_alarm_sns_topic ? 1 : 0

  name              = local.enable_workspace_suffix ? "${var.project_name}-${local.workspace}-update-infra-alerts" : "${var.project_name}-update-infra-alerts"
  kms_master_key_id = var.update_infra_alarm_sns_kms_key_id
}

resource "aws_sns_topic_subscription" "update_infra_alarm_email" {
  for_each = var.enable_update_infra_alarm && var.create_update_infra_alarm_sns_topic ? toset(var.update_infra_alarm_email_endpoints) : toset([])

  topic_arn = aws_sns_topic.update_infra_alarm[0].arn
  protocol  = "email"
  endpoint  = each.value
}

resource "aws_s3_bucket" "cloudfront_logs" {
  count = local.effective_enable_cloudfront_logs ? 1 : 0

  bucket = var.cloudfront_logs_bucket_name
}

resource "aws_s3_bucket_ownership_controls" "cloudfront_logs" {
  count = local.effective_enable_cloudfront_logs ? 1 : 0

  bucket = aws_s3_bucket.cloudfront_logs[0].id

  rule {
    object_ownership = "BucketOwnerPreferred"
  }
}

resource "aws_s3_bucket_acl" "cloudfront_logs" {
  count = local.effective_enable_cloudfront_logs ? 1 : 0

  bucket = aws_s3_bucket.cloudfront_logs[0].id
  acl    = "log-delivery-write"

  depends_on = [aws_s3_bucket_ownership_controls.cloudfront_logs]
}

resource "aws_s3_bucket_server_side_encryption_configuration" "cloudfront_logs" {
  count = local.effective_enable_cloudfront_logs ? 1 : 0

  bucket = aws_s3_bucket.cloudfront_logs[0].id

  rule {
    apply_server_side_encryption_by_default {
      sse_algorithm = "AES256"
    }
  }
}

resource "aws_s3_bucket_public_access_block" "cloudfront_logs" {
  count = local.effective_enable_cloudfront_logs ? 1 : 0

  bucket = aws_s3_bucket.cloudfront_logs[0].id

  block_public_acls       = true
  block_public_policy     = true
  ignore_public_acls      = true
  restrict_public_buckets = true
}

resource "aws_s3_bucket_lifecycle_configuration" "cloudfront_logs" {
  count = local.effective_enable_cloudfront_logs && var.enable_cloudfront_logs_lifecycle ? 1 : 0

  bucket = aws_s3_bucket.cloudfront_logs[0].id

  rule {
    id     = "cloudfront-log-retention"
    status = "Enabled"

    expiration {
      days = var.cloudfront_logs_expiration_days
    }

    abort_incomplete_multipart_upload {
      days_after_initiation = var.cloudfront_logs_abort_incomplete_multipart_upload_days
    }
  }
}

module "network" {
  count  = var.use_default_vpc ? 0 : 1
  source = "./modules/network"

  vpc_name                        = var.vpc_name
  vpc_cidr                        = var.vpc_cidr
  availability_zones              = var.availability_zones
  public_app_subnet_cidrs         = var.public_app_subnet_cidrs
  private_db_subnet_cidrs         = var.private_db_subnet_cidrs
  enable_vpc_flow_logs            = local.effective_enable_vpc_flow_logs
  flow_logs_retention_days        = var.vpc_flow_logs_retention_days
  lockdown_default_security_group = var.lockdown_default_security_group
}

module "iam" {
  source = "./modules/iam"

  aws_region              = var.aws_region
  asg_name                = local.asg_name_final
  rds_instance_id         = local.rds_identifier_final
  enable_workspace_suffix = local.enable_workspace_suffix
}

module "security_groups" {
  source = "./modules/security_groups"

  vpc_id                  = local.selected_vpc_id
  app_port                = local.effective_backend_port
  enable_ssh_admin        = local.effective_enable_ssh_admin
  admin_cidr              = var.admin_cidr
  enable_workspace_suffix = local.enable_workspace_suffix
}

module "s3" {
  source = "./modules/s3"

  bucket_name                                      = local.bucket_name_final
  force_destroy                                    = local.effective_s3_force_destroy
  versioning_enabled                               = var.s3_versioning_enabled
  enable_kms_encryption                            = var.enable_s3_kms_encryption
  kms_key_id                                       = var.s3_kms_key_id
  enable_lifecycle                                 = var.enable_s3_lifecycle
  lifecycle_expiration_days                        = var.s3_lifecycle_expiration_days
  lifecycle_noncurrent_expiration_days             = var.s3_lifecycle_noncurrent_expiration_days
  lifecycle_abort_incomplete_multipart_upload_days = var.s3_lifecycle_abort_incomplete_multipart_upload_days
}

module "cloudfront_frontend" {
  source = "./modules/cloudfront/frontend"

  frontend_bucket_domain     = module.s3.bucket_domain_name
  frontend_aliases           = local.frontend_aliases_final
  frontend_cert_arn          = var.acm_cert_frontend
  cache_policy_id            = var.frontend_cache_policy_id
  price_class                = var.frontend_price_class
  response_headers_policy_id = var.frontend_response_headers_policy_id
  viewer_protocol_policy     = var.frontend_viewer_protocol_policy
  enable_access_logs         = local.effective_enable_cloudfront_logs
  access_logs_bucket         = local.cloudfront_logs_bucket_domain
  access_logs_prefix         = "${var.cloudfront_logs_prefix}frontend/"
  enable_workspace_suffix    = local.enable_workspace_suffix
  workspace_domain           = local.workspace_domain
  web_acl_id                 = var.frontend_web_acl_arn
}

data "aws_iam_policy_document" "frontend_bucket_policy" {
  statement {
    sid    = "DenyInsecureTransport"
    effect = "Deny"

    principals {
      type        = "*"
      identifiers = ["*"]
    }

    actions = ["s3:*"]
    resources = [
      module.s3.bucket_arn,
      "${module.s3.bucket_arn}/*"
    ]

    condition {
      test     = "Bool"
      variable = "aws:SecureTransport"
      values   = ["false"]
    }
  }

  statement {
    effect = "Allow"

    principals {
      type        = "Service"
      identifiers = ["cloudfront.amazonaws.com"]
    }

    actions   = ["s3:GetObject"]
    resources = ["${module.s3.bucket_arn}/*"]

    condition {
      test     = "StringEquals"
      variable = "AWS:SourceAccount"
      values   = [data.aws_caller_identity.current.account_id]
    }

    condition {
      test     = "StringEquals"
      variable = "AWS:SourceArn"
      values   = [module.cloudfront_frontend.frontend_distribution_arn]
    }
  }
}

resource "aws_s3_bucket_policy" "frontend_policy" {
  bucket = module.s3.bucket_name
  policy = data.aws_iam_policy_document.frontend_bucket_policy.json
}

module "rds" {
  source = "./modules/rds"

  identifier                = var.rds_identifier
  db_name                   = var.rds_db_name
  username                  = var.rds_username
  password                  = var.rds_password
  instance_class            = var.rds_instance_class
  allocated_storage         = var.rds_allocated_storage
  multi_az                  = var.rds_multi_az
  backup_retention_period   = var.rds_backup_retention_period
  deletion_protection       = local.effective_rds_deletion_protection
  skip_final_snapshot       = local.effective_rds_skip_final_snapshot
  final_snapshot_identifier = var.rds_final_snapshot_identifier
  kms_key_id                = var.kms_key_id
  enable_iam_database_auth  = var.enable_rds_iam_auth
  rds_sg_id                 = module.security_groups.rds_sg_id
  db_subnet_ids             = local.selected_db_subnet_ids
  enable_workspace_suffix   = local.enable_workspace_suffix
}

module "ec2" {
  source = "./modules/ec2"

  ami_id                            = var.ec2_ami_id
  instance_type                     = var.instance_type
  key_name                          = var.ec2_key_name
  root_block_device_name            = var.ec2_root_block_device_name
  root_volume_size                  = var.ec2_root_volume_size
  root_volume_type                  = var.ec2_root_volume_type
  ebs_kms_key_id                    = var.ec2_ebs_kms_key_id
  rds_endpoint                      = module.rds.endpoint
  rds_username                      = var.rds_username
  rds_password                      = var.rds_password
  db_name                           = var.rds_db_name
  security_group_ids                = [module.security_groups.backend_ec2_sg_id]
  iam_instance_profile              = module.iam.ec2_instance_profile_name
  subnet_ids                        = local.selected_public_subnet_ids
  launch_template_prefix            = var.launch_template_prefix
  ec2_instance_name                 = var.ec2_instance_name
  asg_name                          = var.asg_name
  desired_capacity                  = var.desired_capacity
  min_size                          = var.min_size
  max_size                          = var.max_size
  cpu_target_value                  = var.cpu_target_value
  asg_health_check_grace_period     = var.asg_health_check_grace_period
  asg_default_instance_warmup       = var.asg_default_instance_warmup
  enable_instance_refresh           = var.enable_asg_instance_refresh
  instance_refresh_min_healthy_pct  = var.asg_instance_refresh_min_healthy_percentage
  instance_refresh_warmup_seconds   = var.asg_instance_refresh_warmup_seconds
  user_data_script                  = var.user_data_script
  backend_port                      = local.effective_backend_port
  enable_origin_auth_header         = var.enable_origin_auth_header
  origin_auth_header_name           = var.origin_auth_header_name
  origin_auth_header_value          = var.origin_auth_header_value
  origin_auth_previous_header_name  = var.origin_auth_previous_header_name
  origin_auth_previous_header_value = var.origin_auth_previous_header_value
  enable_workspace_suffix           = local.enable_workspace_suffix
}

module "lambda" {
  source = "./modules/lambda"
  providers = {
    aws           = aws
    aws.us_east_1 = aws.us_east_1
  }

  rds_instance_id                               = local.rds_identifier_final
  asg_name                                      = module.ec2.asg_name
  infra_update_lambda_role_arn                  = module.iam.infra_update_lambda_role_arn
  scheduler_lambda_role_arn                     = module.iam.scheduler_lambda_role_arn
  lambda_edge_role_arn                          = module.iam.lambda_edge_role_arn
  backend_cf_dist_id                            = module.cloudfront_backend.backend_distribution_id
  app_port                                      = local.effective_backend_port
  origin_protocol_policy                        = var.backend_origin_protocol_policy
  enable_origin_auth_header                     = var.enable_origin_auth_header
  origin_auth_header_name                       = var.origin_auth_header_name
  origin_auth_header_value                      = var.origin_auth_header_value
  origin_auth_previous_header_name              = var.origin_auth_previous_header_name
  origin_auth_previous_header_value             = var.origin_auth_previous_header_value
  enable_origin_health_probe                    = var.enable_origin_health_probe
  origin_health_fail_open                       = var.origin_health_fail_open
  origin_health_path                            = var.origin_health_path
  origin_health_timeout_seconds                 = var.origin_health_timeout_seconds
  start_min_size                                = var.min_size
  start_desired_capacity                        = var.desired_capacity
  start_max_size                                = var.max_size
  stop_snapshot_wait_seconds                    = var.stop_snapshot_wait_seconds
  stop_snapshot_poll_interval_seconds           = var.stop_snapshot_poll_interval_seconds
  lambda_log_retention_days                     = var.lambda_log_retention_days
  lambda_log_kms_key_id                         = var.lambda_log_kms_key_id
  manage_lambda_log_groups                      = var.manage_lambda_log_groups
  update_infra_reserved_concurrent_executions   = var.update_infra_reserved_concurrent_executions
  enable_xray_tracing                           = var.enable_lambda_xray_tracing
  enable_update_infra_alarm                     = var.enable_update_infra_alarm
  update_infra_alarm_actions                    = local.effective_update_infra_alarm_actions
  enable_async_failure_queue                    = var.enable_lambda_async_failure_queue
  async_failure_queue_message_retention_seconds = var.lambda_async_failure_queue_message_retention_seconds
  lambda_async_maximum_retry_attempts           = var.lambda_async_maximum_retry_attempts
  lambda_async_max_event_age_seconds            = var.lambda_async_max_event_age_seconds
  cloudfront_api_max_attempts                   = var.cloudfront_api_max_attempts
  cloudfront_api_base_backoff_seconds           = var.cloudfront_api_base_backoff_seconds
  cloudfront_api_max_backoff_seconds            = var.cloudfront_api_max_backoff_seconds
  snapshot_retention_days                       = var.snapshot_retention_days
  snapshot_min_keep_count                       = var.snapshot_min_keep_count
  enable_workspace_suffix                       = local.enable_workspace_suffix
  enable_snapshot_cleanup                       = var.enable_snapshot_cleanup
}

module "cloudfront_backend" {
  source = "./modules/cloudfront/backend"

  backend_domain_name               = local.backend_bootstrap_origin_domain_final
  backend_alias                     = local.backend_alias_final
  backend_cert_arn                  = var.acm_cert_backend
  lambda_edge_arn                   = module.lambda.lambda_edge_selector_arn
  cache_policy_id                   = var.backend_cache_policy_id
  price_class                       = var.backend_price_class
  origin_request_policy_id          = var.backend_origin_request_policy_id
  geo_locations                     = var.backend_geo_locations
  app_port                          = local.effective_backend_port
  origin_protocol_policy            = var.backend_origin_protocol_policy
  viewer_protocol_policy            = var.backend_viewer_protocol_policy
  enable_origin_auth_header         = var.enable_origin_auth_header
  origin_auth_header_name           = var.origin_auth_header_name
  origin_auth_header_value          = var.origin_auth_header_value
  origin_auth_previous_header_name  = var.origin_auth_previous_header_name
  origin_auth_previous_header_value = var.origin_auth_previous_header_value
  enable_access_logs                = local.effective_enable_cloudfront_logs
  access_logs_bucket                = local.cloudfront_logs_bucket_domain
  access_logs_prefix                = "${var.cloudfront_logs_prefix}backend/"
  enable_workspace_suffix           = local.enable_workspace_suffix
  web_acl_id                        = var.backend_web_acl_arn
  ignore_dynamic_origin_drift       = var.backend_ignore_dynamic_origin_drift
}

data "aws_iam_policy_document" "infra_update_cloudfront_scope_guardrail" {
  statement {
    sid    = "DenyCloudFrontUpdateOutsideManagedDistribution"
    effect = "Deny"
    actions = [
      "cloudfront:GetDistributionConfig",
      "cloudfront:UpdateDistribution"
    ]
    not_resources = [module.cloudfront_backend.backend_distribution_arn]
  }
}

resource "aws_iam_role_policy" "infra_update_cloudfront_scope_guardrail" {
  name = local.enable_workspace_suffix ? "InfraUpdateCloudFrontScopeGuardrail-${local.workspace}" : "InfraUpdateCloudFrontScopeGuardrail"
  role = element(reverse(split("/", module.iam.infra_update_lambda_role_arn)), 0)

  policy = data.aws_iam_policy_document.infra_update_cloudfront_scope_guardrail.json
}

module "cloudwatch_events" {
  source     = "./modules/cloudwatch_events"
  depends_on = [module.lambda]

  start_lambda_arn                         = module.lambda.start_lambda_arn
  stop_lambda_arn                          = module.lambda.stop_lambda_arn
  infra_update_lambda_arn                  = module.lambda.update_infra_lambda_arn
  delete_old_snapshots_arn                 = module.lambda.delete_old_snapshots_arn
  asg_name                                 = module.ec2.asg_name
  enable_start_stop_schedule               = var.enable_compute_start_stop_schedule
  start_schedule_expression                = var.start_schedule_expression
  stop_schedule_expression                 = var.stop_schedule_expression
  snapshot_cleanup_schedule_expression     = var.snapshot_cleanup_schedule_expression
  enable_snapshot_cleanup                  = var.enable_snapshot_cleanup
  enable_origin_health_probe               = var.enable_origin_health_probe
  origin_health_interval_minutes           = var.origin_health_interval_minutes
  dead_letter_queue_arn                    = module.lambda.async_failure_queue_arn
  lambda_invoke_retry_attempts             = var.eventbridge_lambda_retry_attempts
  lambda_invoke_max_event_age_seconds      = var.eventbridge_lambda_max_event_age_seconds
  stop_lambda_invoke_retry_attempts        = var.eventbridge_stop_lambda_retry_attempts
  stop_lambda_invoke_max_event_age_seconds = var.eventbridge_stop_lambda_max_event_age_seconds
  enable_workspace_suffix                  = local.enable_workspace_suffix
}

resource "aws_route53_record" "frontend_root" {
  allow_overwrite = true
  zone_id         = var.route53_zone_id
  name            = local.frontend_aliases_final[0]
  type            = "A"

  alias {
    name                   = module.cloudfront_frontend.frontend_url
    zone_id                = module.cloudfront_frontend.frontend_hosted_zone_id
    evaluate_target_health = false
  }
}

resource "aws_route53_record" "frontend_www" {
  allow_overwrite = true
  zone_id         = var.route53_zone_id
  name            = local.frontend_aliases_final[1]
  type            = "A"

  alias {
    name                   = module.cloudfront_frontend.frontend_url
    zone_id                = module.cloudfront_frontend.frontend_hosted_zone_id
    evaluate_target_health = false
  }
}

resource "aws_route53_record" "backend_api" {
  allow_overwrite = true
  zone_id         = var.route53_zone_id
  name            = local.backend_alias_final
  type            = "A"

  alias {
    name                   = module.cloudfront_backend.backend_url
    zone_id                = module.cloudfront_backend.backend_hosted_zone_id
    evaluate_target_health = false
  }
}
