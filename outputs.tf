output "application_endpoint" {
  description = "The DNS endpoint for the deployed application (ALB)"
  value       = module.network.alb_dns_name
}

# --- ECR Repository Outputs ---

output "ollama_ecr_repository_url" {
  description = "The URL of the Ollama ECR repository"
  value       = aws_ecr_repository.ollama.repository_url
}

output "webui_ecr_repository_url" {
  description = "The URL of the Open WebUI ECR repository"
  value       = aws_ecr_repository.webui.repository_url
} 