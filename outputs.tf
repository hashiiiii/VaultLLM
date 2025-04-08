output "application_endpoint" {
  description = "The DNS endpoint for the deployed application (ALB)"
  value       = module.network.alb_dns_name
}

output "ollama_ecr_repository_url" {
  description = "The URL of the Ollama ECR repository"
  value       = aws_ecr_repository.ollama.repository_url
}

output "webui_ecr_repository_url" {
  description = "The URL of the Open WebUI ECR repository"
  value       = aws_ecr_repository.webui.repository_url
}

output "route53_hosted_zone_id" {
  description = "The ID of the created Route 53 hosted zone"
  value       = aws_route53_zone.main.zone_id
}

output "route53_name_servers" {
  description = "The name servers assigned to the created Route 53 hosted zone. Update your domain registrar with these values."
  value       = aws_route53_zone.main.name_servers
} 