provider "aws" {
  region = "eu-west-3" 
}

module "Dynamodb" {
  source = "./DynamoDb"
}

module "S3Bucket"{
  source="./S3Bucket"
  preprocess_bucket_name = "preworkflow-ingestion-bucket"
}