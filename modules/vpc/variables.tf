variable "name" {
  description = "Name tag prefix for the VPC and everything in it, e.g. \"job-seekers-hope\"."
  type        = string
}

variable "cidr" {
  description = "VPC CIDR block."
  type        = string
}

variable "public_subnet_cidrs" {
  description = "One CIDR per public subnet, paired index-wise with azs."
  type        = list(string)
}

variable "azs" {
  description = "One AZ per public subnet, paired index-wise with public_subnet_cidrs."
  type        = list(string)

  validation {
    condition     = length(var.azs) == length(var.public_subnet_cidrs)
    error_message = "azs and public_subnet_cidrs must have the same length."
  }
}

variable "tags" {
  type    = map(string)
  default = {}
}
