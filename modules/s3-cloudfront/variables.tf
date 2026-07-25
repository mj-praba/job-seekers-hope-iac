variable "bucket_name" {
  description = "S3 bucket name backing the site. Must not contain dots: CloudFront's OAC-based S3 origin always addresses the bucket virtual-hosted-style (bucket.s3.region.amazonaws.com), and dotted bucket names break SSL/routing for that addressing style over HTTPS."
  type        = string
}

variable "domain_name" {
  description = "Custom domain intended for this site, used only for the default CloudFront comment. Required when enable_alias = true (it becomes the alias itself). DNS for this domain is never managed by this module."
  type        = string
  default     = null
}

variable "enable_alias" {
  description = "When true, adds domain_name as a CloudFront alias and uses acm_certificate_arn for the viewer certificate. When false (default), the distribution serves only via its own *.cloudfront.net domain with the CloudFront default certificate."
  type        = bool
  default     = false

  validation {
    condition     = !var.enable_alias || var.domain_name != null
    error_message = "domain_name is required when enable_alias = true."
  }
}

variable "acm_certificate_arn" {
  description = "Existing ISSUED ACM certificate ARN (us-east-1, for CloudFront) covering domain_name. Required when enable_alias = true."
  type        = string
  default     = null

  validation {
    condition     = !var.enable_alias || var.acm_certificate_arn != null
    error_message = "acm_certificate_arn is required when enable_alias = true."
  }
}

variable "price_class" {
  description = "CloudFront price class."
  type        = string
  default     = "PriceClass_100"
}

variable "enable_bucket_versioning" {
  description = "Enable S3 bucket versioning, giving a rollback path if a bad deploy overwrites site files."
  type        = bool
  default     = true
}

variable "spa_routing" {
  description = "When true, 403/404 responses are rewritten to /index.html with a 200 so client-side routing works — correct only for single-page apps that own all client-side routes. Set false for content sites where a missing page should actually 404 rather than silently redirect to the homepage."
  type        = bool
  default     = true
}

variable "cache_policy_id" {
  description = "CloudFront cache policy ID. Look this up via a data \"aws_cloudfront_cache_policy\" in the caller so this module doesn't assume a specific policy name exists."
  type        = string
}

variable "comment" {
  description = "CloudFront distribution comment. Defaults to \"<domain_name or bucket_name> static site (S3 + CloudFront)\" when unset."
  type        = string
  default     = null
}

variable "web_acl_id" {
  description = "Optional WAF Web ACL ARN to associate with the distribution. Empty string omits the argument."
  type        = string
  default     = ""
}

variable "github_actions_role_name" {
  description = "Existing IAM role that a GitHub Actions deploy workflow assumes. When set, this module creates a least-privilege S3+CloudFront deploy policy and attaches it to the named role. When null (default), no IAM resources are created at all."
  type        = string
  default     = null
}

variable "tags" {
  description = "Tags applied to the bucket and distribution (merged with a per-resource Component tag)"
  type        = map(string)
  default     = {}
}
