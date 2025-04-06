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
  default     = ["ap-northeast-1a", "ap-northeast-1c", "ap-northeast-1d"]
}

variable "target_account_id" {
  description = "The AWS Account ID where resources will be deployed."
  type        = string
  default     = "619416722781"
}

variable "webui_container_port" {
  description = "The port the Open WebUI container listens on."
  type        = number
  default     = 8080
}

# Add other common variables if needed, e.g., tags