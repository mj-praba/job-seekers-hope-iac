variable "service_name" {
  description = "e.g. \"job-seekers-hope-api\". Drives the task family, ECS service name, log group name, and ECR repo name defaults."
  type        = string
}

variable "component" {
  description = "Component tag value, applied to this service's ECS service, target group, and ECR repo alike."
  type        = string

  validation {
    condition     = contains(["ecs-api", "ecs-worker"], var.component)
    error_message = "component must be one of: ecs-api, ecs-worker."
  }
}

variable "cluster_arn" {
  type = string
}

variable "capacity_provider_name" {
  description = "This app's own dedicated capacity provider name, from this root's own modules/ecs-ec2-capacity call."
  type        = string
}

variable "network_mode" {
  description = "ECS task network mode."
  type        = string
  default     = "bridge"

  validation {
    condition     = contains(["bridge", "awsvpc"], var.network_mode)
    error_message = "network_mode must be \"bridge\" or \"awsvpc\"."
  }
}

variable "task_cpu" {
  type = string
}

variable "task_memory" {
  type = string
}

variable "container_name" {
  type    = string
  default = null
}

variable "container_image" {
  description = "No default - CD supplies the real value at apply time. The task definition ignores drift on this field regardless, since CD re-registers revisions directly via the AWS API on every deploy."
  type        = string
}

variable "container_port" {
  description = "Primary container port - used for the default port mapping and the target group."
  type        = number
}

variable "host_port" {
  description = "Fixed host port for the primary port mapping in bridge mode - for services reached directly on the instance (e.g. behind an on-host reverse proxy, or a public Elastic IP) instead of through an ALB's dynamic-port target group. null keeps the default dynamic host port (0). Ignored in awsvpc mode."
  type        = number
  default     = null
}

variable "additional_port_mappings" {
  type = list(object({
    container_port = number
    name           = string
  }))
  default = []
}

variable "volumes" {
  description = "Host-path volumes for the task, e.g. so a container's data survives container restarts (not instance replacement - the host path itself is on the instance's ephemeral root volume unless backed by a persistent EBS volume outside this module's scope)."
  type = list(object({
    name      = string
    host_path = string
  }))
  default = []
}

variable "mount_points" {
  description = "Mount points for the primary container, referencing volumes by name."
  type = list(object({
    source_volume  = string
    container_path = string
    read_only      = optional(bool, false)
  }))
  default = []
}

variable "secrets" {
  description = "Container env vars resolved from Secrets Manager (or SSM Parameter Store) at task startup, instead of appearing in plaintext in the task definition. value_from is the secret/parameter ARN - the execution role must be able to read it (e.g. secretsmanager:GetSecretValue)."
  type = list(object({
    name       = string
    value_from = string
  }))
  default = []
}

variable "environment" {
  type = list(object({
    name  = string
    value = string
  }))
  default = []
}

variable "env_file_s3_arn" {
  description = "Optional environmentFiles S3 entry, e.g. arn:aws:s3:::<bucket>/<app>/.env."
  type        = string
  default     = null
}

variable "task_role_arn" {
  type    = string
  default = null
}

variable "execution_role_arn" {
  type = string
}

variable "desired_count" {
  type    = number
  default = 1
}

variable "deployment_maximum_percent" {
  type    = number
  default = 200
}

variable "deployment_minimum_healthy_percent" {
  type    = number
  default = 100
}

variable "attach_load_balancer" {
  description = "false for services with no ALB target group, e.g. a worker, or an EIP-only setup."
  type        = bool
  default     = true
}

variable "target_group_port" {
  type    = number
  default = null
}

variable "health_check_path" {
  type    = string
  default = "/"
}

variable "vpc_id" {
  description = "Only used when attach_load_balancer = true."
  type        = string
  default     = null
}

variable "listener_rules" {
  description = "One aws_lb_listener_rule per entry, all forwarding to this module's single target group."
  type = list(object({
    listener_arn  = string
    priority      = number
    host_headers  = optional(list(string), [])
    path_patterns = optional(list(string), [])
  }))
  default = []
}

variable "ecr_repository_name" {
  description = "Override the ECR repository name. Defaults to service_name when null."
  type        = string
  default     = null
}

variable "create_ecr_repository" {
  description = "false for services using a public image with no custom repo."
  type        = bool
  default     = true
}

variable "ecr_lifecycle_keep_count" {
  type    = number
  default = 10
}

variable "log_retention_days" {
  type    = number
  default = 7
}

variable "enable_service_discovery" {
  type    = bool
  default = false
}

variable "service_discovery_namespace_id" {
  type    = string
  default = null
}

variable "service_discovery_dns_ttl" {
  type    = number
  default = 3600
}

variable "service_discovery_description" {
  type    = string
  default = null
}

variable "service_discovery_health_check_failure_threshold" {
  description = "Set to null to omit the health_check_custom_config block entirely."
  type        = number
  default     = null
}

variable "network_configuration" {
  description = "Required when network_mode = \"awsvpc\"."
  type = object({
    subnet_ids         = list(string)
    security_group_ids = list(string)
    assign_public_ip   = optional(bool, false)
  })
  default = null
}

variable "tags" {
  type    = map(string)
  default = {}
}
