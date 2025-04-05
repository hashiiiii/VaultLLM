output "ecs_cluster_name" {
  description = "The name of the ECS cluster"
  value       = aws_ecs_cluster.main.name
}

output "ecs_service_name" {
  description = "The name of the ECS service"
  value       = aws_ecs_service.main.name
}

output "ecs_task_definition_arn" {
  description = "The ARN of the ECS task definition"
  value       = aws_ecs_task_definition.main.arn
}

output "ecs_task_security_group_id" {
  description = "The ID of the security group for ECS tasks"
  value       = aws_security_group.ecs_task_sg.id
}

output "cloudwatch_log_group_name" {
  description = "The name of the CloudWatch log group for tasks"
  value       = aws_cloudwatch_log_group.ecs_task_logs.name
} 