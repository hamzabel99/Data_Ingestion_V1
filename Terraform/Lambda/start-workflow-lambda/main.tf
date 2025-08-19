#  configuration


# IAM role for All Lambda functions
data "aws_iam_policy_document" "assume_role" {
  statement {
    effect = "Allow"

    principals {
      type        = "Service"
      identifiers = ["lambda.amazonaws.com"]
    }

    actions = ["sts:AssumeRole"]
  }
}

resource "aws_iam_role" "lambda_role" {
  name               = "lambda_execution_role"
  assume_role_policy = data.aws_iam_policy_document.assume_role.json
}

data "aws_iam_policy_document" "lambda_policy" {
  statement {
    sid     = "SQSPoller"
    effect  = "Allow"
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
    sid     = "DynamoReadWorkflowMetadata"
    effect  = "Allow"
    actions = [
      "dynamodb:GetItem"
    ]
    resources = [
      "arn:aws:dynamodb:eu-west-3:195044943814:table/workflow_metadata"
    ]
  }

  statement {
    sid     = "StartStepFunctions"
    effect  = "Allow"
    actions = [
      "states:StartExecution"
    ]
    resources = ["*"]
  }

  statement {
    sid     = "CloudWatchLogs"
    effect  = "Allow"
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


resource "aws_iam_role_policy" "lambda_permissions" {
  name   = "lambda_permissions"
  role   = aws_iam_role.lambda_role.id
  policy = data.aws_iam_policy_document.lambda_policy.json
}




# Package the Lambda function code
data "archive_file" "data_start_workflow_lambda" {
  type        = "zip"
  source_file = "${path.module}/../Code/start-workflow-lambda/start-workflow-lambda.py"
  output_path = "${path.module}/../Code/start-workflow-lambda/start-workflow-lambda.zip"
}

# Lambda function
resource "aws_lambda_function" "start_workflow_lambda" {
  filename         = data.archive_file.data_start_workflow_lambda.output_path
  function_name    = "start_workflow_lambda"
  role             = aws_iam_role.lambda_role.arn
  handler          = "index.handler"

  runtime = "python3.12"

  environment {
    variables = {
      WORKFLOW_METADATA_TABLE = "workflow_metadata"
      WORKFLOW_TRACK_TABLE   = "workflow_statut"
    }
  }
}

resource "aws_lambda_event_source_mapping" "sqs_trigger_lambda" {
  event_source_arn = var.aws_sqs_queue_arn
  function_name    = aws_lambda_function.start_workflow_lambda.arn
  batch_size       = 10
}