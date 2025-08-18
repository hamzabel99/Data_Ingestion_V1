output "preprocess_bucket_name" {
  value = aws_s3_bucket.preprocess_bucket.bucket
}

output "preprocess_bucket_arn" {
  value = aws_s3_bucket.preprocess_bucket.arn
}