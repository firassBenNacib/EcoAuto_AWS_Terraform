data "aws_caller_identity" "current" {}

locals {
  workspace = terraform.workspace
  suffix    = var.enable_workspace_suffix ? "-${local.workspace}" : ""

  ec2_role_name             = "EC2BasicRole${local.suffix}"
  ec2_instance_profile_name = "EC2BasicInstanceProfile${local.suffix}"
  lambda_edge_role_name     = "LambdaEdgeOriginRequestRole${local.suffix}"
  scheduler_role_name       = "SchedulerLambdaExecutionRole${local.suffix}"
  scheduler_policy_name     = "SchedulerLambdaPolicy${local.suffix}"
  infra_update_role_name    = "InfraUpdateLambdaRole${local.suffix}"
  infra_update_policy_name  = "InfraUpdateLambdaPolicy${local.suffix}"

  update_infra_function_name = var.enable_workspace_suffix ? "UpdateInfra-${local.workspace}" : "UpdateInfraRouting"
  start_function_name        = var.enable_workspace_suffix ? "StartEC2RDS-${local.workspace}" : "StartComputeResources"
  stop_function_name         = var.enable_workspace_suffix ? "StopEC2RDS-${local.workspace}" : "StopComputeResources"
  delete_function_name       = var.enable_workspace_suffix ? "DeleteSnapshots-${local.workspace}" : "DeleteSnapshots"

  scheduler_log_group_arns = [
    "arn:aws:logs:${var.aws_region}:${data.aws_caller_identity.current.account_id}:log-group:/aws/lambda/${local.start_function_name}:*",
    "arn:aws:logs:${var.aws_region}:${data.aws_caller_identity.current.account_id}:log-group:/aws/lambda/${local.stop_function_name}:*",
    "arn:aws:logs:${var.aws_region}:${data.aws_caller_identity.current.account_id}:log-group:/aws/lambda/${local.delete_function_name}:*"
  ]
  infra_update_log_group_arns = [
    "arn:aws:logs:${var.aws_region}:${data.aws_caller_identity.current.account_id}:log-group:/aws/lambda/${local.update_infra_function_name}:*"
  ]
}

resource "aws_iam_role" "ec2_basic_role" {
  name               = local.ec2_role_name
  assume_role_policy = data.aws_iam_policy_document.ec2_assume_role.json
}

data "aws_iam_policy_document" "ec2_assume_role" {
  statement {
    actions = ["sts:AssumeRole"]

    principals {
      type        = "Service"
      identifiers = ["ec2.amazonaws.com"]
    }
  }
}

resource "aws_iam_role_policy_attachment" "ec2_basic_policy_attach" {
  role       = aws_iam_role.ec2_basic_role.name
  policy_arn = "arn:aws:iam::aws:policy/AmazonEC2ReadOnlyAccess"
}

resource "aws_iam_role_policy_attachment" "ec2_ssm_core_attach" {
  role       = aws_iam_role.ec2_basic_role.name
  policy_arn = "arn:aws:iam::aws:policy/AmazonSSMManagedInstanceCore"
}

resource "aws_iam_instance_profile" "ec2_basic_profile" {
  name = local.ec2_instance_profile_name
  role = aws_iam_role.ec2_basic_role.name
}

data "aws_iam_policy_document" "lambda_assume_role" {
  statement {
    actions = ["sts:AssumeRole"]

    principals {
      type        = "Service"
      identifiers = ["lambda.amazonaws.com"]
    }
  }
}

resource "aws_iam_role" "lambda_edge_role" {
  name               = local.lambda_edge_role_name
  assume_role_policy = data.aws_iam_policy_document.lambda_edge_assume_role.json
}

data "aws_iam_policy_document" "lambda_edge_assume_role" {
  statement {
    actions = ["sts:AssumeRole"]

    principals {
      type        = "Service"
      identifiers = ["lambda.amazonaws.com", "edgelambda.amazonaws.com"]
    }
  }
}

resource "aws_iam_role_policy_attachment" "lambda_edge_logs_attach" {
  role       = aws_iam_role.lambda_edge_role.name
  policy_arn = "arn:aws:iam::aws:policy/service-role/AWSLambdaBasicExecutionRole"
}

