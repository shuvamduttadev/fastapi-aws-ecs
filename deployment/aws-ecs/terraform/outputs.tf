output "ecr_repository_url" {
  description = "ECR repository URL"
  value       = aws_ecr_repository.fastapi.repository_url
}

output "ecr_repository_name" {
  description = "ECR repository name"
  value       = aws_ecr_repository.fastapi.name
}

output "ecs_cluster_name" {
  description = "ECS cluster name"
  value       = aws_ecs_cluster.main.name
}

output "ecs_service_name" {
  description = "ECS service name"
  value       = aws_ecs_service.main.name
}

output "alb_dns_name" {
  description = "Application Load Balancer DNS name"
  value       = aws_lb.main.dns_name
}

output "alb_url" {
  description = "Application Load Balancer URL"
  value       = "http://${aws_lb.main.dns_name}"
}

output "cloudfront_distribution_id" {
  description = "CloudFront distribution ID"
  value       = aws_cloudfront_distribution.main.id
}

output "cloudfront_domain_name" {
  description = "CloudFront distribution domain name"
  value       = aws_cloudfront_distribution.main.domain_name
}

output "cloudfront_url" {
  description = "CloudFront URL"
  value       = "https://${aws_cloudfront_distribution.main.domain_name}"
}

output "cloudwatch_log_group" {
  description = "CloudWatch log group name"
  value       = aws_cloudwatch_log_group.ecs.name
}

output "aws_region" {
  description = "AWS region"
  value       = var.aws_region
}

output "deployment_summary" {
  description = "Deployment summary"
  value = {
    ecr_repository      = aws_ecr_repository.fastapi.repository_url
    ecs_cluster         = aws_ecs_cluster.main.name
    ecs_service         = aws_ecs_service.main.name
    alb_url             = "http://${aws_lb.main.dns_name}"
    cloudfront_url      = "https://${aws_cloudfront_distribution.main.domain_name}"
    health_check        = "https://${aws_cloudfront_distribution.main.domain_name}${var.health_check_path}"
    api_docs            = "https://${aws_cloudfront_distribution.main.domain_name}/docs"
    logs_command        = "aws logs tail ${aws_cloudwatch_log_group.ecs.name} --follow --region ${var.aws_region}"
  }
}