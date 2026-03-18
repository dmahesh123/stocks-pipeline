output "api_endpoint" {
  description = "The public URL for the GET /movers API endpoint"
  value       = "${aws_apigatewayv2_api.main.api_endpoint}/movers"
}

output "frontend_url" {
  description = "The public URL of the S3 hosted frontend website"
  value       = "http://${aws_s3_bucket_website_configuration.frontend.website_endpoint}"
}

output "dynamodb_table_name" {
  description = "The name of the DynamoDB table"
  value       = aws_dynamodb_table.top_movers.name
}