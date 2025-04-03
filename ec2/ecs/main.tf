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

# Define module dependency on network
module "network" {
  source = "../network" # Path to the network module

  # Pass variables if the network module needs them
  # aws_region = var.aws_region
}

# --- ECS Cluster ---
resource "aws_ecs_cluster" "main" {
  name = "vaultllm-ecs-cluster"

  tags = {
    Name = "vaultllm-ecs-cluster"
  }
}
