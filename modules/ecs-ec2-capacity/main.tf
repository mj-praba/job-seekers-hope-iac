data "aws_ssm_parameter" "ecs_optimized_ami" {
  name = "/aws/service/ecs/optimized-ami/amazon-linux-2023/recommended/image_id"
}

# ecsInstanceRole is an account-wide singleton - created by exactly one app root
# (create_ecs_instance_role = true), looked up by every other root.
data "aws_iam_role" "ecs_instance" {
  count = var.create_ecs_instance_role || var.use_external_instance_profile ? 0 : 1
  name  = "ecsInstanceRole"
}

data "aws_iam_instance_profile" "ecs_instance" {
  count = var.create_ecs_instance_role || var.use_external_instance_profile ? 0 : 1
  name  = "ecsInstanceRole"
}

resource "aws_iam_role" "ecs_instance" {
  count = var.create_ecs_instance_role ? 1 : 0

  name = "ecsInstanceRole"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect    = "Allow"
        Principal = { Service = "ec2.amazonaws.com" }
        Action    = "sts:AssumeRole"
      }
    ]
  })
}

resource "aws_iam_role_policy_attachment" "ecs_instance" {
  count = var.create_ecs_instance_role ? 1 : 0

  role       = aws_iam_role.ecs_instance[0].name
  policy_arn = "arn:aws:iam::aws:policy/service-role/AmazonEC2ContainerServiceforEC2Role"
}

resource "aws_iam_instance_profile" "ecs_instance" {
  count = var.create_ecs_instance_role ? 1 : 0

  name = "ecsInstanceRole"
  role = aws_iam_role.ecs_instance[0].name
}

locals {
  instance_profile_arn = var.use_external_instance_profile ? var.instance_profile_arn : (
    var.create_ecs_instance_role ? aws_iam_instance_profile.ecs_instance[0].arn : data.aws_iam_instance_profile.ecs_instance[0].arn
  )
}

resource "aws_launch_template" "this" {
  name_prefix   = "${var.name}-"
  image_id      = data.aws_ssm_parameter.ecs_optimized_ami.value
  instance_type = var.instance_type

  iam_instance_profile {
    arn = local.instance_profile_arn
  }

  network_interfaces {
    associate_public_ip_address = true
    security_groups             = var.security_group_ids
  }

  dynamic "instance_market_options" {
    for_each = var.use_spot ? [1] : []
    content {
      market_type = "spot"
      spot_options {
        spot_instance_type             = "one-time"
        instance_interruption_behavior = "terminate"
      }
    }
  }

  # join() so an empty user_data_extra renders byte-identical to the pre-variable heredoc -
  # any difference would churn a new launch template version in every existing root.
  user_data = base64encode(join("", [
    <<-EOF
    #!/bin/bash
    echo "ECS_CLUSTER=${var.ecs_cluster_name}" >> /etc/ecs/ecs.config
    echo "ECS_ENABLE_CONTAINER_METADATA=true" >> /etc/ecs/ecs.config
    EOF
    , var.user_data_extra
  ]))

  tag_specifications {
    resource_type = "instance"
    tags = merge(var.tags, {
      Name = var.name
    })
  }

  lifecycle {
    create_before_destroy = true
  }
}

resource "aws_autoscaling_group" "this" {
  name                  = "${var.name}-asg"
  vpc_zone_identifier   = var.subnet_ids
  min_size              = var.min_size
  desired_capacity      = var.desired_capacity
  max_size              = var.max_size
  protect_from_scale_in = var.protect_from_scale_in

  launch_template {
    id      = aws_launch_template.this.id
    version = "$Latest"
  }

  dynamic "tag" {
    for_each = merge(var.tags, {
      Name             = var.name
      AmazonECSManaged = "true"
    })
    content {
      key                 = tag.key
      value               = tag.value
      propagate_at_launch = true
    }
  }

  lifecycle {
    create_before_destroy = true
  }
}

resource "aws_ecs_capacity_provider" "this" {
  name = var.name

  auto_scaling_group_provider {
    auto_scaling_group_arn         = aws_autoscaling_group.this.arn
    managed_termination_protection = var.managed_termination_protection

    managed_scaling {
      status                    = "ENABLED"
      target_capacity           = var.managed_scaling_target_capacity
      minimum_scaling_step_size = var.managed_scaling_min_step
      maximum_scaling_step_size = var.managed_scaling_max_step
    }
  }

  tags = var.tags
}
