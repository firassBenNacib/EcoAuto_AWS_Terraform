data "aws_ec2_managed_prefix_list" "cloudfront_origin_facing" {
  name = var.cloudfront_origin_prefix_list_name
}

data "aws_vpc" "selected" {
  id = var.vpc_id
}

locals {
  workspace = terraform.workspace
  suffix    = var.enable_workspace_suffix ? "-${local.workspace}" : ""
}

resource "aws_security_group" "backend_ec2" {
  name        = "backend-ec2-sg${local.suffix}"
  description = "Allow backend traffic only from CloudFront origin-facing prefix list"
  vpc_id      = var.vpc_id

  ingress {
    description     = "Backend app port from CloudFront origin-facing IPs"
    from_port       = var.app_port
    to_port         = var.app_port
    protocol        = "tcp"
    prefix_list_ids = [data.aws_ec2_managed_prefix_list.cloudfront_origin_facing.id]
  }

  egress {
    description = "Allow all outbound traffic"
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    #tfsec:ignore:aws-ec2-no-public-egress-sgr Public backend requires outbound internet for OS/package updates and image pulls in no-NAT mode.
    cidr_blocks = ["0.0.0.0/0"]
  }
}

resource "aws_security_group_rule" "backend_admin_ssh" {
  count = var.enable_ssh_admin ? 1 : 0

  type              = "ingress"
  from_port         = 22
  to_port           = 22
  protocol          = "tcp"
  cidr_blocks       = [var.admin_cidr]
  description       = "Optional SSH admin access"
  security_group_id = aws_security_group.backend_ec2.id
}

resource "aws_security_group" "rds" {
  name        = "rds-from-backend-sg${local.suffix}"
  description = "Allow database access only from backend EC2 security group"
  vpc_id      = var.vpc_id

  ingress {
    description     = "MySQL from backend instances"
    from_port       = 3306
    to_port         = 3306
    protocol        = "tcp"
    security_groups = [aws_security_group.backend_ec2.id]
  }

  egress {
    description = "Restrict outbound traffic to VPC CIDR"
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = [data.aws_vpc.selected.cidr_block]
  }
}
