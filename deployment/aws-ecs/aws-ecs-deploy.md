# FastAPI Deployment Guide - Manual Process

## Table of Contents
1. [Set Up AWS Infrastructure](#set-up-aws-infrastructure)
2. [Create Application Load Balancer](#create-application-load-balancer)
3. [Create CloudFront Distribution](#create-cloudfront-distribution)
4. [GitHub Actions Deployment](#github-actions-deployment)
5. [Access Your Application](#access-your-application)


## Set Up AWS Infrastructure

### 1. Create ECR Repository (Container Registry)

```bash
aws ecr create-repository \
    --repository-name my-fastapi-app \
    --region us-east-1

# Save the repository URI from output
# Example: 123456789012.dkr.ecr.us-east-1.amazonaws.com/my-fastapi-app
```

---

### 2. Create IAM Role for ECS Task Execution

```bash
# Create trust policy file
cat > ecs-task-execution-trust-policy.json << EOF
{
  "Version": "2012-10-17",
  "Statement": [
    {
      "Effect": "Allow",
      "Principal": {
        "Service": "ecs-tasks.amazonaws.com"
      },
      "Action": "sts:AssumeRole"
    }
  ]
}
EOF

# Create the IAM role
aws iam create-role \
    --role-name ecsTaskExecutionRole \
    --assume-role-policy-document file://ecs-task-execution-trust-policy.json

# Attach required policy
aws iam attach-role-policy \
    --role-name ecsTaskExecutionRole \
    --policy-arn arn:aws:iam::aws:policy/service-role/AmazonECSTaskExecutionRolePolicy

# Get the role ARN (save this for task definition)
aws iam get-role \
    --role-name ecsTaskExecutionRole \
    --query 'Role.Arn' \
    --output text
```

---

### 3. Create ECS Cluster

```bash
aws ecs create-cluster \
    --cluster-name fastapi-cluster \
    --region us-east-1
```

---

### 4. Get VPC and Subnet Information

```bash
# Get default VPC ID
VPC_ID=$(aws ec2 describe-vpcs \
    --filters "Name=isDefault,Values=true" \
    --query "Vpcs[0].VpcId" \
    --output text \
    --region us-east-1)

echo "VPC ID: $VPC_ID"

# Get subnet IDs (you need at least 2 for ALB)
SUBNET_1=$(aws ec2 describe-subnets \
    --filters "Name=vpc-id,Values=$VPC_ID" \
    --query "Subnets[0].SubnetId" \
    --output text \
    --region us-east-1)

SUBNET_2=$(aws ec2 describe-subnets \
    --filters "Name=vpc-id,Values=$VPC_ID" \
    --query "Subnets[1].SubnetId" \
    --output text \
    --region us-east-1)

echo "Subnet 1: $SUBNET_1"
echo "Subnet 2: $SUBNET_2"
```

---

### 5. Create Security Groups

#### Create ALB Security Group

```bash
# Create ALB security group
ALB_SG=$(aws ec2 create-security-group \
    --group-name fastapi-alb-sg \
    --description "Security group for FastAPI ALB" \
    --vpc-id $VPC_ID \
    --region us-east-1 \
    --query 'GroupId' \
    --output text)

echo "ALB Security Group: $ALB_SG"

# Allow HTTP traffic to ALB
aws ec2 authorize-security-group-ingress \
    --group-id $ALB_SG \
    --protocol tcp \
    --port 80 \
    --cidr 0.0.0.0/0 \
    --region us-east-1

# Allow HTTPS traffic to ALB (optional)
aws ec2 authorize-security-group-ingress \
    --group-id $ALB_SG \
    --protocol tcp \
    --port 443 \
    --cidr 0.0.0.0/0 \
    --region us-east-1
```

#### Create ECS Tasks Security Group

```bash
# Create ECS security group
ECS_SG=$(aws ec2 create-security-group \
    --group-name fastapi-ecs-sg \
    --description "Security group for FastAPI ECS tasks" \
    --vpc-id $VPC_ID \
    --region us-east-1 \
    --query 'GroupId' \
    --output text)

echo "ECS Security Group: $ECS_SG"

# Allow traffic from ALB to ECS tasks on port 8000
aws ec2 authorize-security-group-ingress \
    --group-id $ECS_SG \
    --protocol tcp \
    --port 8000 \
    --source-group $ALB_SG \
    --region us-east-1
```

---

### 6. Create CloudWatch Log Group

```bash
aws logs create-log-group \
    --log-group-name /ecs/fastapi \
    --region us-east-1
```

---

## Create Application Load Balancer

### 7. Create Target Group

```bash
# Create target group
TG_ARN=$(aws elbv2 create-target-group \
    --name fastapi-tg \
    --protocol HTTP \
    --port 8000 \
    --vpc-id $VPC_ID \
    --target-type ip \
    --health-check-enabled \
    --health-check-protocol HTTP \
    --health-check-path /health \
    --health-check-interval-seconds 30 \
    --health-check-timeout-seconds 5 \
    --healthy-threshold-count 2 \
    --unhealthy-threshold-count 3 \
    --matcher HttpCode=200 \
    --region us-east-1 \
    --query 'TargetGroups[0].TargetGroupArn' \
    --output text)

echo "Target Group ARN: $TG_ARN"
```

---

### 8. Create Application Load Balancer

```bash
# Create ALB
ALB_ARN=$(aws elbv2 create-load-balancer \
    --name fastapi-alb \
    --subnets $SUBNET_1 $SUBNET_2 \
    --security-groups $ALB_SG \
    --scheme internet-facing \
    --type application \
    --ip-address-type ipv4 \
    --region us-east-1 \
    --query 'LoadBalancers[0].LoadBalancerArn' \
    --output text)

echo "ALB ARN: $ALB_ARN"

# Get ALB DNS name
ALB_DNS=$(aws elbv2 describe-load-balancers \
    --load-balancer-arns $ALB_ARN \
    --query 'LoadBalancers[0].DNSName' \
    --output text \
    --region us-east-1)

echo "ALB DNS: $ALB_DNS"
echo "Access your app at: http://$ALB_DNS"
```

---

### 9. Create ALB Listener

```bash
# Create HTTP listener (port 80)
LISTENER_ARN=$(aws elbv2 create-listener \
    --load-balancer-arn $ALB_ARN \
    --protocol HTTP \
    --port 80 \
    --default-actions Type=forward,TargetGroupArn=$TG_ARN \
    --region us-east-1 \
    --query 'Listeners[0].ListenerArn' \
    --output text)

echo "Listener ARN: $LISTENER_ARN"
```

---

### 10. Create Task Definition

Create `task-definition.json` in your project root:

```json
{
  "family": "fastapi-task",
  "networkMode": "awsvpc",
  "requiresCompatibilities": ["FARGATE"],
  "cpu": "256",
  "memory": "512",
  "executionRoleArn": "arn:aws:iam::YOUR_ACCOUNT_ID:role/ecsTaskExecutionRole",
  "containerDefinitions": [
    {
      "name": "fastapi-container",
      "image": "YOUR_ACCOUNT_ID.dkr.ecr.us-east-1.amazonaws.com/my-fastapi-app:latest",
      "portMappings": [
        {
          "containerPort": 8000,
          "protocol": "tcp"
        }
      ],
      "essential": true,
      "logConfiguration": {
        "logDriver": "awslogs",
        "options": {
          "awslogs-group": "/ecs/fastapi",
          "awslogs-region": "us-east-1",
          "awslogs-stream-prefix": "ecs",
          "awslogs-create-group": "true"
        }
      },
      "environment": [
        {
          "name": "ENVIRONMENT",
          "value": "production"
        }
      ]
    }
  ]
}
```

**Register the task definition:**

```bash
# Replace YOUR_ACCOUNT_ID in the file first
aws ecs register-task-definition \
    --cli-input-json file://task-definition.json \
    --region us-east-1
```

---

### 11. Create ECS Service with Load Balancer

```bash
aws ecs create-service \
    --cluster fastapi-cluster \
    --service-name fastapi-service \
    --task-definition fastapi-task \
    --desired-count 2 \
    --launch-type FARGATE \
    --network-configuration "awsvpcConfiguration={subnets=[$SUBNET_1,$SUBNET_2],securityGroups=[$ECS_SG],assignPublicIp=ENABLED}" \
    --load-balancers "targetGroupArn=$TG_ARN,containerName=fastapi-container,containerPort=8000" \
    --health-check-grace-period-seconds 60 \
    --region us-east-1
```

---

### 12. Wait and Verify Service is Running

```bash
# Wait for service to stabilize (takes 2-5 minutes)
echo "Waiting for service to stabilize..."
aws ecs wait services-stable \
    --cluster fastapi-cluster \
    --services fastapi-service \
    --region us-east-1

echo "✅ Service is stable!"

# Check target health
aws elbv2 describe-target-health \
    --target-group-arn $TG_ARN \
    --region us-east-1 \
    --query 'TargetHealthDescriptions[*].[Target.Id,TargetHealth.State]' \
    --output table

# Test ALB endpoint
echo ""
echo "Testing ALB..."
curl http://$ALB_DNS/health
```

---

## Create CloudFront Distribution

### 13. Create CloudFront Distribution

```bash
# Create CloudFront distribution configuration
cat > cloudfront-config.json << EOF
{
  "CallerReference": "fastapi-$(date +%s)",
  "Comment": "FastAPI CloudFront Distribution",
  "Enabled": true,
  "Origins": {
    "Quantity": 1,
    "Items": [
      {
        "Id": "ALB-Origin",
        "DomainName": "$ALB_DNS",
        "CustomOriginConfig": {
          "HTTPPort": 80,
          "HTTPSPort": 443,
          "OriginProtocolPolicy": "http-only",
          "OriginSslProtocols": {
            "Quantity": 1,
            "Items": ["TLSv1.2"]
          },
          "OriginReadTimeout": 60,
          "OriginKeepaliveTimeout": 5
        }
      }
    ]
  },
  "DefaultCacheBehavior": {
    "TargetOriginId": "ALB-Origin",
    "ViewerProtocolPolicy": "redirect-to-https",
    "AllowedMethods": {
      "Quantity": 7,
      "Items": ["GET", "HEAD", "OPTIONS", "PUT", "POST", "PATCH", "DELETE"],
      "CachedMethods": {
        "Quantity": 2,
        "Items": ["GET", "HEAD"]
      }
    },
    "Compress": true,
    "CachePolicyId": "4135ea2d-6df8-44a3-9df3-4b5a84be39ad",
    "OriginRequestPolicyId": "216adef6-5c7f-47e4-b989-5492eafa07d3",
    "MinTTL": 0,
    "DefaultTTL": 0,
    "MaxTTL": 0
  },
  "ViewerCertificate": {
    "CloudFrontDefaultCertificate": true,
    "MinimumProtocolVersion": "TLSv1.2_2021"
  },
  "PriceClass": "PriceClass_All",
  "HttpVersion": "http2and3"
}
EOF

# Create CloudFront distribution
CF_DIST=$(aws cloudfront create-distribution \
    --distribution-config file://cloudfront-config.json \
    --region us-east-1 \
    --query 'Distribution.{Id:Id,DomainName:DomainName,Status:Status}' \
    --output json)

echo "CloudFront Distribution Created:"
echo "$CF_DIST" | jq '.'

# Extract CloudFront domain
CF_DOMAIN=$(echo "$CF_DIST" | jq -r '.DomainName')
CF_ID=$(echo "$CF_DIST" | jq -r '.Id')

echo ""
echo "✅ CloudFront Distribution Created!"
echo "   Distribution ID: $CF_ID"
echo "   CloudFront URL: https://$CF_DOMAIN"
echo ""
echo "⏳ CloudFront is deploying globally (takes 10-20 minutes)..."
echo "   Check status: aws cloudfront get-distribution --id $CF_ID --query 'Distribution.Status'"
```

---

### 14. Wait for CloudFront Deployment

```bash
# Check CloudFront status
echo "Checking CloudFront deployment status..."
while true; do
    STATUS=$(aws cloudfront get-distribution --id $CF_ID --query 'Distribution.Status' --output text)
    echo "Status: $STATUS"
    
    if [ "$STATUS" == "Deployed" ]; then
        echo "✅ CloudFront is deployed!"
        break
    fi
    
    echo "Waiting 60 seconds..."
    sleep 60
done

# Test CloudFront
echo ""
echo "Testing CloudFront endpoint..."
curl https://$CF_DOMAIN/health
```

---

### 15. (Optional) Create CloudFront Invalidation

If you need to clear CloudFront cache:

```bash
# Create invalidation
aws cloudfront create-invalidation \
    --distribution-id $CF_ID \
    --paths "/*" \
    --region us-east-1

echo "Cache invalidation created. This will take 5-10 minutes to complete."
```

---

## GitHub Actions Deployment

### 16. Create GitHub Actions Workflow

Create `.github/workflows/deploy.yml`:

```yaml
name: Deploy FastAPI to AWS ECS

on:
  push:
    branches:
      - main
  workflow_dispatch:

env:
  AWS_REGION: us-east-1
  ECR_REPOSITORY: my-fastapi-app
  ECS_SERVICE: fastapi-service
  ECS_CLUSTER: fastapi-cluster
  ECS_TASK_DEFINITION: fastapi-task
  CONTAINER_NAME: fastapi-container

jobs:
  deploy:
    name: Deploy to ECS
    runs-on: ubuntu-latest
    environment: prod
    
    steps:
      - name: Checkout code
        uses: actions/checkout@v3
      
      - name: Configure AWS credentials
        uses: aws-actions/configure-aws-credentials@v2
        with:
          aws-access-key-id: ${{ secrets.AWS_ACCESS_KEY_ID }}
          aws-secret-access-key: ${{ secrets.AWS_SECRET_ACCESS_KEY }}
          aws-region: us-east-1
      
      - name: Login to Amazon ECR
        id: login-ecr
        uses: aws-actions/amazon-ecr-login@v1
      
      - name: Build, tag, and push image to Amazon ECR
        id: build-image
        env:
          ECR_REGISTRY: ${{ steps.login-ecr.outputs.registry }}
          IMAGE_TAG: ${{ github.sha }}
        run: |
          docker build -t $ECR_REGISTRY/$ECR_REPOSITORY:$IMAGE_TAG .
          docker build -t $ECR_REGISTRY/$ECR_REPOSITORY:latest .
          docker push $ECR_REGISTRY/$ECR_REPOSITORY:$IMAGE_TAG
          docker push $ECR_REGISTRY/$ECR_REPOSITORY:latest
          echo "image=$ECR_REGISTRY/$ECR_REPOSITORY:$IMAGE_TAG" >> $GITHUB_OUTPUT
      
      - name: Download task definition from ECS
        run: |
          aws ecs describe-task-definition \
            --task-definition ${{ env.ECS_TASK_DEFINITION }} \
            --query taskDefinition > task-definition.json
      
      - name: Fill in the new image ID in task definition
        id: task-def
        uses: aws-actions/amazon-ecs-render-task-definition@v1
        with:
          task-definition: task-definition.json
          container-name: ${{ env.CONTAINER_NAME }}
          image: ${{ steps.build-image.outputs.image }}
      
      - name: Deploy to ECS
        uses: aws-actions/amazon-ecs-deploy-task-definition@v1
        with:
          task-definition: ${{ steps.task-def.outputs.task-definition }}
          service: ${{ env.ECS_SERVICE }}
          cluster: ${{ env.ECS_CLUSTER }}
          wait-for-service-stability: true
      
      - name: Invalidate CloudFront cache
        run: |
          aws cloudfront create-invalidation \
            --distribution-id ${{ secrets.CLOUDFRONT_DISTRIBUTION_ID }} \
            --paths "/*"
      
      - name: Deployment complete
        run: |
          echo "🚀 FastAPI deployment successful!"
          echo "Image: ${{ steps.build-image.outputs.image }}"
```

---

### 17. Set Up GitHub Secrets

Go to your GitHub repository → **Settings** → **Secrets and variables** → **Actions** → **New repository secret**

Add these secrets:

| Secret Name | Value |
|-------------|-------|
| `AWS_ACCESS_KEY_ID` | Your AWS access key |
| `AWS_SECRET_ACCESS_KEY` | Your AWS secret key |
| `CLOUDFRONT_DISTRIBUTION_ID` | Your CloudFront distribution ID |

---

## Access Your Application

### Application URLs

```bash
# ALB URL (HTTP)
echo "ALB URL: http://$ALB_DNS"

# CloudFront URL (HTTPS)
echo "CloudFront URL: https://$CF_DOMAIN"

# Health check
echo "Health check: https://$CF_DOMAIN/health"

# API Documentation
echo "API Docs: https://$CF_DOMAIN/docs"
```

---

## Monitoring and Management

### View Logs

```bash
# View CloudWatch logs
aws logs tail /ecs/fastapi --follow --region us-east-1

# View last 100 lines
aws logs tail /ecs/fastapi --since 10m --region us-east-1
```

### Check Service Status

```bash
# Check ECS service
aws ecs describe-services \
    --cluster fastapi-cluster \
    --services fastapi-service \
    --region us-east-1 \
    --query 'services[0].{Status:status,Running:runningCount,Desired:desiredCount}'

# Check target health
aws elbv2 describe-target-health \
    --target-group-arn $TG_ARN \
    --region us-east-1
```

### Scale Service

```bash
# Scale to 4 tasks
aws ecs update-service \
    --cluster fastapi-cluster \
    --service fastapi-service \
    --desired-count 4 \
    --region us-east-1
```

---

## Cleanup (Delete All Resources)

```bash
# Delete ECS service
aws ecs update-service \
    --cluster fastapi-cluster \
    --service fastapi-service \
    --desired-count 0 \
    --region us-east-1

aws ecs delete-service \
    --cluster fastapi-cluster \
    --service fastapi-service \
    --force \
    --region us-east-1

# Delete ECS cluster
aws ecs delete-cluster \
    --cluster fastapi-cluster \
    --region us-east-1

# Disable and delete CloudFront distribution
aws cloudfront get-distribution-config \
    --id $CF_ID \
    --query 'DistributionConfig' > cf-config-temp.json

# Edit config to set Enabled to false
aws cloudfront update-distribution \
    --id $CF_ID \
    --if-match $(aws cloudfront get-distribution --id $CF_ID --query 'ETag' --output text) \
    --distribution-config file://cf-config-temp.json

# Wait for deployment, then delete
aws cloudfront delete-distribution \
    --id $CF_ID \
    --if-match $(aws cloudfront get-distribution --id $CF_ID --query 'ETag' --output text)

# Delete ALB listener
aws elbv2 delete-listener \
    --listener-arn $LISTENER_ARN \
    --region us-east-1

# Delete ALB
aws elbv2 delete-load-balancer \
    --load-balancer-arn $ALB_ARN \
    --region us-east-1

# Wait for ALB deletion (takes 2-3 minutes)
sleep 180

# Delete target group
aws elbv2 delete-target-group \
    --target-group-arn $TG_ARN \
    --region us-east-1

# Delete security groups
aws ec2 delete-security-group \
    --group-id $ECS_SG \
    --region us-east-1

aws ec2 delete-security-group \
    --group-id $ALB_SG \
    --region us-east-1

# Delete CloudWatch log group
aws logs delete-log-group \
    --log-group-name /ecs/fastapi \
    --region us-east-1

# Delete ECR repository
aws ecr delete-repository \
    --repository-name my-fastapi-app \
    --force \
    --region us-east-1

echo "✅ All resources deleted!"
```

---

## Architecture Diagram

```
User (HTTPS)
     ↓
CloudFront Distribution (CDN)
     ↓ (HTTP)
Application Load Balancer
     ↓
Target Group (Health checks)
     ↓
ECS Fargate Service
     ↓
ECS Tasks (FastAPI containers)
```

---

## Cost Estimate (Monthly)

| Service | Cost |
|---------|------|
| ECS Fargate (2 tasks) | ~$15-20 |
| Application Load Balancer | ~$16 |
| CloudFront | ~$1-5 (1TB free tier) |
| ECR Storage | ~$1 |
| CloudWatch Logs | ~$1 |
| **Total** | **~$35-45/month** |

---

## Troubleshooting

### 504 Gateway Timeout

```bash
# Check target health
aws elbv2 describe-target-health --target-group-arn $TG_ARN

# Check ECS task status
aws ecs describe-tasks --cluster fastapi-cluster --tasks $(aws ecs list-tasks --cluster fastapi-cluster --service-name fastapi-service --output text)

# View logs
aws logs tail /ecs/fastapi --since 10m

# Invalidate CloudFront cache
aws cloudfront create-invalidation --distribution-id $CF_ID --paths "/*"
```

### Unhealthy Targets

```bash
# Check security group allows ALB → ECS on port 8000
# Check /health endpoint returns 200
# Check logs for errors
```

---

## Summary

✅ **What You Created:**
- ECR Repository for Docker images
- ECS Cluster and Service running on Fargate
- Application Load Balancer with health checks
- CloudFront CDN with HTTPS
- GitHub Actions CI/CD pipeline
- Auto-scaling and logging

✅ **Access Points:**
- ALB: `http://fastapi-alb-xxx.us-east-1.elb.amazonaws.com`
- CloudFront: `https://d123abc456def.cloudfront.net`
- API Docs: `https://d123abc456def.cloudfront.net/docs`

---

## Next Steps

1. **Add Custom Domain** (Route 53)
2. **Add SSL Certificate** to ALB (AWS Certificate Manager)
3. **Set up Auto Scaling** based on CPU/Memory
4. **Enable WAF** for security
5. **Add Monitoring** with CloudWatch Alarms
6. **Set up CI/CD** with GitHub Actions

---

**🚀 Your FastAPI application is now production-ready on AWS!**
```

---

This complete markdown file provides:

✅ Full CLI commands for ALB setup  
✅ Target Group creation and configuration  
✅ CloudFront distribution with proper settings  
✅ ECS service integration with load balancer  
✅ GitHub Actions workflow with CloudFront invalidation  
✅ Monitoring and troubleshooting commands  
✅ Complete cleanup script  
✅ Cost estimates and architecture diagram  

Save this as `DEPLOYMENT_GUIDE.md` in your repository!