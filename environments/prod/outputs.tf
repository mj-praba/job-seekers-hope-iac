output "frontend_bucket_name" {
  value = module.frontend.bucket_name
}

output "frontend_bucket_arn" {
  value = module.frontend.bucket_arn
}

output "frontend_website_endpoint" {
  value = module.frontend.website_endpoint
}

output "backend_blob_store_bucket_name" {
  value = aws_s3_bucket.backend_blob_store.id
}

output "backend_blob_store_bucket_arn" {
  value = aws_s3_bucket.backend_blob_store.arn
}

output "backend_api_url" {
  description = "Backend API base URL - no domain/TLS yet, plain HTTP via the Elastic IP."
  value       = "http://${aws_eip.backend.public_ip}"
}

output "backend_eip_public_ip" {
  value = aws_eip.backend.public_ip
}

output "backend_ecs_cluster_name" {
  value = aws_ecs_cluster.backend.name
}

output "backend_ecs_service_name" {
  value = module.backend_api.service_name
}

output "backend_ecr_repository_url" {
  value = module.backend_api.ecr_repository_url
}

output "backend_deploy_config_bucket_name" {
  value = aws_s3_bucket.backend_deploy_config.id
}

output "backend_db_host" {
  description = "Postgres runs as a container on the same instance as the API, exposed publicly on the Elastic IP. From the API container itself (same host), the docker bridge gateway 172.17.0.1 also reaches it and avoids the round-trip through the public IP/SG."
  value       = aws_eip.backend.public_ip
}

output "backend_db_port" {
  value = 5432
}

output "backend_db_name" {
  value = var.backend_db_name
}

output "backend_db_username" {
  value = var.backend_db_username
}

output "backend_db_password" {
  value     = random_password.backend_db.result
  sensitive = true
}
