variable "aws_region" {
  description = "AWS region to deploy resources"
  type        = string
  default     = "ap-northeast-1" # Tokyo
}

# 後ほど Availability Zone など他の変数も追加します 