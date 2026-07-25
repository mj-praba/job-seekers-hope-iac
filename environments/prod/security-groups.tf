# Single EC2 instance running both the API and Postgres containers directly on host ports
# 80 and 5432 - no ALB, reached via the Elastic IP in eip.tf.
resource "aws_security_group" "backend_instance" {
  name = "job-seekers-hope-backend-ec2-instance"
  # Unchanged from the original description - AWS security-group descriptions are immutable,
  # and changing it would force a replace of an SG already attached to a running instance.
  description = "Backend API container instance"
  vpc_id      = module.backend_vpc.vpc_id

  tags = {
    Name      = "job-seekers-hope-backend-ec2-instance"
    Component = "ec2-capacity"
  }
}

resource "aws_vpc_security_group_ingress_rule" "backend_http" {
  security_group_id = aws_security_group.backend_instance.id
  description       = "API (host port 80, mapped from container port ${var.backend_container_port})"
  from_port         = 80
  to_port           = 80
  ip_protocol       = "tcp"
  cidr_ipv4         = "0.0.0.0/0"
}

# Public by request - lets you connect a DB client directly to the instance's Elastic IP.
# Postgres has no network-level access control beyond its own password auth once this is open;
# use a strong generated password (random_password.backend_db) and consider narrowing
# cidr_ipv4 to your own IP if this becomes a concern.
resource "aws_vpc_security_group_ingress_rule" "backend_postgres" {
  security_group_id = aws_security_group.backend_instance.id
  description       = "Postgres (public, host port 5432)"
  from_port         = 5432
  to_port           = 5432
  ip_protocol       = "tcp"
  cidr_ipv4         = "0.0.0.0/0"
}

resource "aws_vpc_security_group_ingress_rule" "backend_ssh" {
  count = var.backend_enable_ssh ? 1 : 0

  security_group_id = aws_security_group.backend_instance.id
  description       = "SSH (opt-in; prefer SSM Session Manager)"
  from_port         = 22
  to_port           = 22
  ip_protocol       = "tcp"
  cidr_ipv4         = var.backend_ssh_cidr
}

resource "aws_vpc_security_group_egress_rule" "backend_instance_all" {
  security_group_id = aws_security_group.backend_instance.id
  description       = "All outbound"
  ip_protocol       = "-1"
  cidr_ipv4         = "0.0.0.0/0"
}
