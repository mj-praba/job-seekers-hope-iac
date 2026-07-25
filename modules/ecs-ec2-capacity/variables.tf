variable "name" {
  description = "e.g. \"job-seekers-hope-backend-ec2\". Drives the ASG name, launch template name_prefix, capacity provider name, and instance Name tag."
  type        = string
}

variable "vpc_id" {
  type = string
}

variable "subnet_ids" {
  type = list(string)
}

variable "security_group_ids" {
  description = "Created outside this module, in the app root's own security-groups.tf - ingress rules are too bespoke per app to belong in a generic capacity module. This module only attaches whatever SG IDs it's given."
  type        = list(string)
}

variable "instance_type" {
  type    = string
  default = "t3a.small"
}

variable "min_size" {
  type    = number
  default = 1
}

variable "desired_capacity" {
  type    = number
  default = 1
}

variable "max_size" {
  type    = number
  default = 1
}

variable "create_ecs_instance_role" {
  description = "ecsInstanceRole is an account-wide singleton - exactly one app root should set this true (the first one to need it); every other root leaves it false and this module does a data-source lookup of the existing role/instance-profile instead."
  type        = bool
  default     = false
}

variable "use_external_instance_profile" {
  description = "When true, the shared ecsInstanceRole is neither created nor looked up - the root supplies its own role/profile via instance_profile_arn (e.g. for EIP self-association permissions that shouldn't widen a shared role). Static bool (not inferred from instance_profile_arn) because the data sources' count must be plannable while the profile ARN is still unknown."
  type        = bool
  default     = false
}

variable "instance_profile_arn" {
  description = "Externally-managed instance profile ARN. Required (and only used) when use_external_instance_profile = true."
  type        = string
  default     = null
}

variable "use_spot" {
  description = "Request Spot instances in the launch template (one-time, terminate on interruption). The ASG replaces reclaimed instances automatically. Default false = on-demand."
  type        = bool
  default     = false
}

variable "user_data_extra" {
  description = "Extra shell script appended verbatim after the base ECS-cluster-registration user_data (e.g. EIP self-association, on-host reverse proxy). Empty string leaves the rendered user_data byte-identical to before this variable existed."
  type        = string
  default     = ""
}

variable "ecs_cluster_name" {
  description = "Injected into the launch template's user_data."
  type        = string
}

variable "protect_from_scale_in" {
  type    = bool
  default = true
}

variable "managed_termination_protection" {
  type    = string
  default = "ENABLED"
}

variable "managed_scaling_target_capacity" {
  type    = number
  default = 100
}

variable "managed_scaling_min_step" {
  type    = number
  default = 1
}

variable "managed_scaling_max_step" {
  type    = number
  default = 1
}

variable "tags" {
  description = "Merged manually into both the launch template's tag_specifications and the ASG's tag blocks, since neither inherits provider default_tags."
  type        = map(string)
  default     = {}
}
