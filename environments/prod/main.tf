# CloudFront is blocked on this AWS account until AWS Support verifies it
# (CreateDistributionWithTags -> 403 AccessDenied: "Your account must be
# verified before you can add new CloudFront resources"). Falling back to
# plain S3 static-website hosting (HTTP only, no CDN/SSL) so the site is live
# now; switch back to modules/s3-cloudfront once the account is verified.
module "frontend" {
  source = "../../modules/s3-static-site"

  bucket_name = "job-seekers-hope-frontend"

  tags = {
    Project     = "job-seekers-hope"
    Environment = "prod"
    ManagedBy   = "terraform"
  }
}

# Private blob storage for the backend (resumes, cover letters, generated
# documents, etc.) - no website hosting, no CloudFront, no public access.
# The backend accesses it via its own IAM role once that infra exists
# (modules/ecs-ec2 is currently just a stub); no bucket policy is attached here.
resource "aws_s3_bucket" "backend_blob_store" {
  bucket = "job-seekers-hope-backend-blob-store"

  tags = {
    Project     = "job-seekers-hope"
    Environment = "prod"
    ManagedBy   = "terraform"
    Component   = "s3"
  }

  # Holds user-uploaded/generated content nobody wants a stray
  # terraform destroy/replace to wipe.
  lifecycle {
    prevent_destroy = true
  }
}

resource "aws_s3_bucket_versioning" "backend_blob_store" {
  bucket = aws_s3_bucket.backend_blob_store.id
  versioning_configuration {
    status = "Enabled"
  }
}

resource "aws_s3_bucket_public_access_block" "backend_blob_store" {
  bucket = aws_s3_bucket.backend_blob_store.id

  block_public_acls       = true
  ignore_public_acls      = true
  block_public_policy     = true
  restrict_public_buckets = true
}

resource "aws_s3_bucket_server_side_encryption_configuration" "backend_blob_store" {
  bucket = aws_s3_bucket.backend_blob_store.id

  rule {
    apply_server_side_encryption_by_default {
      sse_algorithm = "AES256"
    }
  }
}

resource "aws_s3_bucket_ownership_controls" "backend_blob_store" {
  bucket = aws_s3_bucket.backend_blob_store.id
  rule {
    object_ownership = "BucketOwnerEnforced"
  }
}
