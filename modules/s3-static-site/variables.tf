variable "bucket_name" {
  description = "Name of the existing S3 bucket to manage for static website hosting"
  type        = string
}

variable "index_document" {
  description = "Website index document"
  type        = string
  default     = "index.html"
}

variable "error_document" {
  description = "Website error document"
  type        = string
  default     = "error.html"
}

variable "tags" {
  description = "Tags applied to the bucket"
  type        = map(string)
  default     = {}
}
