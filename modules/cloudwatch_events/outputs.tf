output "start_event_rule_name" {
  value = aws_cloudwatch_event_rule.start_schedule.name
}

output "stop_event_rule_name" {
  value = aws_cloudwatch_event_rule.stop_schedule.name
}
