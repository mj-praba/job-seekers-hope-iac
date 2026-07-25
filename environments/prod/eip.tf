# Stable public entry point for the backend API - no ALB. The instance self-associates this
# EIP at boot via user-data (see ec2-capacity.tf/templates/user-data-extra.sh.tpl), so ASG
# replacements keep the same IP.
resource "aws_eip" "backend" {
  domain = "vpc"

  tags = {
    Name      = "job-seekers-hope-backend"
    Component = "networking"
  }
}
