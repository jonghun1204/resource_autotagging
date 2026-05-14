provider "aws" {
  alias   = "central"
  region  = var.central_tagging_region
  profile = var.aws_profile
}

provider "aws" {
  alias   = "source1"
  region  = var.source_region_1
  profile = var.aws_profile
}

provider "aws" {
  alias   = "source2"
  region  = var.source_region_2
  profile = var.aws_profile
}

provider "aws" {
  alias   = "source3"
  region  = var.source_region_3
  profile = var.aws_profile
}

provider "aws" {
  alias   = "source4"
  region  = var.source_region_4
  profile = var.aws_profile
}

provider "aws" {
  alias   = "source5"
  region  = var.source_region_5
  profile = var.aws_profile
}

data "aws_caller_identity" "current" {
  provider = aws.central
}

data "aws_region" "central" {
  provider = aws.central
}

resource "aws_sqs_queue" "tagging_queue" {
  provider                   = aws.central
  name                       = "resource-autotagging-queue"
  visibility_timeout_seconds = 60
  delay_seconds              = 20
  message_retention_seconds  = 600

  tags = {
    Name        = "resource-autotagging-queue"
    Environment = "production"
  }
}

resource "aws_iam_role" "lambda_role" {
  provider = aws.central
  name     = "resource-autotagging-lambda-role"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Action = "sts:AssumeRole"
        Effect = "Allow"
        Principal = {
          Service = "lambda.amazonaws.com"
        }
      }
    ]
  })
}

resource "aws_iam_role_policy" "lambda_policy" {
  provider = aws.central
  name     = "resource-autotagging-lambda-policy"
  role     = aws_iam_role.lambda_role.id

  policy = templatefile("${path.module}/../lambda_policy.json.tpl", {
    sqs_queue_arn = aws_sqs_queue.tagging_queue.arn
  })
}

resource "aws_iam_role_policy_attachment" "lambda_basic" {
  provider   = aws.central
  role       = aws_iam_role.lambda_role.name
  policy_arn = "arn:aws:iam::aws:policy/service-role/AWSLambdaBasicExecutionRole"
}

data "archive_file" "lambda_zip" {
  type        = "zip"
  source_file = "${path.module}/../lambda_function.py"
  output_path = "${path.module}/lambda_function.zip"
}

resource "aws_lambda_function" "tagging_lambda" {
  provider         = aws.central
  filename         = data.archive_file.lambda_zip.output_path
  function_name    = "resource-autotagging-lambda"
  role             = aws_iam_role.lambda_role.arn
  handler          = "lambda_function.lambda_handler"
  source_code_hash = data.archive_file.lambda_zip.output_base64sha256
  runtime          = "python3.13"
  timeout          = 20

  tags = {
    Name        = "resource-autotagging"
    Environment = "production"
  }
}

resource "aws_lambda_event_source_mapping" "sqs_trigger" {
  provider         = aws.central
  event_source_arn = aws_sqs_queue.tagging_queue.arn
  function_name    = aws_lambda_function.tagging_lambda.arn
}

resource "aws_cloudwatch_event_rule" "central_tagging_rule" {
  provider    = aws.central
  name        = "resource-autotagging-central-rule"
  description = "Capture resource creation events for auto-tagging"

  event_pattern = file("${path.module}/../event.json")
}

resource "aws_cloudwatch_event_target" "central_sqs" {
  provider  = aws.central
  rule      = aws_cloudwatch_event_rule.central_tagging_rule.name
  target_id = "SendToSQS"
  arn       = aws_sqs_queue.tagging_queue.arn
}

resource "aws_sqs_queue_policy" "tagging_queue_policy" {
  provider  = aws.central
  queue_url = aws_sqs_queue.tagging_queue.id

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect = "Allow"
        Principal = {
          Service = "events.amazonaws.com"
        }
        Action   = "sqs:SendMessage"
        Resource = aws_sqs_queue.tagging_queue.arn
        Condition = {
          ArnEquals = {
            "aws:SourceArn" = aws_cloudwatch_event_rule.central_tagging_rule.arn
          }
        }
      }
    ]
  })
}

resource "aws_iam_role" "source_eventbridge_role" {
  provider = aws.central
  name     = "resource-autotagging-source-eventbridge-role"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect = "Allow"
        Principal = {
          Service = "events.amazonaws.com"
        }
        Action = "sts:AssumeRole"
      }
    ]
  })
}

