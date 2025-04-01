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

resource "aws_vpc" "main" {
  cidr_block = "10.0.0.0/16"

  tags = {
    Name = "vaultllm-vpc"
  }
}

resource "aws_subnet" "public" {
  vpc_id     = aws_vpc.main.id
  cidr_block = "10.0.1.0/24"

  # Availability Zone は variable から取得する想定 (後で追加)
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
    description      = "SSH from anywhere (temporary - restrict ASAP!)"
    from_port        = 22
    to_port          = 22
    protocol         = "tcp"
    cidr_blocks      = ["0.0.0.0/0"] # WARNING: Restrict this later!
  }

  ingress {
    description      = "Open WebUI from anywhere (temporary - restrict ASAP!)"
    from_port        = 8080
    to_port          = 8080
    protocol         = "tcp"
    cidr_blocks      = ["0.0.0.0/0"] # WARNING: Restrict this later!
  }

  egress {
    from_port        = 0
    to_port          = 0
    protocol         = "-1" # Allow all outbound traffic
    cidr_blocks      = ["0.0.0.0/0"]
  }

  tags = {
    Name = "vaultllm-sg-allow-ssh-http"
  }
}

# EC2 Instance
resource "aws_instance" "main" {
  ami           = "ami-0c55b159cbfafe1f0" # Amazon Linux 2 AMI (x86_64) in ap-northeast-1 - Verify or find latest
  instance_type = "t3.micro"             # Start small, may need bigger for LLMs

  subnet_id                   = aws_subnet.public.id
  vpc_security_group_ids      = [aws_security_group.allow_ssh_http.id]
  associate_public_ip_address = true # Needed for internet access via IGW

  # User data script to install Docker and Docker Compose
  user_data = <<-EOF
              #!/bin/bash
              yum update -y
              amazon-linux-extras install docker -y
              systemctl start docker
              systemctl enable docker
              usermod -a -G docker ec2-user

              # Install Docker Compose v2
              DOCKER_CONFIG=$${DOCKER_CONFIG:-/usr/local/lib/docker}
              mkdir -p $DOCKER_CONFIG/cli-plugins
              curl -SL https://github.com/docker/compose/releases/latest/download/docker-compose-linux-x86_64 -o $DOCKER_CONFIG/cli-plugins/docker-compose
              chmod +x $DOCKER_CONFIG/cli-plugins/docker-compose
              # Make docker compose executable without full path (optional link)
              # ln -s $DOCKER_CONFIG/cli-plugins/docker-compose /usr/local/bin/docker-compose

              # Optional: Reboot to apply group changes or logout/login for ec2-user
              # reboot
              EOF

  tags = {
    Name = "vaultllm-ec2-instance"
  }
} 