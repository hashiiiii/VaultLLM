terraform {
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 5.0"
    }
  }
}

provider "aws" {
  region = var.aws_region
}

# TODO: Consider parameterizing CIDR blocks using variables for flexibility.
resource "aws_vpc" "main" {
  cidr_block = "10.0.0.0/16"

  tags = {
    Name = "vaultllm-vpc"
  }
}

resource "aws_subnet" "public" {
  vpc_id     = aws_vpc.main.id
  cidr_block = "10.0.1.0/24"

  # TODO: Explicitly define Availability Zone(s) for resilience and predictability.
  # availability_zone = var.aws_availability_zone

  map_public_ip_on_launch = true

  tags = {
    Name = "vaultllm-public-subnet"
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

# Associate the public route table with the public subnet
resource "aws_route_table_association" "public" {
  subnet_id      = aws_subnet.public.id
  route_table_id = aws_route_table.public.id
}

# Security Group for the EC2 instance
resource "aws_security_group" "allow_ssh_http" {
  name        = "vaultllm-allow-ssh-http"
  description = "Allow SSH and HTTP (Open WebUI) inbound traffic"
  vpc_id      = aws_vpc.main.id

  ingress {
    description      = "SSH from specific IP"
    from_port        = 22
    to_port          = 22
    protocol         = "tcp"
    # TODO: Update this IP if your IP changes, or manage allowed IPs more dynamically (e.g., variables, data sources, VPN ranges).
    cidr_blocks      = ["106.139.138.188/32"] # Restricted to your IP
  }

  ingress {
    description      = "Open WebUI from specific IP"
    from_port        = 8080
    to_port          = 8080
    protocol         = "tcp"
    # TODO: Update this IP if your IP changes, or manage allowed IPs more dynamically.
    cidr_blocks      = ["106.139.138.188/32"] # Restricted to your IP
  }

  egress {
    # TODO: CRITICAL - Restrict outbound traffic! Allow only necessary destinations (OS updates, DockerHub, GHCR, Ollama models, etc.) on specific ports (e.g., 443, 53).
    from_port        = 0
    to_port          = 0
    protocol         = "-1" # Allow all outbound traffic - TEMPORARY
    cidr_blocks      = ["0.0.0.0/0"]
  }

  tags = {
    Name = "vaultllm-sg-allow-ssh-http"
  }
}

# EC2 Instance
resource "aws_instance" "main" {
  # TODO: Periodically check for and update to the latest appropriate Amazon Linux 2 AMI ID for the region.
  # Consider using a data source for dynamic lookup: https://registry.terraform.io/providers/hashicorp/aws/latest/docs/data-sources/ami
  ami           = "ami-05ec362ff4cffc793" # Amazon Linux 2 AMI (x86_64) in ap-northeast-1
  # TODO: Select an appropriate instance type based on LLM requirements and cost (t3.micro is likely too small). Consider GPU instances (g4dn, g5) if needed.
  instance_type = "t3.micro"             # Start small, may need bigger for LLMs

  subnet_id                   = aws_subnet.public.id
  vpc_security_group_ids      = [aws_security_group.allow_ssh_http.id]
  associate_public_ip_address = true # Needed for internet access via IGW
  # TODO: Add key_name argument to associate an SSH key pair managed by Terraform (aws_key_pair resource).

  # User data script to install Docker and Docker Compose
  user_data = file("${path.module}/scripts/user_data.sh")

  tags = {
    Name = "vaultllm-ec2-instance"
  }
} 