output "start_event_rule_name" {
  value = try(aws_cloudwatch_event_rule.start_schedule[0].name, null)
}

output "stop_event_rule_name" {
  value = try(aws_cloudwatch_event_rule.stop_schedule[0].name, null)
}

output "snapshot_cleanup_rule_name" {
  value = try(aws_cloudwatch_event_rule.cleanup_snapshots[0].name, null)
}

output "origin_health_probe_rule_name" {
  value = try(aws_cloudwatch_event_rule.origin_health_probe[0].name, null)
}
