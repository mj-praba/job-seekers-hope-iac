output "bucket_name" {
  value = aws_s3_bucket.this.id
}

output "bucket_arn" {
  value = aws_s3_bucket.this.arn
}

output "bucket_regional_domain_name" {
  value = aws_s3_bucket.this.bucket_regional_domain_name
}

output "oac_id" {
  value = aws_cloudfront_origin_access_control.this.id
}

output "cloudfront_distribution_id" {
  value = aws_cloudfront_distribution.this.id
}

output "cloudfront_distribution_arn" {
  value = aws_cloudfront_distribution.this.arn
}

output "cloudfront_distribution_domain_name" {
  value = aws_cloudfront_distribution.this.domain_name
}

output "iam_policy_arn" {
  value = var.github_actions_role_name != null ? aws_iam_policy.github_cd_static_deploy[0].arn : null
}
