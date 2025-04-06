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

# Add other common variables if needed, e.g., tags 