resource "aws_iam_role_policy" "source_eventbridge_policy" {
  provider = aws.central
  name     = "resource-autotagging-source-eventbridge-policy"
  role     = aws_iam_role.source_eventbridge_role.id

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect = "Allow"
        Action = "events:PutEvents"
        Resource = "arn:aws:events:${var.central_tagging_region}:${data.aws_caller_identity.current.account_id}:event-bus/default"
      }
    ]
  })
}

resource "aws_cloudwatch_event_rule" "source1_tagging_rule" {
  count       = var.source_region_1 != "" ? 1 : 0
  provider    = aws.source1
  name        = "resource-autotagging-source-rule"
  description = "Forward resource creation events to central tagging region"

  event_pattern = file("${path.module}/../event.json")
}

resource "aws_cloudwatch_event_target" "source1_to_central" {
  count     = var.source_region_1 != "" ? 1 : 0
  provider  = aws.source1
  rule      = aws_cloudwatch_event_rule.source1_tagging_rule[0].name
  target_id = "SendToCentralEventBus"
  arn       = "arn:aws:events:${var.central_tagging_region}:${data.aws_caller_identity.current.account_id}:event-bus/default"
  role_arn  = aws_iam_role.source_eventbridge_role.arn
}

resource "aws_cloudwatch_event_rule" "source2_tagging_rule" {
  count       = var.source_region_2 != "" ? 1 : 0
  provider    = aws.source2
  name        = "resource-autotagging-source-rule"
  description = "Forward resource creation events to central tagging region"

  event_pattern = file("${path.module}/../event.json")
}

resource "aws_cloudwatch_event_target" "source2_to_central" {
  count     = var.source_region_2 != "" ? 1 : 0
  provider  = aws.source2
  rule      = aws_cloudwatch_event_rule.source2_tagging_rule[0].name
  target_id = "SendToCentralEventBus"
  arn       = "arn:aws:events:${var.central_tagging_region}:${data.aws_caller_identity.current.account_id}:event-bus/default"
  role_arn  = aws_iam_role.source_eventbridge_role.arn
}

resource "aws_cloudwatch_event_rule" "source3_tagging_rule" {
  count       = var.source_region_3 != "" ? 1 : 0
  provider    = aws.source3
  name        = "resource-autotagging-source-rule"
  description = "Forward resource creation events to central tagging region"

  event_pattern = file("${path.module}/../event.json")
}

resource "aws_cloudwatch_event_target" "source3_to_central" {
  count     = var.source_region_3 != "" ? 1 : 0
  provider  = aws.source3
  rule      = aws_cloudwatch_event_rule.source3_tagging_rule[0].name
  target_id = "SendToCentralEventBus"
  arn       = "arn:aws:events:${var.central_tagging_region}:${data.aws_caller_identity.current.account_id}:event-bus/default"
  role_arn  = aws_iam_role.source_eventbridge_role.arn
}

resource "aws_cloudwatch_event_rule" "source4_tagging_rule" {
  count       = var.source_region_4 != "" ? 1 : 0
  provider    = aws.source4
  name        = "resource-autotagging-source-rule"
  description = "Forward resource creation events to central tagging region"

  event_pattern = file("${path.module}/../event.json")
}

resource "aws_cloudwatch_event_rule" "source4_tagging_rule" {
  count       = var.source_region_4 != "" ? 1 : 0
  provider    = aws.source4
  name        = "resource-autotagging-source-rule"
  description = "Forward resource creation events to central tagging region"

  event_pattern = file("${path.module}/../event.json")
}

resource "aws_cloudwatch_event_rule" "source5_tagging_rule" {
  count       = var.source_region_5 != "" ? 1 : 0
  provider    = aws.source5
  name        = "resource-autotagging-source-rule"
  description = "Forward resource creation events to central tagging region"

  event_pattern = file("${path.module}/../event.json")
}

resource "aws_cloudwatch_event_rule" "source5_tagging_rule" {
  count       = var.source_region_5 != "" ? 1 : 0
  provider    = aws.source5
  name        = "resource-autotagging-source-rule"
  description = "Forward resource creation events to central tagging region"

  event_pattern = file("${path.module}/../event.json")
}