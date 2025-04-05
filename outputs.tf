output "application_endpoint" {
  description = "The DNS endpoint for the deployed application (ALB)"
  value       = module.network.alb_dns_name
} 