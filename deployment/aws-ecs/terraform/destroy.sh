#!/bin/bash

set -e

echo "=== FastAPI Infrastructure Destruction ==="
echo ""

# Colors
RED='\033[0;31m'
YELLOW='\033[1;33m'
NC='\033[0m'

echo -e "${RED}WARNING: This will destroy all infrastructure!${NC}"
echo ""
echo "Resources that will be destroyed:"
echo "  - ECS Cluster and Service"
echo "  - Application Load Balancer"
echo "  - CloudFront Distribution"
echo "  - ECR Repository (including all images)"
echo "  - Security Groups"
echo "  - IAM Roles"
echo "  - CloudWatch Logs"
echo ""

read -p "Are you sure you want to destroy everything? (type 'destroy' to confirm): " confirm

if [ "$confirm" != "destroy" ]; then
    echo "Destruction cancelled."
    exit 0
fi

echo ""
echo "Destroying infrastructure..."
terraform destroy -auto-approve

echo ""
echo -e "${RED}=== All resources have been destroyed ===${NC}"