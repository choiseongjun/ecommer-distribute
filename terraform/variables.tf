# Terraform variables for LocalStack deployment

variable "project_name" {
  description = "Project name used for resource naming"
  type        = string
  default     = "bigdataplatform"
}

variable "environment" {
  description = "Environment name (dev, staging, prod)"
  type        = string
  default     = "dev"
}

variable "aws_region" {
  description = "AWS region"
  type        = string
  default     = "us-east-1"
}

variable "vpc_cidr" {
  description = "CIDR block for VPC"
  type        = string
  default     = "10.0.0.0/16"
}

variable "availability_zones" {
  description = "List of availability zones"
  type        = list(string)
  default     = ["us-east-1a", "us-east-1b"]
}

# Database variables
variable "db_name" {
  description = "Database name"
  type        = string
  default     = "microservices"
}

variable "db_username" {
  description = "Database username"
  type        = string
  default     = "admin"
}

variable "db_password" {
  description = "Database password"
  type        = string
  sensitive   = true
  default     = "admin123"
}

# ECS Task Definition variables
variable "api_gateway_cpu" {
  description = "CPU units for API Gateway task"
  type        = number
  default     = 256
}

variable "api_gateway_memory" {
  description = "Memory for API Gateway task (in MB)"
  type        = number
  default     = 512
}

variable "api_gateway_image" {
  description = "Docker image for API Gateway"
  type        = string
  default     = "api-gateway:latest"
}

variable "user_service_cpu" {
  description = "CPU units for User Service task"
  type        = number
  default     = 256
}

variable "user_service_memory" {
  description = "Memory for User Service task (in MB)"
  type        = number
  default     = 512
}

variable "user_service_image" {
  description = "Docker image for User Service"
  type        = string
  default     = "user-service:latest"
}

variable "order_service_cpu" {
  description = "CPU units for Order Service task"
  type        = number
  default     = 256
}

variable "order_service_memory" {
  description = "Memory for Order Service task (in MB)"
  type        = number
  default     = 512
}

variable "order_service_image" {
  description = "Docker image for Order Service"
  type        = string
  default     = "order-service:latest"
}

variable "product_service_cpu" {
  description = "CPU units for Product Service task"
  type        = number
  default     = 256
}

variable "product_service_memory" {
  description = "Memory for Product Service task (in MB)"
  type        = number
  default     = 512
}

variable "product_service_image" {
  description = "Docker image for Product Service"
  type        = string
  default     = "product-service:latest"
}

variable "notification_service_cpu" {
  description = "CPU units for Notification Service task"
  type        = number
  default     = 256
}

variable "notification_service_memory" {
  description = "Memory for Notification Service task (in MB)"
  type        = number
  default     = 512
}

variable "notification_service_image" {
  description = "Docker image for Notification Service"
  type        = string
  default     = "notification-service:latest"
}
