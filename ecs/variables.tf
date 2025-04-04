variable "aws_region" {
  description = "AWS region to deploy resources"
  type        = string
  default     = "ap-northeast-1" # Tokyo
}

variable "project_name" {
  description = "Base name for resources to ensure uniqueness"
  type        = string
  default     = "vaultllm"
}

variable "ecs_cluster_name" {
  description = "Name for the ECS cluster"
  type        = string
  default     = "main-cluster" # Combined with project_name later
}

variable "ecs_service_name" {
  description = "Name for the ECS service"
  type        = string
  default     = "webui-service" # Combined with project_name later
}

variable "ecs_task_family" {
  description = "Family name for the ECS task definition"
  type        = string
  default     = "webui-task" # Combined with project_name later
}

variable "ecs_task_cpu" {
  description = "CPU units for the ECS task"
  type        = string
  default     = "1024" # 1 vCPU
}

variable "ecs_task_memory" {
  description = "Memory (MiB) for the ECS task"
  type        = string
  default     = "2048" # 2GB
}

variable "ollama_container_name" {
  description = "Name for the Ollama container"
  type        = string
  default     = "ollama"
}

variable "ollama_image" {
  description = "Docker image for Ollama"
  type        = string
  default     = "ollama/ollama"
}

variable "ollama_container_port" {
  description = "Container port for Ollama API"
  type        = number
  default     = 11434
}

variable "ollama_volume_name" {
  description = "Volume name for Ollama data"
  type        = string
  default     = "ollama_data"
}

variable "ollama_volume_path" {
  description = "Container path for Ollama data volume"
  type        = string
  default     = "/root/.ollama"
}

variable "webui_container_name" {
  description = "Name for the Open WebUI container"
  type        = string
  default     = "open-webui"
}

variable "webui_image" {
  description = "Docker image for Open WebUI"
  type        = string
  default     = "ghcr.io/open-webui/open-webui:main"
}

variable "webui_container_port" {
  description = "Container port for Open WebUI"
  type        = number
  default     = 8080
}

variable "webui_volume_name" {
  description = "Volume name for Open WebUI data"
  type        = string
  default     = "open_webui_data"
}

variable "webui_volume_path" {
  description = "Container path for Open WebUI data volume"
  type        = string
  default     = "/app/backend/data"
}

variable "log_group_name" {
  description = "CloudWatch log group name for ECS tasks"
  type        = string
  default     = "/ecs/tasks" # Combined with project_name later
}

variable "desired_count" {
  description = "Desired number of tasks for the ECS service"
  type        = number
  default     = 0 # Default to 0 (stopped)
}

variable "assign_public_ip" {
  description = "Whether to assign public IPs to Fargate tasks"
  type        = bool
  default     = true # Set to false if using ALB exclusively later
} 