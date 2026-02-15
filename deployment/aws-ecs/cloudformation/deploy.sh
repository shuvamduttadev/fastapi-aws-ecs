#!/bin/bash

set -e

# Configuration
STACK_NAME="fastapi-infrastructure"
TEMPLATE_FILE="infrastructure.yaml"
PARAMETERS_FILE="parameters.json"
REGION="ap-south-1"

# Colors
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
RED='\033[0;31m'
NC='\033[0m'

echo "=== FastAPI CloudFormation Deployment ==="
echo ""

# Check prerequisites
echo "Checking prerequisites..."
command -v aws >/dev/null 2>&1 || { echo "AWS CLI is required but not installed. Aborting." >&2; exit 1; }
echo -e "${GREEN}✓${NC} AWS CLI found"

# Get VPC and Subnet IDs
echo ""
echo "Getting VPC and Subnet information..."
VPC_ID=$(aws ec2 describe-vpcs \
    --filters "Name=isDefault,Values=true" \
    --query "Vpcs[0].VpcId" \
    --output text \
    --region $REGION)

if [ -z "$VPC_ID" ] || [ "$VPC_ID" == "None" ]; then
    echo -e "${RED}✗${NC} Default VPC not found"
    exit 1
fi

echo -e "${GREEN}✓${NC} VPC ID: $VPC_ID"

SUBNET_1=$(aws ec2 describe-subnets \
    --filters "Name=vpc-id,Values=$VPC_ID" \
    --query "Subnets[0].SubnetId" \
    --output text \
    --region $REGION)

SUBNET_2=$(aws ec2 describe-subnets \
    --filters "Name=vpc-id,Values=$VPC_ID" \
    --query "Subnets[1].SubnetId" \
    --output text \
    --region $REGION)

echo -e "${GREEN}✓${NC} Subnet 1: $SUBNET_1"
echo -e "${GREEN}✓${NC} Subnet 2: $SUBNET_2"

# Update parameters file with VPC and Subnet IDs
echo ""
echo "Updating parameters file..."
jq --arg vpc "$VPC_ID" --arg subnet1 "$SUBNET_1" --arg subnet2 "$SUBNET_2" \
    '(.[] | select(.ParameterKey == "VpcId") | .ParameterValue) = $vpc |
     (.[] | select(.ParameterKey == "Subnet1Id") | .ParameterValue) = $subnet1 |
     (.[] | select(.ParameterKey == "Subnet2Id") | .ParameterValue) = $subnet2' \
    $PARAMETERS_FILE > ${PARAMETERS_FILE}.tmp && mv ${PARAMETERS_FILE}.tmp $PARAMETERS_FILE

echo -e "${GREEN}✓${NC} Parameters updated"

# Validate template
echo ""
echo "Validating CloudFormation template..."
aws cloudformation validate-template \
    --template-body file://$TEMPLATE_FILE \
    --region $REGION > /dev/null

echo -e "${GREEN}✓${NC} Template is valid"

# Check if stack exists
echo ""
STACK_EXISTS=$(aws cloudformation describe-stacks \
    --stack-name $STACK_NAME \
    --region $REGION 2>&1 || true)

if echo "$STACK_EXISTS" | grep -q "does not exist"; then
    ACTION="create"
    echo "Stack does not exist. Will create new stack."
else
    ACTION="update"
    echo "Stack exists. Will update existing stack."
fi

echo ""
echo -e "${YELLOW}Ready to $ACTION stack: $STACK_NAME${NC}"
read -p "Do you want to continue? (yes/no): " confirm

if [ "$confirm" != "yes" ]; then
    echo "Deployment cancelled."
    exit 0
fi

# Deploy stack
echo ""
echo "Deploying CloudFormation stack..."

if [ "$ACTION" == "create" ]; then
    aws cloudformation create-stack \
        --stack-name $STACK_NAME \
        --template-body file://$TEMPLATE_FILE \
        --parameters file://$PARAMETERS_FILE \
        --capabilities CAPABILITY_NAMED_IAM \
        --region $REGION \
        --tags \
            Key=Project,Value=FastAPI \
            Key=ManagedBy,Value=CloudFormation
    
    echo ""
    echo "Waiting for stack creation to complete..."
    aws cloudformation wait stack-create-complete \
        --stack-name $STACK_NAME \
        --region $REGION
else
    aws cloudformation update-stack \
        --stack-name $STACK_NAME \
        --template-body file://$TEMPLATE_FILE \
        --parameters file://$PARAMETERS_FILE \
        --capabilities CAPABILITY_NAMED_IAM \
        --region $REGION 2>&1 || {
            if echo $? | grep -q "No updates"; then
                echo "No updates to be performed."
            else
                exit 1
            fi
        }
    
    if ! echo "$?" | grep -q "No updates"; then
        echo ""
        echo "Waiting for stack update to complete..."
        aws cloudformation wait stack-update-complete \
            --stack-name $STACK_NAME \
            --region $REGION
    fi
fi

echo ""
echo -e "${GREEN}=== Deployment Complete! ===${NC}"
echo ""

# Get outputs
echo "Stack Outputs:"
aws cloudformation describe-stacks \
    --stack-name $STACK_NAME \
    --region $REGION \
    --query 'Stacks[0].Outputs[*].[OutputKey,OutputValue]' \
    --output table

echo ""
echo -e "${GREEN}Access your application:${NC}"
CLOUDFRONT_URL=$(aws cloudformation describe-stacks \
    --stack-name $STACK_NAME \
    --region $REGION \
    --query 'Stacks[0].Outputs[?OutputKey==`CloudFrontURL`].OutputValue' \
    --output text)

echo "CloudFront URL: $CLOUDFRONT_URL"
echo "Health Check: ${CLOUDFRONT_URL}/health"
echo "API Docs: ${CLOUDFRONT_URL}/docs"

echo ""
echo -e "${YELLOW}Note: CloudFront takes 10-20 minutes to fully deploy globally.${NC}"

echo ""
echo "View logs:"
LOG_GROUP=$(aws cloudformation describe-stacks \
    --stack-name $STACK_NAME \
    --region $REGION \
    --query 'Stacks[0].Outputs[?OutputKey==`CloudWatchLogGroup`].OutputValue' \
    --output text)
echo "aws logs tail $LOG_GROUP --follow --region $REGION"