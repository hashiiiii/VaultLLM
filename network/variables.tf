variable "aws_region" {
  description = "AWS region to deploy resources"
  type        = string
  default     = "ap-northeast-1" # Tokyo
}

# 後ほど Availability Zone など他の変数も追加します 

variable "vpc_cidr" {
  description = "CIDR block for the VPC"
  type        = string
  default     = "10.0.0.0/16"
}

variable "availability_zones" {
  description = "List of Availability Zones to use for subnets"
  type        = list(string)
  # Note: Choose AZs available in your selected region (ap-northeast-1)
  # Example: ["ap-northeast-1a", "ap-northeast-1c"]
  # For MVP, starting with one AZ is acceptable.
  default     = ["ap-northeast-1c"]
}

variable "public_subnet_cidrs" {
  description = "List of CIDR blocks for public subnets (must match the number of AZs)"
  type        = list(string)
  # Ensure the number of CIDRs matches the number of AZs
  default     = ["10.0.1.0/24"]
} 