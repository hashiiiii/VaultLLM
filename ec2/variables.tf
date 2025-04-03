variable "allowed_ip_cidr" {
  description = "CIDR block allowed to access the WebUI"
  type        = string
  default     = "106.139.138.188/32" # Default to your last known IP, update if needed
}

variable "ec2_ami_id" {
  description = "AMI ID for the EC2 instance"
  type        = string
  default     = "ami-05ec362ff4cffc793" # Default Amazon Linux 2 in ap-northeast-1
}

variable "ec2_instance_type" {
  description = "Instance type for the EC2 instance"
  type        = string
  default     = "t3.micro"
} 