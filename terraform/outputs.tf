output "central_region" {
  description = "중앙 태깅 리전"
  value       = var.central_tagging_region
}

output "central_sqs_queue_url" {
  description = "중앙 태깅 리전 SQS Queue URL"
  value       = aws_sqs_queue.tagging_queue.url
}

output "central_lambda_function_name" {
  description = "중앙 태깅 리전 Lambda Function Name"
  value       = aws_lambda_function.tagging_lambda.function_name
}

output "central_eventbridge_rule_arn" {
  description = "중앙 태깅 리전 EventBridge Rule ARN"
  value       = aws_cloudwatch_event_rule.central_tagging_rule.arn
}

output "source_region_1" {
  description = "소스 리전 1"
  value       = var.source_region_1 != "" ? var.source_region_1 : "비활성화"
}

output "source_region_1_eventbridge_rule_arn" {
  description = "소스 리전 1 EventBridge Rule ARN"
  value       = var.source_region_1 != "" ? aws_cloudwatch_event_rule.source1_tagging_rule[0].arn : "비활성화"
}

output "source_region_2" {
  description = "소스 리전 2"
  value       = var.source_region_2 != "" ? var.source_region_2 : "비활성화"
}

output "source_region_2_eventbridge_rule_arn" {
  description = "소스 리전 2 EventBridge Rule ARN"
  value       = var.source_region_2 != "" ? aws_cloudwatch_event_rule.source2_tagging_rule[0].arn : "비활성화"
}

output "source_region_3" {
  description = "소스 리전 3"
  value       = var.source_region_3 != "" ? var.source_region_3 : "비활성화"
}

output "source_region_3_eventbridge_rule_arn" {
  description = "소스 리전 3 EventBridge Rule ARN"
  value       = var.source_region_3 != "" ? aws_cloudwatch_event_rule.source3_tagging_rule[0].arn : "비활성화"
}

output "source_region_4" {
  description = "소스 리전 4"
  value       = var.source_region_4 != "" ? var.source_region_4 : "비활성화"
}

output "source_region_4_eventbridge_rule_arn" {
  description = "소스 리전 4 EventBridge Rule ARN"
  value       = var.source_region_4 != "" ? aws_cloudwatch_event_rule.source4_tagging_rule[0].arn : "비활성화"
}

output "source_region_5" {
  description = "소스 리전 5"
  value       = var.source_region_5 != "" ? var.source_region_5 : "비활성화"
}

output "source_region_5_eventbridge_rule_arn" {
  description = "소스 리전 5 EventBridge Rule ARN"
  value       = var.source_region_5 != "" ? aws_cloudwatch_event_rule.source5_tagging_rule[0].arn : "비활성화"
}