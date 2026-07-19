# Terraform configuration for LocalStack EKS deployment

terraform {
  required_version = ">= 1.0"
  
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 5.0"
    }
  }
}

provider "aws" {
  region = var.aws_region
  
  access_key = "test"
  secret_key = "test"
  
  s3_use_path_style = true
  
  endpoints {
    eks       = "http://localhost:4566"
    ec2       = "http://localhost:4566"
    iam       = "http://localhost:4566"
    s3        = "http://localhost:4566"
    sts       = "http://localhost:4566"
    dynamodb   = "http://localhost:4566"
    elb       = "http://localhost:4566"
    elasticloadbalancing = "http://localhost:4566"
  }
  
  skip_metadata_api_check = true
  skip_credentials_validation = true
  skip_requesting_account_id = true
  
  default_tags {
    tags = {
      Project     = var.project_name
      Environment = var.environment
      ManagedBy   = "Terraform"
    }
  }
}

# S3 Buckets
resource "aws_s3_bucket" "assets" {
  bucket = "${var.project_name}-assets"
  
  tags = {
    Name = "${var.project_name}-assets"
  }
}

resource "aws_s3_bucket_versioning" "assets" {
  bucket = aws_s3_bucket.assets.id
  versioning_configuration {
    status = "Enabled"
  }
}

resource "aws_s3_bucket" "logs" {
  bucket = "${var.project_name}-logs"
  
  tags = {
    Name = "${var.project_name}-logs"
  }
}

resource "aws_s3_bucket_versioning" "logs" {
  bucket = aws_s3_bucket.logs.id
  versioning_configuration {
    status = "Enabled"
  }
}

# IAM Role for Kubernetes
resource "aws_iam_role" "kubernetes_role" {
  name = "${var.project_name}-kubernetes-role"
  
  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Action = "sts:AssumeRole"
        Effect = "Allow"
        Principal = {
          Service = "ec2.amazonaws.com"
        }
      }
    ]
  })
}

resource "aws_iam_role_policy_attachment" "s3_access" {
  policy_arn = "arn:aws:iam::aws:policy/AmazonS3FullAccess"
  role       = aws_iam_role.kubernetes_role.name
}
