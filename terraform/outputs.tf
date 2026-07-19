# Terraform outputs for LocalStack deployment

output "vpc_id" {
  description = "ID of the VPC"
  value       = aws_vpc.main.id
}

output "public_subnet_ids" {
  description = "IDs of public subnets"
  value       = aws_subnet.public[*].id
}

output "private_subnet_ids" {
  description = "IDs of private subnets"
  value       = aws_subnet.private[*].id
}

output "ecs_cluster_id" {
  description = "ID of the ECS cluster"
  value       = aws_ecs_cluster.main.id
}

output "ecs_cluster_arn" {
  description = "ARN of the ECS cluster"
  value       = aws_ecs_cluster.main.arn
}

output "alb_dns_name" {
  description = "DNS name of the load balancer"
  value       = aws_lb.main.dns_name
}

output "alb_zone_id" {
  description = "Zone ID of the load balancer"
  value       = aws_lb.main.zone_id
}

output "rds_endpoint" {
  description = "Endpoint of the RDS instance"
  value       = aws_db_instance.postgres.endpoint
  sensitive   = true
}

output "rds_instance_id" {
  description = "ID of the RDS instance"
  value       = aws_db_instance.postgres.id
}

output "redis_endpoint" {
  description = "Endpoint of the Redis cluster"
  value       = aws_elasticache_replication_group.redis.primary_endpoint_address
}

output "s3_assets_bucket" {
  description = "Name of the assets S3 bucket"
  value       = aws_s3_bucket.assets.id
}

output "s3_logs_bucket" {
  description = "Name of the logs S3 bucket"
  value       = aws_s3_bucket.logs.id
}

output "api_gateway_task_definition_arn" {
  description = "ARN of the API Gateway task definition"
  value       = aws_ecs_task_definition.api_gateway.arn
}

output "user_service_task_definition_arn" {
  description = "ARN of the User Service task definition"
  value       = aws_ecs_task_definition.user_service.arn
}

output "secrets_manager_secret_arn" {
  description = "ARN of the database password secret"
  value       = aws_secretsmanager_secret.db_password.arn
  sensitive   = true
}
