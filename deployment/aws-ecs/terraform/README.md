# FastAPI Terraform Infrastructure

This Terraform configuration deploys a complete FastAPI application infrastructure on AWS.

## Architecture
```
Internet
    ↓ HTTPS
CloudFront (Global CDN)
    ↓ HTTP
Application Load Balancer (ap-south-1)
    ↓
ECS Fargate Service (2+ tasks)
    ↓
FastAPI Containers
```

## Prerequisites

1. **Terraform** >= 1.0
2. **AWS CLI** configured with credentials
3. **Docker image** pushed to ECR

## Usage

### Initialize Terraform
```bash
cd terraform
terraform init
```

### Plan Infrastructure
```bash
terraform plan
```

### Deploy Infrastructure
```bash
terraform apply
```

Type `yes` when prompted.

**Deployment time:** 10-15 minutes

### Get Outputs
```bash
terraform output
```

### Access Your Application
```bash
# Get CloudFront URL
terraform output cloudfront_url

# Get ALB URL
terraform output alb_url

# View deployment summary
terraform output deployment_summary
```

### View Logs
```bash
# Get log command
terraform output -raw deployment_summary | jq -r '.logs_command'

# Or directly
aws logs tail /ecs/fastapi-app --follow --region ap-south-1
```

### Update Infrastructure
```bash
# After making changes to .tf files
terraform plan
terraform apply
```

### Destroy Infrastructure
```bash
terraform destroy
```

Type `yes` when prompted.

**Destruction time:** 5-10 minutes

## What Gets Created

- ✅ ECR Repository
- ✅ ECS Cluster (Fargate)
- ✅ ECS Service with 2 tasks
- ✅ Application Load Balancer
- ✅ Target Group with health checks
- ✅ CloudFront Distribution
- ✅ Security Groups
- ✅ IAM Roles
- ✅ CloudWatch Log Groups
- ✅ Auto Scaling (CPU & Memory based)
- ✅ CloudWatch Alarms

## Customization

Edit `terraform.tfvars` to customize:
```hcl
desired_count = 4          # Number of ECS tasks
task_cpu      = "512"      # Increase CPU
task_memory   = "1024"     # Increase memory
max_capacity  = 20         # Max auto-scale tasks
```

## Cost Estimate

| Service | Monthly Cost |
|---------|--------------|
| ECS Fargate (2 tasks) | ~$15-20 |
| Application Load Balancer | ~$16 |
| CloudFront | ~$1-5 |
| CloudWatch | ~$1 |
| **Total** | **~$35-45/month** |

## Troubleshooting

### View Service Status
```bash
aws ecs describe-services \
    --cluster $(terraform output -raw ecs_cluster_name) \
    --services $(terraform output -raw ecs_service_name) \
    --region ap-south-1
```

### View Target Health
```bash
TG_ARN=$(aws elbv2 describe-target-groups \
    --names fastapi-app-tg \
    --query 'TargetGroups[0].TargetGroupArn' \
    --output text \
    --region ap-south-1)

aws elbv2 describe-target-health \
    --target-group-arn $TG_ARN \
    --region ap-south-1
```

### Invalidate CloudFront Cache
```bash
aws cloudfront create-invalidation \
    --distribution-id $(terraform output -raw cloudfront_distribution_id) \
    --paths "/*"
```

## Terraform State

By default, state is stored locally. For production, use remote state:

### S3 Backend Configuration

Add to `main.tf`:
```hcl
terraform {
  backend "s3" {
    bucket         = "your-terraform-state-bucket"
    key            = "fastapi/terraform.tfstate"
    region         = "ap-south-1"
    encrypt        = true
    dynamodb_table = "terraform-locks"
  }
}
```

## CI/CD Integration

### GitHub Actions
```yaml
- name: Terraform Apply
  run: |
    cd terraform
    terraform init
    terraform apply -auto-approve
```

## Security Best Practices

1. ✅ Use AWS Secrets Manager for sensitive data
2. ✅ Enable AWS WAF on CloudFront
3. ✅ Use private subnets for ECS tasks
4. ✅ Enable VPC Flow Logs
5. ✅ Use least privilege IAM roles

## License

MIT