#!/bin/bash

set -e

echo "=== FastAPI Terraform Deployment ==="
echo ""

# Colors
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

# Check prerequisites
echo "Checking prerequisites..."
command -v terraform >/dev/null 2>&1 || { echo "Terraform is required but not installed. Aborting." >&2; exit 1; }
command -v aws >/dev/null 2>&1 || { echo "AWS CLI is required but not installed. Aborting." >&2; exit 1; }

echo -e "${GREEN}✓${NC} Prerequisites OK"
echo ""

# Initialize Terraform
echo "Initializing Terraform..."
terraform init

echo ""

# Plan
echo "Planning infrastructure..."
terraform plan -out=tfplan

echo ""
echo -e "${YELLOW}Review the plan above.${NC}"
read -p "Do you want to apply this plan? (yes/no): " confirm

if [ "$confirm" != "yes" ]; then
    echo "Deployment cancelled."
    exit 0
fi

echo ""
echo "Applying infrastructure..."
terraform apply tfplan

echo ""
echo -e "${GREEN}=== Deployment Complete! ===${NC}"
echo ""

# Show outputs
echo "Infrastructure Details:"
terraform output deployment_summary | jq '.'

echo ""
echo -e "${GREEN}Access your application:${NC}"
terraform output cloudfront_url

echo ""
echo -e "${YELLOW}Note: CloudFront takes 10-20 minutes to fully deploy globally.${NC}"
echo ""
echo "View logs:"
terraform output -raw deployment_summary | jq -r '.logs_command'