output "api_url" {
  description = "Base URL — POST to <api_url>/order"
  value       = aws_apigatewayv2_api.main.api_endpoint
}

output "post_order_url" {
  description = "Full URL to curl"
  value       = "${aws_apigatewayv2_api.main.api_endpoint}/order"
}

output "queue_url" {
  value = aws_sqs_queue.driver_updates.url
}

output "queue_arn" {
  value = aws_sqs_queue.driver_updates.arn
}

output "queue_name" {
  value = aws_sqs_queue.driver_updates.name
}

output "lambda_function_name" {
  value = aws_lambda_function.driver_update.function_name
}
