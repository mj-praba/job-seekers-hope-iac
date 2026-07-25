# Dedicated instance role (not the shared ecsInstanceRole) so the EIP self-association
# permission below doesn't need to widen a role anything else might use.
resource "aws_iam_role" "backend_instance" {
  name = "job-seekers-hope-backend-instance-role"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect    = "Allow"
        Principal = { Service = "ec2.amazonaws.com" }
        Action    = "sts:AssumeRole"
      }
    ]
  })
}

resource "aws_iam_role_policy_attachment" "backend_instance_ecs" {
  role       = aws_iam_role.backend_instance.name
  policy_arn = "arn:aws:iam::aws:policy/service-role/AmazonEC2ContainerServiceforEC2Role"
}

# Shell access via SSM Session Manager - SSH stays closed by default (var.backend_enable_ssh).
resource "aws_iam_role_policy_attachment" "backend_instance_ssm" {
  role       = aws_iam_role.backend_instance.name
  policy_arn = "arn:aws:iam::aws:policy/AmazonSSMManagedInstanceCore"
}

# ec2:AssociateAddress does not support resource-level scoping to a single allocation in all
# cases; Describe* is read-only. Condition-less but limited to the three EIP actions.
resource "aws_iam_role_policy" "backend_instance_eip_self_associate" {
  name = "eip-self-associate"
  role = aws_iam_role.backend_instance.id

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect   = "Allow"
        Action   = ["ec2:AssociateAddress", "ec2:DisassociateAddress", "ec2:DescribeAddresses"]
        Resource = "*"
      }
    ]
  })
}

resource "aws_iam_instance_profile" "backend_instance" {
  name = "job-seekers-hope-backend-instance-role"
  role = aws_iam_role.backend_instance.name
}

# ECS task execution role: pulls the container image, writes CloudWatch logs, and (via the
# inline policy below) reads the .env file this task's environmentFiles points at.
resource "aws_iam_role" "backend_execution" {
  name = "job-seekers-hope-backend-execution-role"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect    = "Allow"
        Principal = { Service = "ecs-tasks.amazonaws.com" }
        Action    = "sts:AssumeRole"
      }
    ]
  })
}

resource "aws_iam_role_policy_attachment" "backend_execution" {
  role       = aws_iam_role.backend_execution.name
  policy_arn = "arn:aws:iam::aws:policy/service-role/AmazonECSTaskExecutionRolePolicy"
}

resource "aws_iam_role_policy" "backend_execution_read_env_file" {
  name = "read-env-file"
  role = aws_iam_role.backend_execution.id

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Sid      = "GetEnvFile"
        Effect   = "Allow"
        Action   = ["s3:GetObject"]
        Resource = "${aws_s3_bucket.backend_deploy_config.arn}/backend/.env"
      },
      {
        # The ECS agent's environmentFiles download also calls ListBucket on the bucket
        # itself (not just GetObject on the key) - omitting this causes a 403 AccessDenied
        # on ListBucket and the task never starts.
        Sid      = "ListEnvFileBucket"
        Effect   = "Allow"
        Action   = ["s3:ListBucket"]
        Resource = aws_s3_bucket.backend_deploy_config.arn
      }
    ]
  })
}

# Lets ECS resolve the Postgres password (postgres-service.tf's `secrets` entry) at container
# startup without it ever appearing in plaintext in the task definition.
resource "aws_iam_role_policy" "backend_execution_read_db_secret" {
  name = "read-db-secret"
  role = aws_iam_role.backend_execution.id

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect   = "Allow"
        Action   = ["secretsmanager:GetSecretValue"]
        Resource = aws_secretsmanager_secret.backend_db_password.arn
      }
    ]
  })
}

# ECS task role: assumed by the running container itself. Scoped to exactly what the backend
# app needs at runtime - the blob-store bucket and SES sending.
resource "aws_iam_role" "backend_task" {
  name = "job-seekers-hope-backend-task-role"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect    = "Allow"
        Principal = { Service = "ecs-tasks.amazonaws.com" }
        Action    = "sts:AssumeRole"
      }
    ]
  })
}

resource "aws_iam_role_policy" "backend_task" {
  name = "job-seekers-hope-backend-task-policy"
  role = aws_iam_role.backend_task.id

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Sid      = "BlobStoreList"
        Effect   = "Allow"
        Action   = ["s3:ListBucket"]
        Resource = aws_s3_bucket.backend_blob_store.arn
      },
      {
        Sid      = "BlobStoreReadWrite"
        Effect   = "Allow"
        Action   = ["s3:GetObject", "s3:PutObject", "s3:DeleteObject"]
        Resource = "${aws_s3_bucket.backend_blob_store.arn}/*"
      },
      {
        Sid      = "SendMail"
        Effect   = "Allow"
        Action   = ["ses:SendEmail", "ses:SendRawEmail"]
        Resource = "*"
      }
    ]
  })
}
