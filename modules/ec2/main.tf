resource "aws_launch_template" "this" {
  name_prefix   = var.launch_template_prefix
  image_id      = var.ami_id
  instance_type = var.instance_type
  key_name      = var.key_name

  network_interfaces {
    associate_public_ip_address = true
    subnet_id                   = var.subnet_ids[0]
    security_groups             = var.security_group_ids
  }


  user_data = base64encode(templatefile("${path.module}/user-data/${var.user_data_script}", {
    rds_endpoint = var.rds_endpoint
  }))

  iam_instance_profile {
    name = var.iam_instance_profile
  }

  tag_specifications {
    resource_type = "instance"
    tags = {
      Name = var.ec2_instance_name
    }
  }
}

resource "aws_autoscaling_group" "this" {
  name                      = var.asg_name
  desired_capacity          = var.desired_capacity
  max_size                  = var.max_size
  min_size                  = var.min_size
  health_check_type         = "EC2"
  health_check_grace_period = 300
  vpc_zone_identifier       = var.subnet_ids

  launch_template {
    id      = aws_launch_template.this.id
    version = "$Latest"
  }


  tag {
    key                 = "Name"
    value               = var.ec2_instance_name
    propagate_at_launch = true
  }
}

resource "aws_autoscaling_policy" "cpu_target_tracking" {
  name                      = "cpu-tracking"
  policy_type               = "TargetTrackingScaling"
  estimated_instance_warmup = 300
  autoscaling_group_name    = aws_autoscaling_group.this.name

  target_tracking_configuration {
    predefined_metric_specification {
      predefined_metric_type = "ASGAverageCPUUtilization"
    }
    target_value = var.cpu_target_value
  }
}
