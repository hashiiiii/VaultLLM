variable "aws_region" {
  description = "AWS region to deploy resources"
  type        = string
  default     = "ap-northeast-1"
}

variable "project_name" {
  description = "Base name for resources"
  type        = string
  default     = "vaultllm"
}

variable "environment" {
  description = "The deployment environment name (e.g., development, staging, production)."
  type        = string
  default     = "development"
}

variable "vpc_cidr" {
  description = "The base CIDR block for the VPC."
  type        = string
  default     = "10.0.0.0/16"
}

variable "availability_zones" {
  description = "A list of Availability Zones to use for the subnets."
  type        = list(string)
  default     = ["ap-northeast-1a", "ap-northeast-1c"]
}

variable "target_account_id" {
  description = "The AWS Account ID where resources will be deployed."
  type        = string
}

variable "webui_container_port" {
  description = "The port the Open WebUI container listens on."
  type        = number
  default     = 8080
}

variable "ecs_task_cpu" {
  description = "CPU units for the ECS task (e.g., 1024 for 1 vCPU)"
  type        = string
  default     = "4096" # Increased based on local testing (4 vCPU)
}

variable "ecs_task_memory" {
  description = "Memory (MiB) for the ECS task (e.g., 2048 for 2GB)"
  type        = string
  default     = "30720" # Increased based on local testing (30 GB)
}

variable "ollama_image" {
  description = "Docker image for Ollama (e.g., ollama/ollama:latest or ECR path)"
  type        = string
  default     = "ollama/ollama:latest"
}

variable "webui_image" {
  description = "Docker image for Open WebUI (e.g., ghcr.io/open-webui/open-webui:main or ECR path)"
  type        = string
  default     = "ghcr.io/open-webui/open-webui:main"
}

variable "ollama_container_port" {
  description = "Container port for Ollama API"
  type        = number
  default     = 11434
}

variable "ecs_desired_count" {
  description = "Desired number of tasks for the ECS service when running"
  type        = number
  default     = 1 # Default to 1 task when service is running
}

variable "run_service" {
  description = "Set to false to scale ECS service tasks to zero when not in use."
  type        = bool
  default     = true # Service runs by default
}

variable "domain_name" {
  description = "The domain name for the application (e.g., vaultllm.example.com)"
  type        = string
}