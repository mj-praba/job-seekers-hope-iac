# job-seekers-hope-infra

Terraform for the job-seekers-hope application's AWS infrastructure.

## Layout

| Path                          | What it is                                                                          |
| ------------------------------ | ------------------------------------------------------------------------------------ |
| `modules/s3-static-site`       | S3 bucket configured for public static-website hosting (currently used by the frontend) |
| `modules/s3-cloudfront`        | Private S3 bucket + CloudFront (OAC) for static site hosting - blocked on AWS account CloudFront verification, see below |
| `modules/vpc`                  | Minimal public-subnets-only VPC (no NAT)                                            |
| `modules/ecs-ec2-capacity`     | ECS-on-EC2 capacity provider: launch template + ASG                                 |
| `modules/ecs-ec2-service`      | ECS service + task definition, optional ALB attachment, ECR repo, log group         |
| `environments/prod`            | The one root module wiring everything above together                               |

## Current scope

Frontend (S3 static hosting) and backend (ECS-on-EC2 + a Postgres container on the same
instance) are both managed here.

## Frontend: S3 static-website hosting (temporary - no CDN/SSL)

CloudFront is currently **blocked**: `CreateDistributionWithTags` returns `403 AccessDenied:
Your account must be verified before you can add new CloudFront resources` on this AWS
account. Until AWS Support verifies the account, `environments/prod/main.tf` uses
`modules/s3-static-site` instead - a public bucket with S3 website hosting (HTTP only, no
CDN, no SSL). Once verified, switch back to `modules/s3-cloudfront` (kept in the repo,
private bucket + CloudFront OAC + optional custom domain/ACM alias - see that module's
`variables.tf`).

## Backend: ECS-on-EC2 + Elastic IP (no ALB), Postgres as a container (not RDS)

Single EC2 instance (t3.small, on-demand) in a dedicated VPC, running two ECS services in
bridge mode on fixed host ports - no ALB, both reached directly via a static Elastic IP:

```
Internet
   │
   ├── :80   → job-seekers-hope-api       (ECS, bridge, host port 80  → container port 3000)
   └── :5432 → job-seekers-hope-postgres  (ECS, bridge, host port 5432, public by request)
                 pgvector/pgvector:pg16, data on host path /opt/postgres/data
```

RDS was tried first but `CreateDBInstance` was rejected on this AWS account
(`FreeTierRestrictionError: backup retention period exceeds the maximum available to free
tier customers`), and this account can't use paid RDS features. Postgres now runs as a
regular ECS-on-EC2 container instead - same `pgvector/pgvector:pg16` image as local dev
(`backend/docker-compose.yml`), on the same instance as the API.

**Durability trade-off**: `/opt/postgres/data` is a host-path volume on the instance's root
EBS volume (set up by `templates/user-data-extra.sh.tpl`). It survives container restarts but
**not** instance replacement (ASG health-check failure, AZ rebalance, a future Spot switch) -
there's no automated backup like RDS provided. Take manual `pg_dump` backups periodically if
this data matters long-term, or revisit RDS once the account is out of Free Tier.

**Postgres is publicly reachable** on the Elastic IP, port 5432 (by request, for direct DB
client access) - protected only by its own password (`terraform output -raw
backend_db_password`), no network-level restriction. Narrow `cidr_ipv4` in
`security-groups.tf` (`backend_postgres` rule) to your own IP if that's a concern.

Cost is roughly EC2 (~$15/mo for t3.small on-demand) + EIP (~$3.65/mo once unattached, free
while attached to a running instance) + minor EBS/log storage. No ALB, no NAT, no RDS.

### Manual prerequisites before this actually runs anything

