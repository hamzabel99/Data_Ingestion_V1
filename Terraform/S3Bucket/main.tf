resource "aws_s3_bucket" "preprocess_bucket" {
  bucket = var.preprocess_bucket_name
}