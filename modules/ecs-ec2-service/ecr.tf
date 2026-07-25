resource "aws_ecr_repository" "this" {
  count = var.create_ecr_repository ? 1 : 0

  name                 = coalesce(var.ecr_repository_name, var.service_name)
  image_tag_mutability = "MUTABLE"

  tags = merge(var.tags, {
    Component = var.component
  })

  encryption_configuration {
    encryption_type = "AES256"
  }

  image_scanning_configuration {
    scan_on_push = false
  }
}

resource "aws_ecr_lifecycle_policy" "this" {
  count = var.create_ecr_repository ? 1 : 0

  repository = aws_ecr_repository.this[0].name

  policy = jsonencode({
    rules = [
      {
        rulePriority = 1
        description  = "Expire all but the most recent ${var.ecr_lifecycle_keep_count} images"
        selection = {
          tagStatus   = "any"
          countType   = "imageCountMoreThan"
          countNumber = var.ecr_lifecycle_keep_count
        }
        action = {
          type = "expire"
        }
      }
    ]
  })
}
