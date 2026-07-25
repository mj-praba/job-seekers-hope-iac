output "task_definition_family" {
  value = aws_ecs_task_definition.this.family
}

output "task_definition_arn" {
  value = aws_ecs_task_definition.this.arn
}

output "service_name" {
  value = aws_ecs_service.this.name
}

output "service_arn" {
  value = aws_ecs_service.this.id
}

output "target_group_arn" {
  value = try(aws_lb_target_group.this[0].arn, null)
}

output "ecr_repository_url" {
  value = try(aws_ecr_repository.this[0].repository_url, null)
}

output "log_group_name" {
  value = aws_cloudwatch_log_group.this.name
}

output "service_discovery_service_arn" {
  value = try(aws_service_discovery_service.this[0].arn, null)
}
