terraform {
    required_providers {
        aws = {
            source = "hashicorp/aws"
            version = "-> 5.0"
        }
    }
    required_version = ">= 1.3.0"
}

provider "aws" {
    region = var.aws_region
}

resource "aws_dynamodb_table" "top_movers" {
    name = var.dynamodb_table_name
    billing_mode = "PAY_PER_REQUEST"
    hash_key = "date"

    attribute {
        name = "date"
        type = "S"
    }

    tags = {
        Project = var.project_name
    }
}

data "archive_file" "ingest_zip" {
    type = "zip"
    source_dir = "${path.module}/../lambda/ingest"
    output_dir = "${path.module}/../lambda/ingest.zip"
}

resource "aws_lambda_function" "ingest" {
    function_name = "${var.project_name}-ingest"
    role = aws_iam_role.lambda_ingest_role.arn
    handler = "handler.lambda_handler"
    runtime = "python3.12"
    filename = data.archive_file.ingest_zip.output_path
    source_code_hash = data.archive_file.ingest_zip.output_path
    timeout = 60
}

environment {
    variables = {
        MASSIVE_API_KEY = var.massive_api_key
        ANTHROPIC_API_KEY = var.anthropic_api_key
        DYNAMODB_TABLE = var.dynamodb_table_name
        AWS_REGION_NAME = var.aws_region
    }
}

tags = {
    Project = var.project_name
}

resource "aws_cloudwatch_event_rule" "daily_trigger" {
    name = "${var.project_name}-daily-trigger"
    description = "Triggers the ingest Lambda once per day after the market closes"
    schedule_expression = var.cron_schedule

    tags = {
        Project = var.project_name
    }
}

resource "aws_cloudwatch_event_target" "ingest_target" {
  rule      = aws_cloudwatch_event_rule.daily_trigger.name
  target_id = "IngestLambda"
  arn       = aws_lambda_function.ingest.arn
}

resource "aws_lambda_permission" "allow_eventbridge" {
  statement_id  = "AllowEventBridgeInvoke"
  action        = "lambda:InvokeFunction"
  function_name = aws_lambda_function.ingest.function_name
  principal     = "events.amazonaws.com"
  source_arn    = aws_cloudwatch_event_rule.daily_trigger.arn
}

data "archive_file" "api_zip" {
  type        = "zip"
  source_dir  = "${path.module}/../lambda/api"
  output_path = "${path.module}/../lambda/api.zip"
}

resource "aws_lambda_function" "api" {
  function_name    = "${var.project_name}-api"
  role             = aws_iam_role.lambda_api_role.arn
  handler          = "handler.lambda_handler"
  runtime          = "python3.12"
  filename         = data.archive_file.api_zip.output_path
  source_code_hash = data.archive_file.api_zip.output_base64sha256
  timeout          = 15

  environment {
    variables = {
      DYNAMODB_TABLE  = var.dynamodb_table_name
      AWS_REGION_NAME = var.aws_region
    }
  }

  tags = {
    Project = var.project_name
  }
}

resource "aws_apigatewayv2_api" "main" {
  name          = "${var.project_name}-api"
  protocol_type = "HTTP"

  cors_configuration {
    allow_origins = ["*"]
    allow_methods = ["GET", "OPTIONS"]
    allow_headers = ["Content-Type"]
  }

  tags = {
    Project = var.project_name
  }
}

resource "aws_apigatewayv2_stage" "default" {
  api_id      = aws_apigatewayv2_api.main.id
  name        = "$default"
  auto_deploy = true
}

resource "aws_apigatewayv2_integration" "api_lambda" {
  api_id             = aws_apigatewayv2_api.main.id
  integration_type   = "AWS_PROXY"
  integration_uri    = aws_lambda_function.api.invoke_arn
  integration_method = "POST"
}

resource "aws_apigatewayv2_route" "get_movers" {
  api_id    = aws_apigatewayv2_api.main.id
  route_key = "GET /movers"
  target    = "integrations/${aws_apigatewayv2_integration.api_lambda.id}"
}

resource "aws_lambda_permission" "allow_apigw" {
  statement_id  = "AllowAPIGatewayInvoke"
  action        = "lambda:InvokeFunction"
  function_name = aws_lambda_function.api.function_name
  principal     = "apigateway.amazonaws.com"
  source_arn    = "${aws_apigatewayv2_api.main.execution_arn}/*/*"
}

resource "aws_s3_bucket" "frontend" {
  bucket = "${var.project_name}-frontend-${random_id.suffix.hex}"

  tags = {
    Project = var.project_name
  }
}

resource "random_id" "suffix" {
  byte_length = 4
}

resource "aws_s3_bucket_public_access_block" "frontend" {
  bucket = aws_s3_bucket.frontend.id

  block_public_acls       = false
  block_public_policy     = false
  ignore_public_acls      = false
  restrict_public_buckets = false
}

resource "aws_s3_bucket_website_configuration" "frontend" {
  bucket = aws_s3_bucket.frontend.id

  index_document {
    suffix = "index.html"
  }

  error_document {
    key = "index.html"
  }
}

resource "aws_s3_bucket_policy" "frontend_public" {
  bucket = aws_s3_bucket.frontend.id

  depends_on = [aws_s3_bucket_public_access_block.frontend]

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Sid       = "PublicReadGetObject"
        Effect    = "Allow"
        Principal = "*"
        Action    = "s3:GetObject"
        Resource  = "${aws_s3_bucket.frontend.arn}/*"
      }
    ]
  })
}