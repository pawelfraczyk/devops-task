output "bucket_name" {
  description = "State bucket name, including the account id."
  value       = aws_s3_bucket.state.bucket
}

output "bucket_arn" {
  description = "State bucket ARN."
  value       = aws_s3_bucket.state.arn
}
