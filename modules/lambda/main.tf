data "archive_file" "update_sgs_zip" {
  type        = "zip"
  source_file = "${path.module}/src/update_sgs.py"
  output_path = "${path.module}/src/update_sgs.zip"
}

data "archive_file" "update_infra_zip" {
  type        = "zip"
  source_file = "${path.module}/src/update_infra.py"
  output_path = "${path.module}/src/update_infra.zip"
}

data "archive_file" "start_instances_zip" {
  type        = "zip"
  source_file = "${path.module}/src/start_instances.py"
  output_path = "${path.module}/src/start_instances.zip"
}

data "archive_file" "stop_instances_zip" {
  type        = "zip"
  source_file = "${path.module}/src/stop_instances.py"
  output_path = "${path.module}/src/stop_instances.zip"
}

data "archive_file" "edge_selector_zip" {
  type        = "zip"
  source_dir  = "${path.module}/src/edge_origin_selector"
  output_path = "${path.module}/src/edge_origin_selector.zip"
}

resource "aws_lambda_function" "update_sgs" {
  filename         = data.archive_file.update_sgs_zip.output_path
  function_name    = "UpdateSecurityGroupsFromCloudFrontIPs"
  handler          = "update_sgs.lambda_handler"
  runtime          = "python3.12"
  role             = var.lambda_sg_update_role_arn
  source_code_hash = data.archive_file.update_sgs_zip.output_base64sha256
  timeout          = 30
  memory_size      = 128

  environment {
    variables = {
      SECURITY_GROUP_IDS = join(",", var.security_group_ids)
    }
  }
}

resource "aws_lambda_function" "update_infra" {
  filename         = data.archive_file.update_infra_zip.output_path
  function_name    = "UpdateInfraRouting"
  handler          = "update_infra.lambda_handler"
  runtime          = "python3.9"
  role             = var.infra_update_lambda_role_arn
  source_code_hash = data.archive_file.update_infra_zip.output_base64sha256
  timeout          = 30

  environment {
    variables = {
      CLOUDFRONT_DIST_ID = var.backend_cf_dist_id
      ROUTE53_ZONE_ID    = var.route53_zone_id
      FRONTEND_CF_DOMAIN = var.frontend_cf_domain
      BACKEND_ALIAS      = var.backend_alias
      FRONTEND_ALIAS     = var.frontend_alias
    }
  }
}

resource "aws_lambda_function" "start_instances" {
  filename         = data.archive_file.start_instances_zip.output_path
  function_name    = "StartComputeResources"
  handler          = "start_instances.lambda_handler"
  runtime          = "python3.9"
  role             = var.scheduler_lambda_role_arn
  source_code_hash = data.archive_file.start_instances_zip.output_base64sha256
  timeout          = 30

  environment {
    variables = {
      ASG_NAME        = var.asg_name
      RDS_INSTANCE_ID = var.rds_instance_id
    }
  }
}

resource "aws_lambda_function" "stop_instances" {
  filename         = data.archive_file.stop_instances_zip.output_path
  function_name    = "StopComputeResources"
  handler          = "stop_instances.lambda_handler"
  runtime          = "python3.9"
  role             = var.scheduler_lambda_role_arn
  source_code_hash = data.archive_file.stop_instances_zip.output_base64sha256
  timeout          = 30

  environment {
    variables = {
      ASG_NAME        = var.asg_name
      RDS_INSTANCE_ID = var.rds_instance_id
    }
  }
}

provider "aws" {
  alias  = "us_east_1"
  region = "us-east-1"
}

resource "aws_lambda_function" "lambda_edge_selector" {
  provider         = aws.us_east_1
  function_name    = "EdgeOriginSelector"
  filename         = data.archive_file.edge_selector_zip.output_path
  handler          = "index.handler"
  runtime          = "nodejs18.x"
  role             = var.lambda_edge_role_arn
  publish          = true
  source_code_hash = data.archive_file.edge_selector_zip.output_base64sha256
}
