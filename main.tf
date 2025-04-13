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
  source             = "./network"
  aws_region         = var.aws_region
  project_name       = var.project_name
  vpc_cidr           = var.vpc_cidr
  availability_zones = var.availability_zones
  public_subnet_cidrs = local.public_subnet_cidrs
  acm_certificate_arn = aws_acm_certificate_validation.main.certificate_arn
  ecs_target_group_arn = module.ecs.target_group_arn
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
  name = var.parent_domain_name

  tags = {
    Name        = "${var.parent_domain_name}-hosted-zone"
    Environment = var.environment
    Project     = var.project_name
  }
}

resource "aws_acm_certificate" "main" {
  domain_name       = var.domain_name
  validation_method = "DNS"

  lifecycle {
    create_before_destroy = true # Allows replacing certificate without downtime if needed later
  }

  tags = {
    Name        = "${var.domain_name}-certificate"
    Environment = var.environment
    Project     = var.project_name
  }
}

resource "aws_route53_record" "acm_validation" {
  zone_id         = aws_route53_zone.main.zone_id
  name            = tolist(aws_acm_certificate.main.domain_validation_options)[0].resource_record_name
  type            = tolist(aws_acm_certificate.main.domain_validation_options)[0].resource_record_type
  records         = [tolist(aws_acm_certificate.main.domain_validation_options)[0].resource_record_value]
  ttl             = 300
  allow_overwrite = true
}

resource "aws_acm_certificate_validation" "main" {
  certificate_arn         = aws_acm_certificate.main.arn
  validation_record_fqdns = [aws_route53_record.acm_validation.fqdn]
}

resource "aws_route53_record" "app_alias" {
  zone_id = aws_route53_zone.main.zone_id
  name    = var.domain_name
  type    = "A"

  alias {
    name                   = module.network.alb_dns_name
    zone_id                = module.network.alb_zone_id
    evaluate_target_health = true
  }
}

module "ecs" {
  source                    = "./ecs"
  aws_region                = var.aws_region
  project_name              = var.project_name
  environment               = var.environment
  vpc_id                    = module.network.vpc_id
  public_subnet_ids         = module.network.public_subnet_ids
  alb_arn                   = module.network.alb_arn
  alb_security_group_id     = module.network.alb_sg_id
  vpc_endpoint_sg_id        = module.network.vpc_endpoint_sg_id
  vpc_cidr_block            = var.vpc_cidr
  webui_container_port      = var.webui_container_port
  ecs_task_cpu              = var.ecs_task_cpu
  ecs_task_memory           = var.ecs_task_memory
  ollama_image              = aws_ecr_repository.ollama.repository_url
  webui_image               = aws_ecr_repository.webui.repository_url
  ollama_container_port     = var.ollama_container_port
  desired_count             = var.run_service ? var.ecs_desired_count : 0
  assign_public_ip          = false
  efs_file_system_id        = module.network.efs_file_system_id
  webui_data_container_path = var.webui_data_container_path
  health_check_path         = var.health_check_path
  health_check_matcher      = var.health_check_matcher
  availability_zones        = module.network.public_subnet_azs
  acm_certificate_arn       = aws_acm_certificate_validation.main.certificate_arn
  efs_security_group_id     = module.network.efs_security_group_id
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

resource "aws_security_group_rule" "ecs_to_efs_nfs" {
  type                     = "egress"
  from_port                = var.nfs_port
  to_port                  = var.nfs_port
  protocol                 = "tcp"
  source_security_group_id = module.ecs.ecs_task_security_group_id
  security_group_id        = module.network.efs_security_group_id
  description              = "Allow ECS tasks outbound to EFS on NFS port"
}

resource "aws_security_group_rule" "efs_from_ecs_nfs" {
  type                     = "ingress"
  from_port                = var.nfs_port
  to_port                  = var.nfs_port
  protocol                 = "tcp"
  source_security_group_id = module.ecs.ecs_task_security_group_id
  security_group_id        = module.network.efs_security_group_id
  description              = "Allow EFS inbound from ECS tasks on NFS port"
}
