# Attaches to an ALB via ARNs passed in from the caller - never creates or manages the ALB
# itself. Unused entirely when attach_load_balancer = false (e.g. EIP-only deployments).

resource "aws_lb_target_group" "this" {
  count = var.attach_load_balancer ? 1 : 0

  name_prefix = substr(var.service_name, 0, 6)
  port        = local.target_group_port
  protocol    = "HTTP"
  vpc_id      = var.vpc_id
  target_type = local.target_type

  deregistration_delay = 300

  health_check {
    enabled             = true
    healthy_threshold   = 5
    unhealthy_threshold = 2
    timeout             = 5
    interval            = 30
    path                = var.health_check_path
    matcher             = "200"
    port                = "traffic-port"
    protocol            = "HTTP"
  }

  stickiness {
    type            = "lb_cookie"
    enabled         = false
    cookie_duration = 86400
  }

  tags = merge(var.tags, {
    Component = var.component
  })

  lifecycle {
    create_before_destroy = true
  }
}

resource "aws_lb_listener_rule" "this" {
  for_each = var.attach_load_balancer ? { for idx, rule in var.listener_rules : idx => rule } : {}

  listener_arn = each.value.listener_arn
  priority     = each.value.priority

  action {
    type = "forward"

    forward {
      target_group {
        arn    = aws_lb_target_group.this[0].arn
        weight = 1
      }

      stickiness {
        enabled  = false
        duration = 3600
      }
    }
  }

  dynamic "condition" {
    for_each = length(each.value.host_headers) > 0 ? [1] : []
    content {
      host_header {
        values = each.value.host_headers
      }
    }
  }

  dynamic "condition" {
    for_each = length(each.value.path_patterns) > 0 ? [1] : []
    content {
      path_pattern {
        values = each.value.path_patterns
      }
    }
  }
}
