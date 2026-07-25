# Self-associate the stable EIP so the public IP survives ASG replacements. AWS CLI v2 ships
# on the ECS-optimized AL2023 AMI; IMDSv2 for the instance id.
TOKEN=$(curl -s -X PUT "http://169.254.169.254/latest/api/token" -H "X-aws-ec2-metadata-token-ttl-seconds: 300")
INSTANCE_ID=$(curl -s -H "X-aws-ec2-metadata-token: $TOKEN" "http://169.254.169.254/latest/meta-data/instance-id")
aws ec2 associate-address \
  --region "${aws_region}" \
  --allocation-id "${eip_allocation_id}" \
  --instance-id "$INSTANCE_ID" \
  --allow-reassociation

# Host-path volume for the Postgres container (see postgres-service.tf) - survives container
# restarts, but lives on this instance's root volume, so it does NOT survive instance
# replacement (ASG health-check failure, AZ rebalance, a future Spot switch). UID 999 is the
# postgres image's default non-root user.
mkdir -p /opt/postgres/data
chown -R 999:999 /opt/postgres/data
