# Holds the backend's .env file (DB connection string, JWT secrets, MS SSO creds, GROQ_API_KEY,
# etc.) - Terraform only creates the bucket. Uploading the actual .env is a manual step (see
# README.md) since those values are real secrets that shouldn't pass through Terraform state.
resource "aws_s3_bucket" "backend_deploy_config" {
  bucket = "job-seekers-hope-backend-deploy-config"

  tags = {
    Project     = "job-seekers-hope"
    Environment = "prod"
    ManagedBy   = "terraform"
    Component   = "s3"
  }
}

resource "aws_s3_bucket_versioning" "backend_deploy_config" {
  bucket = aws_s3_bucket.backend_deploy_config.id
  versioning_configuration {
    status = "Enabled"
  }
}

resource "aws_s3_bucket_public_access_block" "backend_deploy_config" {
  bucket = aws_s3_bucket.backend_deploy_config.id

  block_public_acls       = true
  ignore_public_acls      = true
  block_public_policy     = true
  restrict_public_buckets = true
}

resource "aws_s3_bucket_server_side_encryption_configuration" "backend_deploy_config" {
  bucket = aws_s3_bucket.backend_deploy_config.id

  rule {
    apply_server_side_encryption_by_default {
      sse_algorithm = "AES256"
    }
  }
}

resource "aws_s3_bucket_ownership_controls" "backend_deploy_config" {
  bucket = aws_s3_bucket.backend_deploy_config.id
  rule {
    object_ownership = "BucketOwnerEnforced"
  }
}

# Single ECS service, no ALB - reached directly on the EC2 instance's Elastic IP (eip.tf) via a
# fixed host port. Same ECS/ECR deploy flow the backend-cd.yml comment describes for a "real
# Graviton/ECS deployment", just EIP instead of ALB.
#
# container_image points at this service's own ECR repo (created below) with no image pushed
# yet - first apply creates empty infra; the ECS task won't actually start running until a CD
# workflow builds backend/Dockerfile and pushes an image tagged :latest (or update this to a
# specific tag). Terraform ignores drift on this field regardless (see modules/ecs-ec2-service).
module "backend_api" {
  source = "../../modules/ecs-ec2-service"

  service_name           = "job-seekers-hope-api"
  component              = "ecs-api"
  cluster_arn            = aws_ecs_cluster.backend.arn
  capacity_provider_name = module.backend_ec2_capacity.capacity_provider_name
  network_mode           = "bridge"
  task_cpu               = "512"
  task_memory            = "1024"
  container_image        = "${data.aws_caller_identity.current.account_id}.dkr.ecr.${var.aws_region}.amazonaws.com/job-seekers-hope-api:latest"
  container_port         = var.backend_container_port
  host_port              = 80
  attach_load_balancer   = false
  # Fixed host port + single instance: the old task must stop before the new one can bind, so
  # deployments are stop-then-start (brief downtime, acceptable for a low-traffic personal app).
  deployment_maximum_percent         = 100
  deployment_minimum_healthy_percent = 0
  create_ecr_repository              = true
  env_file_s3_arn                    = "${aws_s3_bucket.backend_deploy_config.arn}/backend/.env"
  task_role_arn                      = aws_iam_role.backend_task.arn
  execution_role_arn                 = aws_iam_role.backend_execution.arn

  tags = {
    Project     = "job-seekers-hope"
    Environment = "prod"
    ManagedBy   = "terraform"
  }
}
