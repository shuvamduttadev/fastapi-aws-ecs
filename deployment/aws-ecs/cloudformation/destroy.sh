#!/bin/bash

set -e

# Configuration
STACK_NAME="fastapi-infrastructure"
REGION="ap-south-1"

# Colors
RED='\033[0;31m'
YELLOW='\033[1;33m'
GREEN='\033[0;32m'
NC='\033[0m'

echo -e "${RED}=== FastAPI Infrastructure Destruction ===${NC}"
echo ""

# Check if stack exists
STACK_EXISTS=$(aws cloudformation describe-stacks \
    --stack-name $STACK_NAME \
    --region $REGION 2>&1 || true)

if echo "$STACK_EXISTS" | grep -q "does not exist"; then
    echo "Stack $STACK_NAME does not exist."
    exit 0
fi

echo -e "${RED}WARNING: This will destroy all infrastructure!${NC}"
echo ""
echo "Stack: $STACK_NAME"
echo "Region: $REGION"
echo ""
echo "Resources that will be destroyed:"
echo "  - ECS Cluster and Service"
echo "  - Application Load Balancer"
echo "  - CloudFront Distribution"
echo "  - ECR Repository (including all images)"
echo "  - Security Groups"
echo "  - IAM Roles"
echo "  - CloudWatch Logs"
echo "  - CloudWatch Alarms"
echo ""

read -p "Are you sure you want to destroy everything? (type 'destroy' to confirm): " confirm

if [ "$confirm" != "destroy" ]; then
    echo "Destruction cancelled."
    exit 0
fi

echo ""
echo "Deleting CloudFormation stack..."
aws cloudformation delete-stack \
    --stack-name $STACK_NAME \
    --region $REGION

echo ""
echo "Waiting for stack deletion to complete (this may take 5-10 minutes)..."
aws cloudformation wait stack-delete-complete \
    --stack-name $STACK_NAME \
    --region $REGION

echo ""
echo -e "${GREEN}=== All resources have been destroyed ===${NC}"