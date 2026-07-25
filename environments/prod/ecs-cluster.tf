resource "aws_ecs_cluster" "backend" {
  name = "job-seekers-hope-backend"

  tags = {
    Project     = "job-seekers-hope"
    Environment = "prod"
    ManagedBy   = "terraform"
    Component   = "ecs-cluster"
  }
}

resource "aws_ecs_cluster_capacity_providers" "backend" {
  cluster_name       = aws_ecs_cluster.backend.name
  capacity_providers = [module.backend_ec2_capacity.capacity_provider_name]

  default_capacity_provider_strategy {
    capacity_provider = module.backend_ec2_capacity.capacity_provider_name
    weight            = 1
    base              = 0
  }
}