resource "aws_iam_role" "scheduler_lambda_role" {
  name               = local.scheduler_role_name
  assume_role_policy = data.aws_iam_policy_document.lambda_assume_role.json
}

resource "aws_iam_policy" "scheduler_lambda_policy" {
  name   = local.scheduler_policy_name
  policy = data.aws_iam_policy_document.scheduler_lambda_policy_doc.json
}

resource "aws_iam_role_policy_attachment" "scheduler_lambda_policy_attach" {
  role       = aws_iam_role.scheduler_lambda_role.name
  policy_arn = aws_iam_policy.scheduler_lambda_policy.arn
}

resource "aws_iam_role_policy_attachment" "scheduler_lambda_xray_attach" {
  role       = aws_iam_role.scheduler_lambda_role.name
  policy_arn = "arn:aws:iam::aws:policy/AWSXRayDaemonWriteAccess"
}

data "aws_iam_policy_document" "scheduler_lambda_policy_doc" {
  statement {
    actions = [
      "logs:CreateLogStream",
      "logs:PutLogEvents"
    ]
    resources = local.scheduler_log_group_arns
  }

  statement {
    actions = [
      "autoscaling:DescribeAutoScalingGroups",
      "autoscaling:DescribeAutoScalingInstances",
      "autoscaling:DescribeScalingActivities"
    ]
    resources = ["*"]
  }

  statement {
    actions = [
      "autoscaling:UpdateAutoScalingGroup",
      "autoscaling:SuspendProcesses",
      "autoscaling:ResumeProcesses"
    ]
    resources = [
      "arn:aws:autoscaling:${var.aws_region}:${data.aws_caller_identity.current.account_id}:autoScalingGroup:*:autoScalingGroupName/${var.asg_name}"
    ]
  }

  statement {
    actions = [
      "rds:StartDBInstance",
      "rds:StopDBInstance",
      "rds:CreateDBSnapshot",
      "rds:DeleteDBSnapshot",
      "rds:AddTagsToResource"
    ]
    resources = [
      "arn:aws:rds:${var.aws_region}:${data.aws_caller_identity.current.account_id}:db:${var.rds_instance_id}",
      "arn:aws:rds:${var.aws_region}:${data.aws_caller_identity.current.account_id}:snapshot:${var.rds_instance_id}*"
    ]
  }

  #tfsec:ignore:aws-iam-no-policy-wildcards RDS Describe APIs do not support resource-level scoping.
  statement {
    actions = [
      "rds:DescribeDBInstances",
      "rds:DescribeDBSnapshots"
    ]
    resources = ["*"]
  }
}

resource "aws_iam_role" "infra_update_lambda_role" {
  name               = local.infra_update_role_name
  assume_role_policy = data.aws_iam_policy_document.lambda_assume_role.json
}

resource "aws_iam_policy" "infra_update_lambda_policy" {
  name   = local.infra_update_policy_name
  policy = data.aws_iam_policy_document.infra_update_lambda_policy_doc.json
}

resource "aws_iam_role_policy_attachment" "infra_update_lambda_policy_attach" {
  role       = aws_iam_role.infra_update_lambda_role.name
  policy_arn = aws_iam_policy.infra_update_lambda_policy.arn
}

resource "aws_iam_role_policy_attachment" "infra_update_lambda_xray_attach" {
  role       = aws_iam_role.infra_update_lambda_role.name
  policy_arn = "arn:aws:iam::aws:policy/AWSXRayDaemonWriteAccess"
}

data "aws_iam_policy_document" "infra_update_lambda_policy_doc" {
  statement {
    actions = [
      "logs:CreateLogStream",
      "logs:PutLogEvents"
    ]
    resources = local.infra_update_log_group_arns
  }

  statement {
    actions = [
      "autoscaling:DescribeAutoScalingGroups",
      "ec2:DescribeInstances"
    ]
    resources = ["*"]
  }

  statement {
    actions = [
      "cloudfront:GetDistributionConfig",
      "cloudfront:UpdateDistribution"
    ]
    resources = ["arn:aws:cloudfront::${data.aws_caller_identity.current.account_id}:distribution/*"]
  }
}
