data "aws_caller_identity" "current" {}
data "aws_region" "current" {}

# IAM role for All Lambda functions
data "aws_iam_policy_document" "start_workflow_lambda_assume_role" {
  statement {
    effect = "Allow"

    principals {
      type        = "Service"
      identifiers = ["lambda.amazonaws.com"]
    }

    actions = ["sts:AssumeRole"]
  }
}

resource "aws_iam_role" "start_workflow_lambda_role" {
  name               = "start_workflow_lambda_execution_role"
  assume_role_policy = data.aws_iam_policy_document.start_workflow_lambda_assume_role.json
}

data "aws_iam_policy_document" "start_workflow_lambda_policy" {
  statement {
    sid    = "SQSPoller"
    effect = "Allow"
    actions = [
      "sqs:ReceiveMessage",
      "sqs:DeleteMessage",
      "sqs:GetQueueAttributes"
    ]
    resources = [
      "arn:aws:sqs:eu-west-3:195044943814:Preprocess_Queue"
    ]
  }

  statement {
    sid    = "DynamoReadWorkflowMetadata"
    effect = "Allow"
    actions = [
      "dynamodb:GetItem",
      "dynamodb:BatchGetItem",
      "dynamodb:Query",
      "dynamodb:Scan",
      "dynamodb:PutItem",
      "dynamodb:UpdateItem",
      "dynamodb:DeleteItem",
      "dynamodb:BatchWriteItem"
    ]
    resources = [
      "arn:aws:dynamodb:${data.aws_region.current.region}:${data.aws_caller_identity.current.account_id}:table/workflow_metadata",
      "arn:aws:dynamodb:${data.aws_region.current.region}:${data.aws_caller_identity.current.account_id}:table/workflow_statut"
    ]
  }

  statement {
    sid    = "StartStepFunctions"
    effect = "Allow"
    actions = [
      "states:StartExecution"
    ]
    resources = ["*"]
  }

  statement {
    sid    = "CloudWatchLogs"
    effect = "Allow"
    actions = [
      "logs:CreateLogGroup",
      "logs:CreateLogStream",
      "logs:PutLogEvents"
    ]
    resources = [
      "arn:aws:logs:${data.aws_region.current.region}:${data.aws_caller_identity.current.account_id}:log-group:/aws/lambda/*"
    ]
  }
}


resource "aws_iam_role_policy" "start_workflow_lambda_permissions" {
  name   = "lambda_permissions"
  role   = aws_iam_role.start_workflow_lambda_role.id
  policy = data.aws_iam_policy_document.start_workflow_lambda_policy.json
}




# Package the Lambda function code
data "archive_file" "data_start_workflow_lambda" {
  type        = "zip"
  source_file = "${path.module}/../Code/start-workflow-lambda/start-workflow-lambda.py"
  output_path = "${path.module}/../Code/start-workflow-lambda/start-workflow-lambda.zip"
}

# Lambda function
resource "aws_lambda_function" "start_workflow_lambda" {
  filename      = data.archive_file.data_start_workflow_lambda.output_path
  function_name = "start_workflow_lambda"
  role          = aws_iam_role.start_workflow_lambda_role.arn
  handler       = "start-workflow-lambda.lambda_handler"

  runtime = "python3.12"

  environment {
    variables = {
      WORKFLOW_METADATA_TABLE = "workflow_metadata"
      WORKFLOW_TRACK_TABLE    = "workflow_statut"
    }
  }
}

resource "aws_lambda_event_source_mapping" "sqs_trigger_lambda" {
  event_source_arn = var.aws_sqs_queue_arn
  function_name    = aws_lambda_function.start_workflow_lambda.arn
  batch_size       = 10
}