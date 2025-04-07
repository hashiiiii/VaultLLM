variable "aws_region" {
  description = "AWS region to deploy resources"
  type        = string
}

variable "project_name" {
  description = "Base name for resources to ensure uniqueness"
  type        = string
}

variable "ecs_task_cpu" {
  description = "CPU units for the ECS task (e.g., 1024 for 1 vCPU)"
  type        = string
}

variable "ecs_task_memory" {
  description = "Memory (MiB) for the ECS task (e.g., 2048 for 2GB)"
  type        = string
}

variable "ollama_image" {
  description = "Docker image for Ollama (e.g., ollama/ollama or ECR path)"
  type        = string
}

variable "ollama_container_port" {
  description = "Container port for Ollama API"
  type        = number
}

variable "webui_image" {
  description = "Docker image for Open WebUI (e.g., ghcr.io/open-webui/open-webui:main or ECR path)"
  type        = string
}

variable "webui_container_port" {
  description = "Container port for Open WebUI"
  type        = number
}

variable "desired_count" {
  description = "Desired number of tasks for the ECS service"
  type        = number
}

variable "assign_public_ip" {
  description = "Whether to assign public IPs to Fargate tasks (should be false with ALB)"
  type        = bool
}

variable "vpc_id" {
  description = "ID of the VPC where ECS resources will be deployed"
  type        = string
}

variable "vpc_cidr_block" {
  description = "CIDR block of the VPC (used for ECS Task SG Egress)"
  type        = string
}

variable "public_subnet_ids" {
  description = "List of public subnet IDs for ECS tasks"
  type        = list(string)
}

variable "vpc_endpoint_sg_id" {
  description = "ID of the security group for VPC endpoints (used for ECS task SG Egress)"
  type        = string
}

variable "alb_arn" {
  description = "ARN of the Application Load Balancer for listener configuration"
  type        = string
}

variable "alb_security_group_id" {
  description = "ID of the ALB security group (used for ECS task SG Ingress)"
  type        = string
} 