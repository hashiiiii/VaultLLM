//terraform {
//  required_providers {
//    aws = {
//      source  = "hashicorp/aws"
//      version = "~> 5.0"
//    }
//  }
//}
//
//provider "aws" {
//  region = var.aws_region
//}

# TODO: Consider parameterizing CIDR blocks using variables for flexibility.
resource "aws_vpc" "main" {
  cidr_block           = var.vpc_cidr
  enable_dns_support   = true # Required for VPC Endpoints private DNS
  enable_dns_hostnames = true # Required for VPC Endpoints private DNS

  tags = {
    Name = "vaultllm-vpc"
  }
}

resource "aws_subnet" "public" {
  count = length(var.availability_zones)

  vpc_id            = aws_vpc.main.id
  cidr_block        = var.public_subnet_cidrs[count.index]
  availability_zone = var.availability_zones[count.index]

  # TODO: Explicitly define Availability Zone(s) for resilience and predictability.
  # availability_zone = var.aws_availability_zone

  map_public_ip_on_launch = true

  tags = {
    Name = "vaultllm-public-subnet-${var.availability_zones[count.index]}"
  }
}

# Internet Gateway for the VPC
resource "aws_internet_gateway" "main" {
  vpc_id = aws_vpc.main.id

  tags = {
    Name = "vaultllm-igw"
  }
}

# Route Table for the public subnet
resource "aws_route_table" "public" {
  vpc_id = aws_vpc.main.id

  route {
    cidr_block = "0.0.0.0/0" # Route for internet traffic
    gateway_id = aws_internet_gateway.main.id
  }

  tags = {
    Name = "vaultllm-public-route-table"
  }
}

# Route Table Association for the public subnet
resource "aws_route_table_association" "public" {
  count = length(var.availability_zones)

  subnet_id      = aws_subnet.public[count.index].id
  route_table_id = aws_route_table.public.id
}

# --- VPC Endpoints for SSM ---

# Security Group for VPC Endpoints (Allow HTTPS from VPC)
resource "aws_security_group" "vpc_endpoint_sg" {
  name        = "vaultllm-vpc-endpoint-sg"
  description = "Allow HTTPS traffic from within the VPC for endpoints"
  vpc_id      = aws_vpc.main.id

  ingress {
    description = "Allow HTTPS from VPC CIDR"
    from_port   = 443
    to_port     = 443
    protocol    = "tcp"
    cidr_blocks = [aws_vpc.main.cidr_block]
  }

  # Egress is typically allowed by default, but can be restricted if needed.
  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = {
    Name = "vaultllm-vpc-endpoint-sg"
  }
}

# VPC Endpoint for SSM
resource "aws_vpc_endpoint" "ssm" {
  vpc_id            = aws_vpc.main.id
  service_name      = "com.amazonaws.${var.aws_region}.ssm"
  vpc_endpoint_type = "Interface"
  subnet_ids        = aws_subnet.public[*].id
  security_group_ids = [aws_security_group.vpc_endpoint_sg.id]
  private_dns_enabled = true

  tags = {
    Name = "vaultllm-vpc-endpoint-ssm"
  }
}

# VPC Endpoint for EC2 Messages
resource "aws_vpc_endpoint" "ec2messages" {
  vpc_id            = aws_vpc.main.id
  service_name      = "com.amazonaws.${var.aws_region}.ec2messages"
  vpc_endpoint_type = "Interface"
  subnet_ids        = aws_subnet.public[*].id
  security_group_ids = [aws_security_group.vpc_endpoint_sg.id]
  private_dns_enabled = true

  tags = {
    Name = "vaultllm-vpc-endpoint-ec2messages"
  }
}

# VPC Endpoint for SSM Messages
resource "aws_vpc_endpoint" "ssmmessages" {
  vpc_id            = aws_vpc.main.id
  service_name      = "com.amazonaws.${var.aws_region}.ssmmessages"
  vpc_endpoint_type = "Interface"
  subnet_ids        = aws_subnet.public[*].id
  security_group_ids = [aws_security_group.vpc_endpoint_sg.id]
  private_dns_enabled = true

  tags = {
    Name = "vaultllm-vpc-endpoint-ssmmessages"
  }
}

