# TODO: HTTPS Configuration Required
# This configuration currently only supports HTTP.
# To enable HTTPS, the following steps are needed after domain transfer is complete:
# 1. Define variables for domain_name and route53_zone_id in variables.tf.
# 2. Add resources for ACM certificate creation and validation using Route 53 DNS.
# 3. Add a Route 53 Alias record pointing the domain name to the ALB.
# 4. Pass the validated certificate ARN to the ECS module.
# 5. Update the ECS module to remove the HTTP listener and add an HTTPS listener using the certificate.

terraform {
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 5.0"
    }
  }

  backend "s3" {
    # Values will be provided via backend.conf during init
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
  availability_zones   = var.availability_zones
  public_subnet_cidrs  = local.public_subnet_cidrs
}

resource "aws_ecr_repository" "ollama" {
  name                 = "${var.project_name}/ollama"
  image_tag_mutability = "IMMUTABLE"

  image_scanning_configuration {
    scan_on_push = true
  }

  tags = {
    Name        = "${var.project_name}-ollama-ecr"
    Environment = var.environment
    Project     = var.project_name
  }
}

resource "aws_ecr_repository" "webui" {
  name                 = "${var.project_name}/open-webui"
  image_tag_mutability = "IMMUTABLE"

  image_scanning_configuration {
    scan_on_push = true
  }

  tags = {
    Name        = "${var.project_name}-webui-ecr"
    Environment = var.environment
    Project     = var.project_name
  }
}

resource "aws_route53_zone" "main" {
  name = var.domain_name

  tags = {
    Name        = "${var.domain_name}-hosted-zone"
    Environment = var.environment
    Project     = var.project_name
  }
}

module "ecs" {
  source = "./ecs"

  aws_region              = var.aws_region
  project_name            = var.project_name
  environment             = var.environment
  vpc_id                  = module.network.vpc_id
  public_subnet_ids       = module.network.public_subnet_ids
  alb_arn                 = module.network.alb_arn
  alb_security_group_id   = module.network.alb_sg_id
  vpc_endpoint_sg_id      = module.network.vpc_endpoint_sg_id
  vpc_cidr_block          = var.vpc_cidr
  webui_container_port    = var.webui_container_port
  ecs_task_cpu            = var.ecs_task_cpu
  ecs_task_memory         = var.ecs_task_memory
  ollama_image            = aws_ecr_repository.ollama.repository_url
  webui_image             = aws_ecr_repository.webui.repository_url
  ollama_container_port   = var.ollama_container_port
  desired_count           = var.ecs_desired_count
  assign_public_ip        = false
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