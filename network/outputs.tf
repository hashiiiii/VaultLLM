output "vpc_id" {
  description = "The ID of the VPC"
  value       = aws_vpc.main.id
}

output "vpc_cidr_block" {
  description = "The CIDR block of the VPC."
  value       = aws_vpc.main.cidr_block
}

output "public_subnet_ids" {
  description = "List of IDs of the public subnets"
  value       = aws_subnet.public[*].id
}

output "vpc_endpoint_sg_id" {
  description = "The ID of the security group for VPC endpoints"
  value       = aws_security_group.vpc_endpoint_sg.id
}

output "alb_sg_id" {
  description = "The ID of the security group attached to the ALB."
  value       = aws_security_group.alb_sg.id
}

output "alb_arn" {
  description = "The ARN of the load balancer."
  value       = aws_lb.main.arn
}

output "alb_dns_name" {
  description = "DNS name of the Application Load Balancer"
  value       = aws_lb.main.dns_name
}

output "alb_zone_id" {
  description = "Canonical hosted zone ID of the Application Load Balancer"
  value       = aws_lb.main.zone_id
}

output "efs_file_system_id" {
  description = "The ID of the created EFS file system"
  value       = aws_efs_file_system.main.id
}

output "efs_security_group_id" {
  description = "The ID of the security group for the EFS file system"
  value       = aws_security_group.efs_sg.id
}

output "public_subnet_azs" {
  description = "Availability Zones for the public subnets"
  value       = aws_subnet.public[*].availability_zone
} 