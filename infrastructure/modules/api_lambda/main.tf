# =============================================================================
# 4C - API Gateway HTTP API + Lambda + SQS (driver mobile endpoint)
# =============================================================================
# Flow: mobile POST -> API GW -> Lambda -> SQS message
# Lambda runs outside VPC (no DB access needed for this demo flow).
# =============================================================================

# -----------------------------------------------------------------------------
# 1. SQS Queue
# -----------------------------------------------------------------------------
resource "aws_sqs_queue" "driver_updates" {
  name                       = "${lower(var.project_name)}-driver-updates"
  visibility_timeout_seconds = 30
  message_retention_seconds  = 345600 # 4 days (default)

  tags = { Name = "${var.project_name}-driver-updates" }
}


# -----------------------------------------------------------------------------
# 2. Lambda - package source dir to zip
# -----------------------------------------------------------------------------
data "archive_file" "lambda_zip" {
  type        = "zip"
  source_dir  = "${path.module}/src"
  output_path = "${path.module}/build/handler.zip"
}


# -----------------------------------------------------------------------------
# 3. IAM role for Lambda
# -----------------------------------------------------------------------------
data "aws_iam_policy_document" "lambda_assume" {
  statement {
    actions = ["sts:AssumeRole"]
    principals {
      type        = "Service"
      identifiers = ["lambda.amazonaws.com"]
    }
  }
}

resource "aws_iam_role" "lambda" {
  name               = "${var.project_name}-driver-lambda-role"
  assume_role_policy = data.aws_iam_policy_document.lambda_assume.json
}

resource "aws_iam_role_policy_attachment" "lambda_logs" {
  role       = aws_iam_role.lambda.name
  policy_arn = "arn:aws:iam::aws:policy/service-role/AWSLambdaBasicExecutionRole"
}

data "aws_iam_policy_document" "lambda_sqs" {
  statement {
    actions   = ["sqs:SendMessage"]
    resources = [aws_sqs_queue.driver_updates.arn]
  }
}

resource "aws_iam_role_policy" "lambda_sqs" {
  name   = "${var.project_name}-lambda-sqs-send"
  role   = aws_iam_role.lambda.id
  policy = data.aws_iam_policy_document.lambda_sqs.json
}


# -----------------------------------------------------------------------------
# 4. Lambda function
# -----------------------------------------------------------------------------
resource "aws_cloudwatch_log_group" "lambda" {
  name              = "/aws/lambda/${var.project_name}-driver-update"
  retention_in_days = 7
}

resource "aws_lambda_function" "driver_update" {
  function_name = "${var.project_name}-driver-update"
  role          = aws_iam_role.lambda.arn
  runtime       = var.lambda_runtime
  handler       = "handler.handler"
  timeout       = var.lambda_timeout
  memory_size   = var.lambda_memory

  filename         = data.archive_file.lambda_zip.output_path
  source_code_hash = data.archive_file.lambda_zip.output_base64sha256

  environment {
    variables = {
      QUEUE_URL = aws_sqs_queue.driver_updates.url
    }
  }

  depends_on = [
    aws_iam_role_policy_attachment.lambda_logs,
    aws_cloudwatch_log_group.lambda,
  ]

  tags = { Name = "${var.project_name}-driver-update" }
}


# -----------------------------------------------------------------------------
# 5. API Gateway HTTP API
# -----------------------------------------------------------------------------
resource "aws_apigatewayv2_api" "main" {
  name          = "${var.project_name}-driver-api"
  protocol_type = "HTTP"
  description   = "Driver mobile endpoint (Y9)"

  tags = { Name = "${var.project_name}-driver-api" }
}

resource "aws_apigatewayv2_integration" "lambda" {
  api_id                 = aws_apigatewayv2_api.main.id
  integration_type       = "AWS_PROXY"
  integration_uri        = aws_lambda_function.driver_update.invoke_arn
  integration_method     = "POST"
  payload_format_version = "2.0"
}

resource "aws_apigatewayv2_route" "post_order" {
  api_id    = aws_apigatewayv2_api.main.id
  route_key = "POST /order"
  target    = "integrations/${aws_apigatewayv2_integration.lambda.id}"
}

resource "aws_apigatewayv2_stage" "default" {
  api_id      = aws_apigatewayv2_api.main.id
  name        = "$default"
  auto_deploy = true
}

resource "aws_lambda_permission" "api_gw" {
  statement_id  = "AllowAPIGatewayInvoke"
  action        = "lambda:InvokeFunction"
  function_name = aws_lambda_function.driver_update.function_name
  principal     = "apigateway.amazonaws.com"
  source_arn    = "${aws_apigatewayv2_api.main.execution_arn}/*/*"
}
