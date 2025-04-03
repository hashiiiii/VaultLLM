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

# --- ECS Service Linked Role ---
# Ensure the ECS Service Linked Role exists
resource "aws_iam_service_linked_role" "ecs" {
  aws_service_name = "ecs.amazonaws.com"
}

# --- IAM Role for ECS Task Execution ---
resource "aws_iam_role" "ecs_task_execution_role" {
  name = "vaultllm-ecs-task-execution-role"

  assume_role_policy = jsonencode({
    Version = "2012-10-17",
    Statement = [
      {
        Action = "sts:AssumeRole",
        Effect = "Allow",
        Principal = {
          Service = "ecs-tasks.amazonaws.com"
        }
      }
    ]
  })

  tags = {
    Name = "vaultllm-ecs-task-execution-role"
  }
}

resource "aws_iam_role_policy_attachment" "ecs_task_execution_role_policy" {
  role       = aws_iam_role.ecs_task_execution_role.name
  policy_arn = "arn:aws:iam::aws:policy/service-role/AmazonECSTaskExecutionRolePolicy"
}

# --- CloudWatch Log Group ---
# Log group for ECS tasks
resource "aws_cloudwatch_log_group" "ecs_task_logs" {
  name = "/ecs/vaultllm-task"

  tags = {
    Name = "vaultllm-ecs-task-log-group"
  }
}

# --- ECS Task Definition ---
resource "aws_ecs_task_definition" "main" {
  family                   = "vaultllm-task"
  network_mode             = "awsvpc" # Required for Fargate
  requires_compatibilities = ["FARGATE"]
  cpu                      = "1024" # 1 vCPU unit
  memory                   = "2048" # 2GB MiB - Adjust as needed for Ollama models
  execution_role_arn       = aws_iam_role.ecs_task_execution_role.arn
  # task_role_arn = aws_iam_role.ecs_task_role.arn # Add if a task role is needed later

  # Define volumes like in docker-compose.yml
  # Using Fargate-managed ephemeral storage initially. Mount EFS later for persistence.
  volume {
    name = "ollama_data"
    # No host path specified for Fargate managed volume
  }
  volume {
    name = "open_webui_data"
    # No host path specified for Fargate managed volume
  }

  # Container Definitions (JSON format)
  container_definitions = jsonencode([
    {
      name      = "ollama"
      image     = "ollama/ollama"
      essential = true
      # Port mapping needed if accessing Ollama API directly, but primarily for WebUI comms
      portMappings = [
        {
          containerPort = 11434
          hostPort      = 11434 # Optional in awsvpc, but good practice
          protocol      = "tcp"
          name          = "ollama-11434-tcp"
          appProtocol   = "http"
        }
      ]
      mountPoints = [
        {
          sourceVolume  = "ollama_data"
          containerPath = "/root/.ollama"
          readOnly      = false
        }
      ]
      logConfiguration = {
        logDriver = "awslogs"
        options = {
          "awslogs-group"         = aws_cloudwatch_log_group.ecs_task_logs.name
          "awslogs-region"        = var.aws_region
          "awslogs-stream-prefix" = "ollama"
        }
      }
      # Health check could be added later
    },
    {
      name      = "open-webui"
      image     = "ghcr.io/open-webui/open-webui:main"
      essential = true
      portMappings = [
        {
          containerPort = 8080
          hostPort      = 8080 # Optional in awsvpc
          protocol      = "tcp"
          name          = "webui-8080-tcp"
          appProtocol   = "http"
        }
      ]
      environment = [
        # Use localhost for communication within the same task in awsvpc mode
        { name = "OLLAMA_BASE_URL", value = "http://localhost:11434" }
      ]
      mountPoints = [
        {
          sourceVolume  = "open_webui_data"
          containerPath = "/app/backend/data"
          readOnly      = false
        }
      ]
      dependsOn = [
        {
          containerName = "ollama"
          condition     = "START" # Wait for ollama to start (or HEALTHY if health check defined)
        }
      ]
      logConfiguration = {
        logDriver = "awslogs"
        options = {
          "awslogs-group"         = aws_cloudwatch_log_group.ecs_task_logs.name
          "awslogs-region"        = var.aws_region
          "awslogs-stream-prefix" = "open-webui"
        }
      }
    }
  ])

  tags = {
    Name = "vaultllm-ecs-task-definition"
  }
}

# --- Security Group for ECS Tasks ---
resource "aws_security_group" "ecs_task_sg" {
  name        = "vaultllm-ecs-task-sg"
  description = "Allow inbound traffic to ECS tasks (e.g., from ALB or specific IPs)"
  vpc_id      = module.network.vpc_id

  ingress {
    description = "Allow Open WebUI (placeholder - will be ALB later)"
    from_port   = 8080
    to_port     = 8080
    protocol    = "tcp"
    # TODO: Restrict this to the ALB security group once created
    cidr_blocks = ["0.0.0.0/0"] # TEMPORARY: Allow from anywhere initially
  }

  # Restrict outbound traffic
  egress {
    description     = "Allow HTTPS to VPC Endpoint SG for SSM (if needed by agent inside task)"
    from_port       = 443
    to_port         = 443
    protocol        = "tcp"
    security_groups = [module.network.vpc_endpoint_sg_id]
  }

  egress {
    description = "Allow DNS (UDP 53) within VPC"
    from_port   = 53
    to_port     = 53
    protocol    = "udp"
    cidr_blocks = [module.network.vpc_cidr_block]
  }

  egress {
    description = "Allow outbound HTTPS for image pulls (DockerHub, GHCR, etc.)"
    from_port   = 443
    to_port     = 443
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  # TODO: Add egress rules for OS updates (if needed), DockerHub, Ollama model downloads etc.
  # Example for ECR/S3 Interface endpoints (often needed by task execution role)
  # egress {
  #   description = "Allow HTTPS to VPC Endpoint SG for ECR/S3"
  #   from_port   = 443
  #   to_port     = 443
  #   protocol    = "tcp"
  #   security_groups = [module.network.vpc_endpoint_sg_id] # Assuming ECR/S3 endpoints use the same SG
  # }

  tags = {
    Name = "vaultllm-ecs-task-sg"
  }
}

# --- ECS Service ---
resource "aws_ecs_service" "main" {
  name            = "vaultllm-service"
  cluster         = aws_ecs_cluster.main.id
  task_definition = aws_ecs_task_definition.main.arn
  desired_count   = 1 # Start with one task
  launch_type     = "FARGATE"

  # Network configuration for Fargate tasks
  network_configuration {
    subnets         = [module.network.public_subnet_id] # Run tasks in the public subnet
    security_groups = [aws_security_group.ecs_task_sg.id]  # Attach the task security group
    assign_public_ip = true # Assign public IP to the task ENI for direct access (or ALB access later)
  }

  # Optional: Load Balancer configuration (will add later)
  # load_balancer {
  #   target_group_arn = aws_lb_target_group.main.arn
  #   container_name   = "open-webui"
  #   container_port   = 8080
  # }

  # Ensure service waits for dependencies like IAM roles if needed, though usually implicit
  # depends_on = [aws_iam_role_policy_attachment.ecs_task_execution_role_policy]

  tags = {
    Name = "vaultllm-ecs-service"
  }
}

# --- Outputs ---
# Output the ECS Task public IP to access WebUI (if assign_public_ip is true)
# Note: This is harder to get directly for Fargate services.
#       Accessing via ALB DNS is the standard way.
#       For now, find the IP in the AWS Console ECS Task details. 