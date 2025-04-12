variable "aws_region" {
  description = "AWS region to deploy resources"
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

variable "public_subnet_cidrs" {
  description = "A list of CIDR blocks for the public subnets."
  type        = list(string)
}

variable "project_name" {
  description = "Base name for resources to ensure uniqueness"
  type        = string
}

variable "acm_certificate_arn" {
  description = "ARN of the ACM certificate for the HTTPS listener"
  type        = string
}

variable "ecs_target_group_arn" {
  description = "ARN of the ECS target group to forward traffic to"
  type        = string
} 