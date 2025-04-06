terraform {
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 5.0"
    }
  }

  backend "s3" {
    bucket         = "vaultllm-tfstate-619416722781-ap-northeast-1"
    key            = "vaultllm/root/terraform.tfstate"
    region         = "ap-northeast-1"
    dynamodb_table = "vaultllm-tfstate-lock"
    encrypt        = true
  }
}

provider "aws" {
  region = var.aws_region
  allowed_account_ids = [var.target_account_id]

  default_tags {
    tags = {
      Project     = var.project_name
      Environment = var.environment
      ManagedBy   = "Terraform"
    }
  }
}

module "network" {
  source = "./network"

  aws_region           = var.aws_region
  project_name         = var.project_name
  vpc_cidr             = var.vpc_cidr
  public_subnet_cidrs  = local.public_subnet_cidrs
  availability_zones   = var.availability_zones
}

module "ecs" {
  source = "./ecs"

  aws_region           = var.aws_region
  project_name         = var.project_name
  vpc_id               = module.network.vpc_id
  vpc_cidr_block       = module.network.vpc_cidr_block
  public_subnet_ids    = module.network.public_subnet_ids
  vpc_endpoint_sg_id   = module.network.vpc_endpoint_sg_id
  alb_arn    = module.network.alb_arn
  webui_container_port = var.webui_container_port
}

resource "aws_security_group_rule" "alb_egress_to_ecs" {
  type                     = "egress"
  from_port                = var.webui_container_port
  to_port                  = var.webui_container_port
  protocol                 = "tcp"
  source_security_group_id = module.ecs.ecs_task_security_group_id
  security_group_id        = module.network.alb_sg_id
  description              = "Allow ALB outbound to ECS Tasks on WebUI port"
}

resource "aws_security_group_rule" "ecs_ingress_from_alb" {
  type                     = "ingress"
  from_port                = var.webui_container_port
  to_port                  = var.webui_container_port
  protocol                 = "tcp"
  source_security_group_id = module.network.alb_sg_id
  security_group_id        = module.ecs.ecs_task_security_group_id
  description              = "Allow ECS inbound from ALB on WebUI port"
} 