# --- VPC Endpoints for ECR ---

resource "aws_vpc_endpoint" "ecr_dkr" {
  vpc_id            = aws_vpc.main.id
  service_name      = "com.amazonaws.${var.aws_region}.ecr.dkr"
  vpc_endpoint_type = "Interface"
  subnet_ids        = aws_subnet.public[*].id # For simplicity, use public subnet. Consider private subnets for production.
  security_group_ids = [aws_security_group.vpc_endpoint_sg.id]
  private_dns_enabled = true

  tags = {
    Name = "vaultllm-vpc-endpoint-ecr-dkr"
  }
}

resource "aws_vpc_endpoint" "ecr_api" {
  vpc_id            = aws_vpc.main.id
  service_name      = "com.amazonaws.${var.aws_region}.ecr.api"
  vpc_endpoint_type = "Interface"
  subnet_ids        = aws_subnet.public[*].id # For simplicity, use public subnet. Consider private subnets for production.
  security_group_ids = [aws_security_group.vpc_endpoint_sg.id]
  private_dns_enabled = true

  tags = {
    Name = "vaultllm-vpc-endpoint-ecr-api"
  }
}

# --- VPC Endpoint for CloudWatch Logs ---

resource "aws_vpc_endpoint" "logs" {
  vpc_id            = aws_vpc.main.id
  service_name      = "com.amazonaws.${var.aws_region}.logs"
  vpc_endpoint_type = "Interface"
  subnet_ids        = aws_subnet.public[*].id # For simplicity, use public subnet. Consider private subnets for production.
  security_group_ids = [aws_security_group.vpc_endpoint_sg.id]
  private_dns_enabled = true

  tags = {
    Name = "vaultllm-vpc-endpoint-logs"
  }
}

# --- VPC Endpoint for S3 (Gateway) ---

resource "aws_vpc_endpoint" "s3" {
  vpc_id            = aws_vpc.main.id
  service_name      = "com.amazonaws.${var.aws_region}.s3"
  vpc_endpoint_type = "Gateway"

  # Associate with the route table(s) where tasks/instances reside
  route_table_ids = [aws_route_table.public.id] # If using private subnets, add their route table IDs too

  tags = {
    Name = "vaultllm-vpc-endpoint-s3-gateway"
  }
}

# --- Security Group for ALB ---
resource "aws_security_group" "alb_sg" {
  name        = "${var.project_name}-alb-sg"
  description = "Allow HTTP/HTTPS inbound traffic to ALB and allow outbound to tasks"
  vpc_id      = aws_vpc.main.id # Use the existing VPC ID

  ingress {
    description = "Allow HTTP from anywhere"
    from_port   = 80
    to_port     = 80
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
    ipv6_cidr_blocks = ["::/0"]
  }

  ingress {
    description = "Allow HTTPS from anywhere"
    from_port   = 443
    to_port     = 443
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
    ipv6_cidr_blocks = ["::/0"]
  }

  # Egress rule will be defined separately using aws_security_group_rule

  tags = {
    Name = "${var.project_name}-alb-sg"
  }
}

# --- Application Load Balancer (ALB) ---
resource "aws_lb" "main" {
  name               = "${var.project_name}-alb"
  internal           = false # Internet-facing
  load_balancer_type = "application"
  security_groups    = [aws_security_group.alb_sg.id] # Directly reference the SG defined in this module
  subnets            = aws_subnet.public[*].id      # Directly reference the subnets defined in this module

  # Enable access logs (optional but recommended)
  # access_logs {
  #   bucket  = aws_s3_bucket.lb_logs.bucket # Need to define S3 bucket for logs if enabling
  #   prefix  = "${var.project_name}-lb-logs"
  #   enabled = true
  # }

  tags = {
    Name = "${var.project_name}-alb"
  }
} 