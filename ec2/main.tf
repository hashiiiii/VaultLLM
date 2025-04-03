terraform {
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 5.0"
    }
  }
}

provider "aws" {
  # Assuming the region is implicitly provided by the environment or higher-level configuration
  # If not, you might need to pass it from the root module or define it here
  # region = var.aws_region 
}

# Define module dependency on network
module "network" {
  source = "../network" # Path to the network module

  # Pass any necessary variables to the network module if needed
  # e.g., aws_region = var.aws_region
}

# IAM Role for EC2 instance to allow SSM connection
resource "aws_iam_role" "instance_role" {
  name = "vaultllm-ec2-ssm-role"

  assume_role_policy = jsonencode({
    Version = "2012-10-17",
    Statement = [
      {
        Action    = "sts:AssumeRole",
        Effect    = "Allow",
        Principal = {
          Service = "ec2.amazonaws.com"
        }
      }
    ]
  })

  tags = {
    Name = "vaultllm-ec2-ssm-role"
  }
}

resource "aws_iam_role_policy_attachment" "ssm_policy_attachment" {
  role       = aws_iam_role.instance_role.name
  policy_arn = "arn:aws:iam::aws:policy/AmazonSSMManagedInstanceCore"
}

resource "aws_iam_instance_profile" "instance_profile" {
  name = "vaultllm-ec2-ssm-instance-profile"
  role = aws_iam_role.instance_role.name

  tags = {
    Name = "vaultllm-ec2-ssm-instance-profile"
  }
}

# Security Group for the EC2 instance
resource "aws_security_group" "allow_webui" {
  name        = "vaultllm-allow-webui"
  description = "Allow Open WebUI inbound traffic and restrict outbound"
  vpc_id      = module.network.vpc_id # Reference network module output

  ingress {
    description      = "Open WebUI from specific IP"
    from_port        = 8080
    to_port          = 8080
    protocol         = "tcp"
    # TODO: Update this IP if your IP changes, or manage allowed IPs more dynamically.
    cidr_blocks      = [var.allowed_ip_cidr] # Use variable for allowed IP
  }

  # --- Temporarily allow ALL outbound for debugging SSM Agent --- 
  egress {
    description = "TEMP: Allow all outbound for SSM debugging"
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }
  # --- End Temporary Rule --- 

  # Add other necessary egress rules here later (e.g., OS updates, DockerHub)

  tags = {
    Name = "vaultllm-sg-allow-webui"
  }
}

# EC2 Instance
resource "aws_instance" "main" {
  # TODO: Periodically check for and update to the latest appropriate Amazon Linux 2 AMI ID for the region.
  # Consider using a data source for dynamic lookup: https://registry.terraform.io/providers/hashicorp/aws/latest/docs/data-sources/ami
  ami           = var.ec2_ami_id # Use variable
  # TODO: Select an appropriate instance type based on LLM requirements and cost (t3.micro is likely too small). Consider GPU instances (g4dn, g5) if needed.
  instance_type = var.ec2_instance_type # Use variable

  subnet_id                   = module.network.public_subnet_id # Reference network module output
  vpc_security_group_ids      = [aws_security_group.allow_webui.id]
  associate_public_ip_address = true # Needed for internet access via IGW
  iam_instance_profile        = aws_iam_instance_profile.instance_profile.name

  # User data script to install Docker and Docker Compose
  user_data = file("${path.module}/scripts/user_data.sh")

  tags = {
    Name = "vaultllm-ec2-instance"
  }
} 