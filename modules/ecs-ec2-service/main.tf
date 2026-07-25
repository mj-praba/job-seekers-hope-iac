locals {
  container_name    = coalesce(var.container_name, var.service_name)
  target_group_port = coalesce(var.target_group_port, var.container_port)

  # target_type is derived from network_mode rather than asked for separately, so callers can't
  # set the two out of sync with each other.
  target_type = var.network_mode == "awsvpc" ? "ip" : "instance"

  port_mappings = concat(
    [{
      name          = "${local.container_name}-${var.container_port}-tcp"
      containerPort = var.container_port
      hostPort      = var.network_mode == "awsvpc" ? var.container_port : coalesce(var.host_port, 0)
      protocol      = "tcp"
      appProtocol   = "http"
    }],
    [for m in var.additional_port_mappings : {
      name          = m.name
      containerPort = m.container_port
      hostPort      = var.network_mode == "awsvpc" ? m.container_port : 0
      protocol      = "tcp"
      appProtocol   = "http"
    }]
  )

  environment_files = var.env_file_s3_arn == null ? [] : [
    {
      type  = "s3"
      value = var.env_file_s3_arn
    }
  ]
}

resource "aws_ecs_task_definition" "this" {
  family                   = "${var.service_name}-task"
  requires_compatibilities = ["EC2"]
  network_mode             = var.network_mode
  cpu                      = var.task_cpu
  memory                   = var.task_memory
  task_role_arn            = var.task_role_arn
  execution_role_arn       = var.execution_role_arn

  runtime_platform {
    operating_system_family = "LINUX"
    cpu_architecture        = "X86_64"
  }

  dynamic "volume" {
    for_each = var.volumes
    content {
      name      = volume.value.name
      host_path = volume.value.host_path
    }
  }

  container_definitions = jsonencode([
    {
      name         = local.container_name
      image        = var.container_image
      essential    = true
      portMappings = local.port_mappings
      environment  = var.environment
      secrets = [for s in var.secrets : {
        name      = s.name
        valueFrom = s.value_from
      }]
      environmentFiles = local.environment_files
      mountPoints = [for m in var.mount_points : {
        sourceVolume  = m.source_volume
        containerPath = m.container_path
        readOnly      = m.read_only
      }]
      volumesFrom    = []
      systemControls = []
      logConfiguration = {
        logDriver = "awslogs"
        options = {
          awslogs-group         = aws_cloudwatch_log_group.this.name
          awslogs-region        = data.aws_region.current.name
          awslogs-create-group  = "true"
          awslogs-stream-prefix = "ecs"
        }
      }
    }
  ])

  # CI/CD registers new task-definition revisions and updates the running service directly via
  # the AWS API on every deploy, bypassing Terraform entirely - ignore drift so `terraform apply`
  # never rolls a live service back to whatever revision this config knows about.
  lifecycle {
    ignore_changes = [container_definitions]
  }
}

resource "aws_ecs_service" "this" {
  name            = var.service_name
  cluster         = var.cluster_arn
  task_definition = aws_ecs_task_definition.this.arn
  desired_count   = var.desired_count

  enable_ecs_managed_tags           = true
  health_check_grace_period_seconds = var.attach_load_balancer ? 0 : null

  capacity_provider_strategy {
    capacity_provider = var.capacity_provider_name
    weight            = 1
    base              = 0
  }

  deployment_maximum_percent         = var.deployment_maximum_percent
  deployment_minimum_healthy_percent = var.deployment_minimum_healthy_percent

  deployment_circuit_breaker {
    enable   = true
    rollback = true
  }

  dynamic "network_configuration" {
    for_each = var.network_mode == "awsvpc" ? [var.network_configuration] : []
    content {
      subnets          = network_configuration.value.subnet_ids
      security_groups  = network_configuration.value.security_group_ids
      assign_public_ip = network_configuration.value.assign_public_ip
    }
  }

  dynamic "load_balancer" {
    for_each = var.attach_load_balancer ? [1] : []
    content {
      target_group_arn = aws_lb_target_group.this[0].arn
      container_name   = local.container_name
      container_port   = var.container_port
    }
  }

  dynamic "service_registries" {
    for_each = var.enable_service_discovery ? [1] : []
    content {
      registry_arn = aws_service_discovery_service.this[0].arn
    }
  }

  propagate_tags = "SERVICE"

  tags = merge(var.tags, {
    Component = var.component
  })

  # deploy CD registers new task-definition revisions and updates the running service directly via
  # the AWS API on every deploy - ignore drift here so `terraform apply` never rolls the live
  # service back.
  lifecycle {
    ignore_changes = [task_definition]
  }
}

data "aws_region" "current" {}
