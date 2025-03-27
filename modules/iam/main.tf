data "aws_caller_identity" "current" {}


resource "aws_iam_role" "ec2_basic_role" {
  name               = "EC2BasicRole"
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

resource "aws_iam_instance_profile" "ec2_basic_profile" {
  name = "EC2BasicInstanceProfile"
  role = aws_iam_role.ec2_basic_role.name
}

resource "aws_iam_role" "lambda_sg_update_role" {
  name               = "UpdateCloudFrontSGsLambdaRole"
  assume_role_policy = data.aws_iam_policy_document.lambda_assume_role.json
}

resource "aws_iam_policy" "lambda_sg_update_policy" {
  name   = "LambdaEC2SGPolicy"
  policy = data.aws_iam_policy_document.lambda_sg_update_policy_doc.json
}

resource "aws_iam_role_policy_attachment" "lambda_sg_update_attach" {
  role       = aws_iam_role.lambda_sg_update_role.name
  policy_arn = aws_iam_policy.lambda_sg_update_policy.arn
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

data "aws_iam_policy_document" "lambda_sg_update_policy_doc" {
  statement {
    actions   = ["ec2:DescribeSecurityGroups"]
    resources = ["*"]
  }

  statement {
    actions   = ["ec2:AuthorizeSecurityGroupIngress", "ec2:RevokeSecurityGroupIngress"]
    resources = ["arn:aws:ec2:*:*:security-group/*"]
  }

  statement {
    actions   = ["logs:CreateLogGroup", "logs:CreateLogStream", "logs:PutLogEvents"]
    resources = ["arn:aws:logs:*:*:*"]
  }
}


resource "aws_iam_role" "lambda_edge_role" {
  name               = "LambdaEdgeOriginRequestRole"
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
  name               = "SchedulerLambdaExecutionRole"
  assume_role_policy = data.aws_iam_policy_document.lambda_assume_role.json
}

resource "aws_iam_policy" "scheduler_lambda_policy" {
  name   = "SchedulerLambdaPolicy"
  policy = data.aws_iam_policy_document.scheduler_lambda_policy_doc.json
}

resource "aws_iam_role_policy_attachment" "scheduler_lambda_policy_attach" {
  role       = aws_iam_role.scheduler_lambda_role.name
  policy_arn = aws_iam_policy.scheduler_lambda_policy.arn
}

data "aws_iam_policy_document" "scheduler_lambda_policy_doc" {
  statement {
    actions = [
      "logs:CreateLogGroup",
      "logs:CreateLogStream",
      "logs:PutLogEvents"
    ]
    resources = ["arn:aws:logs:*:*:*"]
  }

  statement {
    actions = [
      "autoscaling:DescribeAutoScalingGroups",
      "autoscaling:UpdateAutoScalingGroup",
      "autoscaling:SuspendProcesses",
      "autoscaling:ResumeProcesses",
      "autoscaling:TerminateInstanceInAutoScalingGroup"
    ]
    resources = ["*"]
  }

  statement {
    actions = [
      "ec2:StopInstances",
      "ec2:StartInstances"
    ]
    resources = ["arn:aws:ec2:*:*:instance/*"]
  }

  statement {
    actions = [
      "ec2:DescribeInstances",
      "ec2:DescribeInstanceStatus"
    ]
    resources = ["*"]
  }

  statement {
    actions = [
      "rds:StartDBInstance",
      "rds:StopDBInstance",
      "rds:DescribeDBInstances"
    ]
    resources = ["*"]
  }
}


resource "aws_iam_role" "infra_update_lambda_role" {
  name               = "InfraUpdateLambdaRole"
  assume_role_policy = data.aws_iam_policy_document.lambda_assume_role.json
}

resource "aws_iam_policy" "infra_update_lambda_policy" {
  name   = "InfraUpdateLambdaPolicy"
  policy = data.aws_iam_policy_document.infra_update_lambda_policy_doc.json
}

resource "aws_iam_role_policy_attachment" "infra_update_lambda_policy_attach" {
  role       = aws_iam_role.infra_update_lambda_role.name
  policy_arn = aws_iam_policy.infra_update_lambda_policy.arn
}

data "aws_iam_policy_document" "infra_update_lambda_policy_doc" {
  statement {
    actions   = ["logs:CreateLogGroup", "logs:CreateLogStream", "logs:PutLogEvents"]
    resources = ["arn:aws:logs:*:*:*"]
  }

  statement {
    actions   = ["ec2:DescribeInstances"]
    resources = ["*"]
  }

  statement {
    actions = [
      "cloudfront:GetDistributionConfig",
      "cloudfront:UpdateDistribution"
    ]
    resources = ["arn:aws:cloudfront::${data.aws_caller_identity.current.account_id}:distribution/*"]
  }

  statement {
    actions   = ["route53:ChangeResourceRecordSets"]
    resources = ["arn:aws:route53:::hostedzone/*"]
  }
}


