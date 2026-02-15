# FastAPI CloudFormation Infrastructure

Deploy complete FastAPI infrastructure on AWS using CloudFormation in ap-south-1 region.

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

1. **AWS CLI** configured with credentials
2. **jq** installed (`sudo apt install jq` or `brew install jq`)
3. **Docker image** pushed to ECR (optional, can use placeholder)

## Quick Start

### 1. Update Parameters

Edit `parameters.json`:
```json
{
  "ParameterKey": "ContainerImage",
  "ParameterValue": "YOUR_ACCOUNT_ID.dkr.ecr.ap-south-1.amazonaws.com/fastapi-app:latest"
}
```

### 2. Deploy Infrastructure
```bash
chmod +x deploy.sh
./deploy.sh
```

**Deployment time:** 10-15 minutes

### 3. Destroy Infrastructure
```bash
chmod +x destroy.sh
./destroy.sh
```

**Destruction time:** 5-10 minutes

## Manual Deployment

### Via AWS CLI
```bash
# Get VPC and Subnets
VPC_ID=$(aws ec2 describe-vpcs --filters "Name=isDefault,Values=true" --query "Vpcs[0].VpcId" --output text --region ap-south-1)
SUBNET_1=$(aws ec2 describe-subnets --filters "Name=vpc-id,Values=$VPC_ID" --query "Subnets[0].SubnetId" --output text --region ap-south-1)
SUBNET_2=$(aws ec2 describe-subnets --filters "Name=vpc-id,Values=$VPC_ID" --query "Subnets[1].SubnetId" --output text --region ap-south-1)

# Create stack
aws cloudformation create-stack \
    --stack-name fastapi-infrastructure \
    --template-body file://infrastructure.yaml \
    --parameters file://parameters.json \
    --capabilities CAPABILITY_NAMED_IAM \
    --region ap-south-1

# Wait for completion
aws cloudformation wait stack-create-complete \
    --stack-name fastapi-infrastructure \
    --region ap-south-1

# Get outputs
aws cloudformation describe-stacks \
    --stack-name fastapi-infrastructure \
    --region ap-south-1 \
    --query 'Stacks[0].Outputs'
```

### Via AWS Console

1. Go to **CloudFormation Console** (ap-south-1)
2. Click **Create stack** → **With new resources**
3. Upload `infrastructure.yaml`
4. Fill in parameters
5. Check **I acknowledge that AWS CloudFormation might create IAM resources**
6. Click **Create stack**

## What Gets Created

- ✅ ECR Repository
- ✅ ECS Cluster (Fargate)
- ✅ ECS Service with auto-scaling
- ✅ Application Load Balancer
- ✅ Target Group with health checks
- ✅ CloudFront Distribution
- ✅ Security Groups (ALB + ECS)
- ✅ IAM Roles (Execution + Task)
- ✅ CloudWatch Log Groups
- ✅ CloudWatch Alarms (CPU, Memory, Response Time)

## Stack Outputs

After deployment, you'll get:

- **ECR Repository URI**: For pushing Docker images
- **ALB URL**: Direct access to load balancer
- **CloudFront URL**: HTTPS URL for production
- **Health Check URL**: Test endpoint
- **API Docs URL**: FastAPI documentation
- **Logs Command**: View CloudWatch logs

## Update Stack
```bash
# Modify parameters.json
vim parameters.json

# Run deploy script again
./deploy.sh
```

Or via AWS CLI:
```bash
aws cloudformation update-stack \
    --stack-name fastapi-infrastructure \
    --template-body file://infrastructure.yaml \
    --parameters file://parameters.json \
    --capabilities CAPABILITY_NAMED_IAM \
    --region ap-south-1
```

## View Stack Status
```bash
# Stack status
aws cloudformation describe-stacks \
    --stack-name fastapi-infrastructure \
    --region ap-south-1 \
    --query 'Stacks[0].StackStatus'

# Stack events
aws cloudformation describe-stack-events \
    --stack-name fastapi-infrastructure \
    --region ap-south-1 \
    --max-items 20

# Stack outputs
aws cloudformation describe-stacks \
    --stack-name fastapi-infrastructure \
    --region ap-south-1 \
    --query 'Stacks[0].Outputs[*].[OutputKey,OutputValue]' \
    --output table
```

## Monitoring

### View Logs
```bash
aws logs tail /ecs/fastapi-app --follow --region ap-south-1
```

### Check Service Health
```bash
# ECS Service
aws ecs describe-services \
    --cluster fastapi-app-cluster \
    --services fastapi-app-service \
    --region ap-south-1

# Target Health
TG_ARN=$(aws cloudformation describe-stacks \
    --stack-name fastapi-infrastructure \
    --query 'Stacks[0].Outputs[?OutputKey==`TargetGroupARN`].OutputValue' \
    --output text --region ap-south-1)

aws elbv2 describe-target-health \
    --target-group-arn $TG_ARN \
    --region ap-south-1
```

### CloudWatch Alarms
```bash
aws cloudwatch describe-alarms \
    --alarm-name-prefix fastapi-app \
    --region ap-south-1
```

## Troubleshooting

### Stack Creation Failed
```bash
# View failure reason
aws cloudformation describe-stack-events \
    --stack-name fastapi-infrastructure \
    --region ap-south-1 \
    --query 'StackEvents[?ResourceStatus==`CREATE_FAILED`]'

# Delete failed stack
aws cloudformation delete-stack \
    --stack-name fastapi-infrastructure \
    --region ap-south-1
```

### Service Not Starting
```bash
# Check ECS service events
aws ecs describe-services \
    --cluster fastapi-app-cluster \
    --services fastapi-app-service \
    --region ap-south-1 \
    --query 'services[0].events[0:5]'

# Check task logs
aws logs tail /ecs/fastapi-app --since 10m --region ap-south-1
```

### 504 Gateway Timeout
```bash
# Invalidate CloudFront cache
CF_ID=$(aws cloudformation describe-stacks \
    --stack-name fastapi-infrastructure \
    --query 'Stacks[0].Outputs[?OutputKey==`CloudFrontDistributionId`].OutputValue' \
    --output text --region ap-south-1)

aws cloudfront create-invalidation \
    --distribution-id $CF_ID \
    --paths "/*"
```

## Cost Estimate

| Service | Monthly Cost |
|---------|--------------|
| ECS Fargate (2 tasks) | ~$15-20 |
| Application Load Balancer | ~$16 |
| CloudFront | ~$1-5 |
| CloudWatch | ~$1 |
| **Total** | **~$35-45/month** |

## GitHub Actions Integration

Add to `.github/workflows/deploy.yml`:
```yaml
- name: Update ECS Service
  run: |
    aws ecs update-service \
      --cluster fastapi-app-cluster \
      --service fastapi-app-service \
      --force-new-deployment \
      --region ap-south-1
```

## Best Practices

1. ✅ Use parameter files for different environments
2. ✅ Enable stack termination protection for production
3. ✅ Use AWS Secrets Manager for sensitive data
4. ✅ Set up CloudWatch dashboards
5. ✅ Enable AWS Config for compliance
6. ✅ Use stack policies to prevent accidental updates

## License

MIT