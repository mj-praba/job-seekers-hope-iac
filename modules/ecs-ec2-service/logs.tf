resource "aws_cloudwatch_log_group" "this" {
  name              = "/ecs/${var.service_name}-task"
  retention_in_days = var.log_retention_days
}
