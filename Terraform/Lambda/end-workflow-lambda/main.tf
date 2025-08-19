data "aws_iam_policy_document" "end_workflow_lambda_assume_role" {
  statement {
    effect = "Allow"

    principals {
      type        = "Service"
      identifiers = ["lambda.amazonaws.com"]
    }

    actions = ["sts:AssumeRole"]
  }
}

resource "aws_iam_role" "end_workflow_lambda_role" {
  name               = "lambda_execution_role"
  assume_role_policy = data.aws_iam_policy_document.end_workflow_lambda_assume_role.json
}

data "aws_iam_policy_document" "end_workflow_lambda_policy" {

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
      "arn:aws:dynamodb:eu-west-3:195044943814:table/workflow_statut"
    ]
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
      "arn:aws:logs:eu-west-3:195044943814:log-group:/aws/lambda/*"
    ]
  }
}

resource "aws_iam_role_policy" "end_workflow_lambda_permissions" {
  name   = "lambda_permissions"
  role   = aws_iam_role.end_workflow_lambda_role.id
  policy = data.aws_iam_policy_document.end_workflow_lambda_policy.json
}


# Package the Lambda function code
data "archive_file" "end_workflow_lambda" {
  type        = "zip"
  source_file = "${path.module}/../Code/end-workflow-lambda/end-workflow-lambda.py"
  output_path = "${path.module}/../Code/end-workflow-lambda/end-workflow-lambda.zip"
}

# Lambda function
resource "aws_lambda_function" "start_workflow_lambda" {
  filename      = data.archive_file.end_workflow_lambda.output_path
  function_name = "end_workflow_lambda"
  role          = aws_iam_role.end_workflow_lambda_role.arn
  handler       = "index.handler"

  runtime = "python3.12"

  environment {
    variables = {
      WORKFLOW_METADATA_TABLE = "workflow_metadata"
      WORKFLOW_TRACK_TABLE    = "workflow_statut"
    }
  }
}