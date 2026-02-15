# Project Configuration
project_name        = "fastapi-app"
environment         = "production"
aws_region          = "ap-south-1"

# ECR Configuration
ecr_repository_name = "fastapi-app"

# Container Configuration
container_port      = 8000
health_check_path   = "/health"

# ECS Task Configuration
task_cpu           = "256"    # 0.25 vCPU
task_memory        = "512"    # 512 MB

# ECS Service Configuration
desired_count      = 2
min_capacity       = 1
max_capacity       = 10

# Logging
log_retention_days = 7

# CloudFront
cloudfront_price_class = "PriceClass_All"

# Additional Tags
tags = {
  Project     = "FastAPI"
  ManagedBy   = "Terraform"
  Owner       = "DevOps Team"
}