1. **Build and push an image.** `environments/prod` creates an empty ECR repository
   (`job-seekers-hope-api`) and points the task definition at `<account>.dkr.ecr.<region>
   .amazonaws.com/job-seekers-hope-api:latest`. Nothing is pushed there yet - the ECS task
   will fail to start until `job-seekers-hope-frontend`'s sibling backend repo builds
   `backend/Dockerfile` and pushes an image tagged `:latest` (see `backend-cd.yml` in the
   `fullstack-template` repo this was extracted from for the GHCR-based default, or adapt it
   to push to this ECR repo via OIDC instead).
2. **Prep the Postgres data directory on any already-running instance.** User-data only runs
   on first boot, so an instance launched before `templates/user-data-extra.sh.tpl` grew the
   `mkdir -p /opt/postgres/data && chown -R 999:999 /opt/postgres/data` step won't have it.
   Either SSM into the instance and run those two commands manually, or terminate the instance
   (`aws ec2 terminate-instances`) and let the ASG (size 1) launch a replacement with the
   current launch template/user-data.
3. **Upload the backend `.env` file.** Terraform only creates the (private, versioned)
   `job-seekers-hope-backend-deploy-config` bucket - it does not create or upload the actual
   `.env` file, since that holds real secrets (JWT secrets, MS SSO client secret,
   `GROQ_API_KEY`) that shouldn't pass through Terraform state. After first apply:
   ```bash
   terraform output -raw backend_db_password   # Postgres password (also container env var)
   terraform output backend_db_host backend_db_port backend_db_name backend_db_username
   terraform output backend_blob_store_bucket_name
   ```
   Build a `.env` from `backend/.env.example` (in the fullstack-template repo) with those
   values filled in - `DB_HOST` = `172.17.0.1` (the docker bridge gateway; the api and
   postgres containers run on the same host) rather than the public IP, `AWS_S3_BUCKET` from
   the blob-store output, `AWS_REGION` = `us-east-1` - then upload it:
   ```bash
   aws s3 cp backend.env s3://job-seekers-hope-backend-deploy-config/backend/.env
   ```
4. **Run migrations** (`pnpm migration:run` from the backend, pointed at `backend_db_host`
   from the outside or `172.17.0.1` from inside the API container) and enable pgvector once
   connected: `CREATE EXTENSION IF NOT EXISTS vector;`.

### Notes on the design

- **Single instance, no ALB**: fixed host ports mean deployments are stop-then-start
  (`deployment_maximum_percent = 100`, `deployment_minimum_healthy_percent = 0`) - the old
  task must free port 80 before the new one can bind. Brief downtime per deploy; acceptable
  for a low-traffic personal project. Revisit with an ALB + dynamic ports if that changes.
  Fixed host ports are baked into the first task-definition revision - Terraform ignores
  `container_definitions` drift afterwards (CD re-registers revisions directly via the AWS
  API), so any future CD workflow must keep `hostPort = 80` when registering new revisions.
- **Postgres as a container, both services fixed to the same host ports**: the api
  (port 80/3000) and postgres (port 5432) services are independent ECS services with no
  ordering guarantee between them - if the api container starts before postgres is ready, it
  needs to retry the DB connection with backoff (typical for TypeORM). The blob-store S3
  bucket still has `prevent_destroy` set, same as before.
- **`backend_use_spot`** (default `false`) and **`backend_enable_ssh`** (default `false`,
  SSM Session Manager is available via the instance's IAM role instead) are there if you want
  to trade reliability for cost or need shell access - see `environments/prod/variables.tf`.

## Usage

```bash
cd environments/prod
terraform init
terraform plan
terraform apply
```

State is local (`terraform.tfstate`, gitignored) — there's no remote backend configured yet.
If more than one person/machine applies this, move state to an S3 backend with locking
before that becomes a problem.

**Note**: this is being applied against AWS account `380906049942`, via the AWS CLI's
`default` profile. It's a Free Tier account, which is why RDS (backup retention limit),
Route 53 domain registration, and CloudFront (needs account verification) all reject
requests on it - factor that in before assuming any AWS feature is available here.
