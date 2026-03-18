resource "aws_iam_role" "lambda_ingest_role" {
  name = "${var.project_name}-ingest-role"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Action    = "sts:AssumeRole"
        Effect    = "Allow"
        Principal = { Service = "lambda.amazonaws.com" }
      }
    ]
  })

  tags = {
    Project = var.project_name
  }
}

resource "aws_iam_role_policy_attachment" "ingest_logs" {
  role       = aws_iam_role.lambda_ingest_role.name
  policy_arn = "arn:aws:iam::aws:policy/service-role/AWSLambdaBasicExecutionRole"
}

resource "aws_iam_policy" "ingest_dynamodb" {
  name        = "${var.project_name}-ingest-dynamodb-policy"
  description = "Allows ingest Lambda to write records to the top movers table"

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect   = "Allow"
        Action   = ["dynamodb:PutItem"]
        Resource = aws_dynamodb_table.top_movers.arn
      }
    ]
  })
}

resource "aws_iam_role_policy_attachment" "ingest_dynamodb_attach" {
  role       = aws_iam_role.lambda_ingest_role.name
  policy_arn = aws_iam_policy.ingest_dynamodb.arn
}

resource "aws_iam_role" "lambda_api_role" {
  name = "${var.project_name}-api-role"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Action    = "sts:AssumeRole"
        Effect    = "Allow"
        Principal = { Service = "lambda.amazonaws.com" }
      }
    ]
  })

  tags = {
    Project = var.project_name
  }
}

resource "aws_iam_role_policy_attachment" "api_logs" {
  role       = aws_iam_role.lambda_api_role.name
  policy_arn = "arn:aws:iam::aws:policy/service-role/AWSLambdaBasicExecutionRole"
}

resource "aws_iam_policy" "api_dynamodb" {
  name        = "${var.project_name}-api-dynamodb-policy"
  description = "Allows API Lambda to read records from the top movers table"

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect   = "Allow"
        Action   = ["dynamodb:GetItem", "dynamodb:Scan"]
        Resource = aws_dynamodb_table.top_movers.arn
      }
    ]
  })
}

resource "aws_iam_role_policy_attachment" "api_dynamodb_attach" {
  role       = aws_iam_role.lambda_api_role.name
  policy_arn = aws_iam_policy.api_dynamodb.arn
}