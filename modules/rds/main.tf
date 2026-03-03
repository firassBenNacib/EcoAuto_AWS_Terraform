locals {
  workspace        = terraform.workspace
  identifier_final = var.enable_workspace_suffix ? "${var.identifier}-${local.workspace}" : var.identifier
  final_snapshot_identifier_final = var.skip_final_snapshot ? null : coalesce(
    var.final_snapshot_identifier,
    "${local.identifier_final}-final"
  )
}

resource "aws_db_subnet_group" "this" {
  name       = "${local.identifier_final}-subnet-group"
  subnet_ids = var.db_subnet_ids

  tags = {
    Name = "${local.identifier_final}-subnet-group"
  }
}

resource "aws_db_instance" "this" {
  identifier              = local.identifier_final
  engine                  = "mysql"
  engine_version          = "8.0.40"
  instance_class          = var.instance_class
  allocated_storage       = var.allocated_storage
  storage_type            = "gp3"
  username                = var.username
  password                = var.password
  db_name                 = var.db_name
  parameter_group_name    = "default.mysql8.0"
  option_group_name       = "default:mysql-8-0"
  publicly_accessible     = false
  multi_az                = var.multi_az
  storage_encrypted       = true
  kms_key_id              = var.kms_key_id
  backup_retention_period = var.backup_retention_period
  #tfsec:ignore:aws-rds-enable-deletion-protection Deletion protection is forced on in prod by root-module guardrails.
  deletion_protection                 = var.deletion_protection
  skip_final_snapshot                 = var.skip_final_snapshot
  final_snapshot_identifier           = local.final_snapshot_identifier_final
  iam_database_authentication_enabled = var.enable_iam_database_auth
  #tfsec:ignore:aws-rds-enable-performance-insights Cost-optimized default keeps Performance Insights optional.
  performance_insights_enabled    = var.enable_performance_insights
  performance_insights_kms_key_id = var.enable_performance_insights ? var.performance_insights_kms_key_id : null
  copy_tags_to_snapshot           = true
  auto_minor_version_upgrade      = true
  db_subnet_group_name            = aws_db_subnet_group.this.name

  vpc_security_group_ids = [var.rds_sg_id]

  tags = {
    Name = local.identifier_final
  }
}
