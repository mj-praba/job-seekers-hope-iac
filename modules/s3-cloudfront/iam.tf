# Only created when a GitHub Actions role is supplied. Additive only: attached alongside
# whatever permissions and trust policy the named role already has - nothing about those
# is declared or touched here.
data "aws_iam_role" "github_cd" {
  count = var.github_actions_role_name != null ? 1 : 0
  name  = var.github_actions_role_name
}

data "aws_iam_policy_document" "github_cd_static_deploy" {
  count = var.github_actions_role_name != null ? 1 : 0

  statement {
    sid       = "ListStaticSiteBucket"
    effect    = "Allow"
    actions   = ["s3:ListBucket"]
    resources = [aws_s3_bucket.this.arn]
  }

  statement {
    sid    = "ReadWriteStaticSiteObjects"
    effect = "Allow"
    actions = [
      "s3:GetObject",
      "s3:PutObject",
      "s3:DeleteObject",
    ]
    resources = ["${aws_s3_bucket.this.arn}/*"]
  }

  statement {
    sid    = "InvalidateStaticSiteDistribution"
    effect = "Allow"
    actions = [
      "cloudfront:CreateInvalidation",
      "cloudfront:GetInvalidation",
    ]
    resources = [aws_cloudfront_distribution.this.arn]
  }
}

resource "aws_iam_policy" "github_cd_static_deploy" {
  count = var.github_actions_role_name != null ? 1 : 0

  name        = "github-cd-${var.bucket_name}-static-deploy"
  description = "Least-privilege S3 + CloudFront access for this site's static-deploy GitHub Actions workflow."
  policy      = data.aws_iam_policy_document.github_cd_static_deploy[0].json
}

resource "aws_iam_role_policy_attachment" "github_cd_static_deploy" {
  count = var.github_actions_role_name != null ? 1 : 0

  role       = data.aws_iam_role.github_cd[0].name
  policy_arn = aws_iam_policy.github_cd_static_deploy[0].arn
}
