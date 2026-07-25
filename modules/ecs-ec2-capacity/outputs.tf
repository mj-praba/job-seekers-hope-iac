output "capacity_provider_name" {
  value = aws_ecs_capacity_provider.this.name
}

output "capacity_provider_arn" {
  value = aws_ecs_capacity_provider.this.arn
}

output "autoscaling_group_name" {
  value = aws_autoscaling_group.this.name
}

output "autoscaling_group_arn" {
  value = aws_autoscaling_group.this.arn
}

output "launch_template_id" {
  value = aws_launch_template.this.id
}

output "instance_profile_arn" {
  value = local.instance_profile_arn
}
