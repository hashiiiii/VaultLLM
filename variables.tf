variable "aws_region" {
  description = "AWS region to deploy resources"
  type        = string
}

variable "project_name" {
  description = "Base name for resources"
  type        = string
}

variable "environment" {
  description = "The deployment environment name (e.g., development, staging, production)."
  type        = string
}

variable "vpc_cidr" {
  description = "The base CIDR block for the VPC."
  type        = string
}

variable "availability_zones" {
  description = "A list of Availability Zones to use for the subnets."
  type        = list(string)
}

variable "target_account_id" {
  description = "The AWS Account ID where resources will be deployed."
  type        = string
}

variable "webui_container_port" {
  description = "The port the Open WebUI container listens on."
  type        = number
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
  description = "Docker image for Ollama (e.g., ollama/ollama:latest or ECR path)"
  type        = string
}

variable "webui_image" {
  description = "Docker image for Open WebUI (e.g., ghcr.io/open-webui/open-webui:main or ECR path)"
  type        = string
}

variable "ollama_container_port" {
  description = "Container port for Ollama API"
  type        = number
}

variable "nfs_port" {
  description = "The standard port number for NFS traffic."
  type        = number
}

variable "ecs_desired_count" {
  description = "Desired number of tasks for the ECS service when running"
  type        = number
}

variable "run_service" {
  description = "Set to false to scale ECS service tasks to zero when not in use."
  type        = bool
}

variable "domain_name" {
  description = "The domain name for the application (e.g., vaultllm.example.com)"
  type        = string
}

variable "webui_data_container_path" {
  description = "The path inside the WebUI container where persistent data (mounted from EFS) should be stored."
  type        = string
}

variable "health_check_path" {
  description = "The destination for the health check request for the WebUI target group."
  type        = string
}

variable "health_check_matcher" {
  description = "The HTTP codes to use when checking for a successful response from the WebUI target group."
  type        = string
}