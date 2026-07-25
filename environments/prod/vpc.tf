# Backend gets its own small, fully Terraform-managed VPC. Public subnets only, no NAT
# (matches this repo's cost-conscious posture) - the EC2 instance gets a public IP and is
# locked down by security groups instead.
module "backend_vpc" {
  source = "../../modules/vpc"

  name                = "job-seekers-hope-backend"
  cidr                = var.backend_vpc_cidr
  public_subnet_cidrs = var.backend_public_subnet_cidrs
  azs                 = var.backend_azs

  tags = {
    Project     = "job-seekers-hope"
    Environment = "prod"
    ManagedBy   = "terraform"
  }
}
