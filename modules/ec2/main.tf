locals {
  workspace = terraform.workspace

  launch_template_prefix_final = var.enable_workspace_suffix ? "${var.launch_template_prefix}${local.workspace}-" : var.launch_template_prefix
  instance_name_final          = var.enable_workspace_suffix ? "${var.ec2_instance_name}-${local.workspace}" : var.ec2_instance_name
  asg_name_final               = var.enable_workspace_suffix ? "${var.asg_name}-${local.workspace}" : var.asg_name
  cpu_policy_name_final        = var.enable_workspace_suffix ? "cpu-tracking-${local.workspace}" : "cpu-tracking"

  user_data_script_file = var.user_data_script
}

resource "aws_launch_template" "this" {
  name_prefix   = local.launch_template_prefix_final
  image_id      = var.ami_id
  instance_type = var.instance_type
  key_name      = var.key_name

  block_device_mappings {
    device_name = var.root_block_device_name

    ebs {
      encrypted             = true
      kms_key_id            = var.ebs_kms_key_id
      volume_size           = var.root_volume_size
      volume_type           = var.root_volume_type
      delete_on_termination = true
    }
  }

  network_interfaces {
    associate_public_ip_address = true
    security_groups             = var.security_group_ids
  }

  metadata_options {
    http_endpoint               = "enabled"
    http_tokens                 = "required"
    http_put_response_hop_limit = 1
    instance_metadata_tags      = "enabled"
  }

  user_data = base64encode(templatefile("${path.module}/user-data/${local.user_data_script_file}", {
    rds_endpoint                      = var.rds_endpoint
    rds_username                      = var.rds_username
    rds_password                      = var.rds_password
    db_name                           = var.db_name
    backend_port                      = var.backend_port
    enable_origin_auth_header         = var.enable_origin_auth_header
    origin_auth_header_name           = var.origin_auth_header_name
    origin_auth_header_value          = var.origin_auth_header_value
    origin_auth_previous_header_name  = var.origin_auth_previous_header_name
    origin_auth_previous_header_value = var.origin_auth_previous_header_value
  }))

  iam_instance_profile {
    name = var.iam_instance_profile
  }

  tag_specifications {
    resource_type = "instance"
    tags = {
      Name = local.instance_name_final
    }
  }
}

resource "aws_autoscaling_group" "this" {
  name                      = local.asg_name_final
  desired_capacity          = var.desired_capacity
  max_size                  = var.max_size
  min_size                  = var.min_size
  health_check_type         = "EC2"
  health_check_grace_period = var.asg_health_check_grace_period
  default_instance_warmup   = var.asg_default_instance_warmup
  vpc_zone_identifier       = var.subnet_ids

  launch_template {
    id      = aws_launch_template.this.id
    version = "$Latest"
  }

  dynamic "instance_refresh" {
    for_each = var.enable_instance_refresh ? [1] : []
    content {
      strategy = "Rolling"
      preferences {
        min_healthy_percentage = var.instance_refresh_min_healthy_pct
        instance_warmup        = var.instance_refresh_warmup_seconds
        auto_rollback          = true
      }
    }
  }

  tag {
    key                 = "Name"
    value               = local.instance_name_final
    propagate_at_launch = true
  }
}

resource "aws_autoscaling_policy" "cpu_target_tracking" {
  name                      = local.cpu_policy_name_final
  policy_type               = "TargetTrackingScaling"
  estimated_instance_warmup = var.asg_default_instance_warmup
  autoscaling_group_name    = aws_autoscaling_group.this.name

  target_tracking_configuration {
    predefined_metric_specification {
      predefined_metric_type = "ASGAverageCPUUtilization"
    }
    target_value = var.cpu_target_value
  }
}
