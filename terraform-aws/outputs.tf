# Terraform outputs for LocalStack AWS deployment

output "s3_assets_bucket" {
  description = "Name of the assets S3 bucket"
  value       = aws_s3_bucket.assets.id
}

output "s3_logs_bucket" {
  description = "Name of the logs S3 bucket"
  value       = aws_s3_bucket.logs.id
}

output "iam_role_arn" {
  description = "ARN of the IAM role"
  value       = aws_iam_role.kubernetes_role.arn
}
