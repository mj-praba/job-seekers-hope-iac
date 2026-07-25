# Private bucket — no static-website-hosting config. CloudFront reaches it via Origin
# Access Control against the REST endpoint, never a public .s3-website-*.amazonaws.com endpoint.
resource "aws_s3_bucket" "this" {
  bucket = var.bucket_name

  tags = merge(var.tags, { Component = "s3" })

  # Site content nobody wants a stray terraform destroy/replace to wipe.
  lifecycle {
    prevent_destroy = true
  }
}

resource "aws_s3_bucket_versioning" "this" {
  bucket = aws_s3_bucket.this.id
  versioning_configuration {
    status = var.enable_bucket_versioning ? "Enabled" : "Suspended"
  }
}

resource "aws_s3_bucket_public_access_block" "this" {
  bucket = aws_s3_bucket.this.id

  block_public_acls       = true
  ignore_public_acls      = true
  block_public_policy     = true
  restrict_public_buckets = true
}

resource "aws_s3_bucket_server_side_encryption_configuration" "this" {
  bucket = aws_s3_bucket.this.id

  rule {
    apply_server_side_encryption_by_default {
      sse_algorithm = "AES256"
    }
  }
}

# Disables ACLs entirely (bucket policy is the only access path) - closes off the "someone sets
# a public ACL on one object" risk that a bucket-policy-only setup doesn't fully prevent otherwise.
resource "aws_s3_bucket_ownership_controls" "this" {
  bucket = aws_s3_bucket.this.id
  rule {
    object_ownership = "BucketOwnerEnforced"
  }
}

resource "aws_cloudfront_origin_access_control" "this" {
  name                              = "${var.bucket_name}-oac"
  origin_access_control_origin_type = "s3"
  signing_behavior                  = "always"
  signing_protocol                  = "sigv4"
}

locals {
  comment = coalesce(var.comment, "${coalesce(var.domain_name, var.bucket_name)} static site (S3 + CloudFront)")
}

resource "aws_cloudfront_distribution" "this" {
  enabled             = true
  is_ipv6_enabled     = true
  default_root_object = "index.html"
  price_class         = var.price_class
  comment             = local.comment
  aliases             = var.enable_alias ? [var.domain_name] : []
  web_acl_id          = var.web_acl_id != "" ? var.web_acl_id : null

  origin {
    domain_name              = aws_s3_bucket.this.bucket_regional_domain_name
    origin_id                = "s3-${var.bucket_name}"
    origin_access_control_id = aws_cloudfront_origin_access_control.this.id
  }

  default_cache_behavior {
    allowed_methods        = ["GET", "HEAD"]
    cached_methods         = ["GET", "HEAD"]
    target_origin_id       = "s3-${var.bucket_name}"
    viewer_protocol_policy = "redirect-to-https"
    compress               = true
    cache_policy_id        = var.cache_policy_id
  }

  # Bucket policy grants GetObject only (no ListBucket to CloudFront), so a missing key comes
  # back as 403, not 404 - both must map to index.html for SPA client-side routing to work.
  dynamic "custom_error_response" {
    for_each = var.spa_routing ? [403, 404] : []
    content {
      error_code            = custom_error_response.value
      response_code         = 200
      response_page_path    = "/index.html"
      error_caching_min_ttl = 0
    }
  }

  restrictions {
    geo_restriction {
      restriction_type = "none"
    }
  }

  viewer_certificate {
    cloudfront_default_certificate = var.enable_alias ? null : true
    acm_certificate_arn            = var.enable_alias ? var.acm_certificate_arn : null
    ssl_support_method             = var.enable_alias ? "sni-only" : null
    minimum_protocol_version       = var.enable_alias ? "TLSv1.2_2021" : null
  }

  tags = merge(var.tags, { Component = "cloudfront" })
}

# CloudFront-only read access, scoped to this specific distribution via SourceArn.
data "aws_iam_policy_document" "bucket_policy" {
  statement {
    sid     = "AllowCloudFrontServicePrincipalReadOnly"
    effect  = "Allow"
    actions = ["s3:GetObject"]

    resources = ["${aws_s3_bucket.this.arn}/*"]

    principals {
      type        = "Service"
      identifiers = ["cloudfront.amazonaws.com"]
    }

    condition {
      test     = "StringEquals"
      variable = "AWS:SourceArn"
      values   = [aws_cloudfront_distribution.this.arn]
    }
  }
}

resource "aws_s3_bucket_policy" "this" {
  bucket = aws_s3_bucket.this.id
  policy = data.aws_iam_policy_document.bucket_policy.json
}
