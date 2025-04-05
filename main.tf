terraform {
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 5.0"
    }
  }
  # backend "local" {} # Assuming local backend for now, configure if needed
}

provider "aws" {
  region = var.aws_region
}

# Module calls will be added later 

module "network" {
  source = "./network"

  aws_region = var.aws_region
  project_name = var.project_name
  # ecs_task_security_group_id = module.ecs.ecs_task_security_group_id # Removed: Not needed anymore

  # Add other variables required by the network module if any
  # e.g., vpc_cidr, public_subnet_cidrs, availability_zones
  # These might need to be defined in the root variables.tf as well
  vpc_cidr             = "10.0.0.0/16" # Example, define in root variables.tf
  public_subnet_cidrs  = ["10.0.1.0/24", "10.0.2.0/24"] # Example, define in root variables.tf
  availability_zones   = ["ap-northeast-1c", "ap-northeast-1a"] # Example, define in root variables.tf
}

module "ecs" {
  source = "./ecs"

  aws_region = var.aws_region
  project_name = var.project_name

  # Pass required values from network module outputs
  vpc_id                = module.network.vpc_id
  vpc_cidr_block        = module.network.vpc_cidr_block
  public_subnet_ids     = module.network.public_subnet_ids
  vpc_endpoint_sg_id    = module.network.vpc_endpoint_sg_id
  load_balancer_arn     = module.network.load_balancer_arn # Pass ALB ARN

  # Add other variables required by the ecs module if any
  # e.g., webui_container_port, ollama_image, etc.
  # These might need to be defined in the root variables.tf as well
  # Example defaults from ecs/variables.tf are assumed if not passed explicitly
  # desired_count = 1 # Example: Start 1 task, define in root variables.tf
}

# --- Security Group Rules to connect ALB and ECS ---

# Allow ALB egress to ECS Task SG on port 8080
resource "aws_security_group_rule" "alb_egress_to_ecs" {
  type                     = "egress"
  from_port                = 8080 # Assuming WebUI port
  to_port                  = 8080 # Assuming WebUI port
  protocol                 = "tcp"
  source_security_group_id = module.ecs.ecs_task_security_group_id # The SG receiving the traffic
  security_group_id        = module.network.alb_security_group_id # The SG initiating the traffic (ALB)
  description              = "Allow ALB outbound to ECS Tasks on WebUI port"
}

# Allow ECS Task SG ingress from ALB on port 8080
resource "aws_security_group_rule" "ecs_ingress_from_alb" {
  type                     = "ingress"
  from_port                = 8080 # Assuming WebUI port
  to_port                  = 8080 # Assuming WebUI port
  protocol                 = "tcp"
  source_security_group_id = module.network.alb_security_group_id # The SG initiating the traffic (ALB)
  security_group_id        = module.ecs.ecs_task_security_group_id # The SG receiving the traffic (ECS Task)
  description              = "Allow ECS inbound from ALB on WebUI port"
} 