# Postgres (pgvector) as a container on the same instance as the API - not RDS. RDS's default
# backup_retention_period was rejected on this account (FreeTierRestrictionError on
# CreateDBInstance), and this account can't use paid RDS features until upgraded out of Free
# Tier. Matches the pgvector/pgvector:pg16 image used in local dev (backend/docker-compose.yml).
#
# Durability caveat: /opt/postgres/data (see templates/user-data-extra.sh.tpl) is a host-path
# volume on this instance's root EBS volume. It survives container restarts but NOT instance
# replacement (ASG health-check failure, AZ rebalance, a future Spot switch) - unlike RDS,
# there's no automated backup here. Take manual pg_dump backups periodically, or add a
# snapshot/backup script if this data matters long-term.

# Generated rather than asked for, so there's no weak/default password to forget to change.
resource "random_password" "backend_db" {
  length  = 32
  special = false
}

# The password never appears in plaintext in the task definition - ECS resolves it from here
# at container startup (requires the execution role's secretsmanager:GetSecretValue grant,
# see iam.tf). Retrieve it yourself with: aws secretsmanager get-secret-value --secret-id
# job-seekers-hope-backend-db-password --query SecretString --output text
resource "aws_secretsmanager_secret" "backend_db_password" {
  name = "job-seekers-hope-backend-db-password"

  tags = {
    Project     = "job-seekers-hope"
    Environment = "prod"
    ManagedBy   = "terraform"
  }
}

resource "aws_secretsmanager_secret_version" "backend_db_password" {
  secret_id     = aws_secretsmanager_secret.backend_db_password.id
  secret_string = random_password.backend_db.result
}

module "backend_postgres" {
  source = "../../modules/ecs-ec2-service"

  service_name = "job-seekers-hope-postgres"
  # Closest fit in the component taxonomy: a background/support process, not a request-serving
  # API.
  component              = "ecs-worker"
  cluster_arn            = aws_ecs_cluster.backend.arn
  capacity_provider_name = module.backend_ec2_capacity.capacity_provider_name
  network_mode           = "bridge"
  task_cpu               = "256"
  task_memory            = "512"
  container_image        = "pgvector/pgvector:pg16"
  container_port         = 5432
  host_port              = 5432 # fixed - public via the instance SG (backend_postgres rule)
  attach_load_balancer   = false
  create_ecr_repository  = false # public image, no custom repo
  execution_role_arn     = aws_iam_role.backend_execution.arn
  # Fixed host port + single instance: the old task must stop before the new one can bind, so
  # deployments are stop-then-start (brief downtime). Same rationale as the api service.
  deployment_maximum_percent         = 100
  deployment_minimum_healthy_percent = 0

  environment = [
    { name = "POSTGRES_USER", value = var.backend_db_username },
    { name = "POSTGRES_DB", value = var.backend_db_name },
  ]

  secrets = [
    { name = "POSTGRES_PASSWORD", value_from = aws_secretsmanager_secret.backend_db_password.arn }
  ]

  volumes = [
    { name = "postgres-data", host_path = "/opt/postgres/data" }
  ]
  mount_points = [
    { source_volume = "postgres-data", container_path = "/var/lib/postgresql/data" }
  ]

  tags = {
    Project     = "job-seekers-hope"
    Environment = "prod"
    ManagedBy   = "terraform"
  }
}
