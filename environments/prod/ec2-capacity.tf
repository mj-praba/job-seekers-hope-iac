module "backend_ec2_capacity" {
  source = "../../modules/ecs-ec2-capacity"

  name               = "job-seekers-hope-backend-ec2"
  vpc_id             = module.backend_vpc.vpc_id
  subnet_ids         = module.backend_vpc.public_subnet_ids
  security_group_ids = [aws_security_group.backend_instance.id]
  instance_type      = var.backend_ec2_instance_type
  ecs_cluster_name   = aws_ecs_cluster.backend.name

  min_size         = 1
  desired_capacity = 1
  max_size         = 1

  use_spot = var.backend_use_spot

  # Dedicated role (iam.tf) instead of the shared ecsInstanceRole - see iam.tf.
  create_ecs_instance_role      = false
  use_external_instance_profile = true
  instance_profile_arn          = aws_iam_instance_profile.backend_instance.arn

  user_data_extra = templatefile("${path.module}/templates/user-data-extra.sh.tpl", {
    eip_allocation_id = aws_eip.backend.id
    aws_region        = var.aws_region
  })

  tags = {
    Project     = "job-seekers-hope"
    Environment = "prod"
    ManagedBy   = "terraform"
  }
}
