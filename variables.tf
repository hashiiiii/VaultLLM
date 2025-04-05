variable "aws_region" {
  description = "AWS region to deploy resources"
  type        = string
  default     = "ap-northeast-1" # Or your preferred default
}

variable "project_name" {
  description = "Base name for resources"
  type        = string
  default     = "vaultllm"
}

# Add other common variables if needed, e.g., tags 