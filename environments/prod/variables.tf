variable "aws_region" {
  type    = string
  default = "us-east-1"
}

variable "backend_vpc_cidr" {
  type    = string
  default = "10.60.0.0/16"
}

variable "backend_public_subnet_cidrs" {
  description = "One CIDR per public subnet, paired index-wise with backend_azs."
  type        = list(string)
  default     = ["10.60.0.0/24", "10.60.1.0/24"]
}

variable "backend_azs" {
  description = "One AZ per public subnet, paired index-wise with backend_public_subnet_cidrs."
  type        = list(string)
  default     = ["us-east-1a", "us-east-1b"]
}

variable "backend_ec2_instance_type" {
  description = "t3.small (2 GiB RAM) to comfortably fit the NestJS API's in-process embedding model (@xenova/transformers) alongside Node/ECS-agent overhead on a single instance."
  type        = string
  default     = "t3.small"
}

variable "backend_use_spot" {
  description = "On-demand by default: a Spot reclaim replaces the instance (brief downtime while the ASG re-launches and user-data re-attaches the EIP). Flip to true to cut cost once that's acceptable."
  type        = bool
  default     = false
}

variable "backend_enable_ssh" {
  description = "Open port 22 on the instance SG. Off by default - the instance role includes SSM, so use Session Manager for shell access instead."
  type        = bool
  default     = false
}

variable "backend_ssh_cidr" {
  type    = string
  default = null
}

variable "backend_container_port" {
  description = "Must match the backend's PORT env var / Dockerfile EXPOSE (3000 in the fullstack-template backend)."
  type        = number
  default     = 3000
}

variable "backend_db_name" {
  type    = string
  default = "job_seekers_hope"
}

variable "backend_db_username" {
  type    = string
  default = "job_seekers_hope_app"
}

