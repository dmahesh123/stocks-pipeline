variable "aws_region" {
    description = "AWS region to deploy all resources into"
    type = string
    default = us-east-1
}

variable "project_name" {
    description = "Name to label all resources"
    type = string
    default = "stocks-pipeline"
}

variable "dynamodb_table_name" {
    description = "DynamoDb table name that stores the daily top movers"
    type = string
    default = "stocks-top-movers"
}

variable "massive_api_key" {
    description = "Massive API key for deploy time"
    type = string
    sensitive = True
}

variable "anthropic_api_key" {
    description = "Anthropic API key for deploy time"
    type = string
    sensitive = True
}

variable "cron_schedule" {
    description = "Eventbridge cron schedule for the daily ingest Lambda"
    type = string
    default = "cron(0 21 * * ? *)" #market close at 4pm ET
}