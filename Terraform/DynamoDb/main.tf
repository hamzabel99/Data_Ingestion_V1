resource "aws_dynamodb_table" "example" {
    name             = "workflow_metadata"
    hash_key         = "S3_prefix"
    billing_mode     = "PAY_PER_REQUEST"

    attribute {
    name = "S3_prefix"
    type = "S"
  }
}

