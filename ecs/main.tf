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
# module "network" {
#  source = "../network" # Path to the network module
#
#  # Pass variables if the network module needs them
#  # aws_region = var.aws_region
#}

data "terraform_remote_state" "network" {
  backend = "local"

  config = {
    path = "../network/terraform.tfstate"
  }
}

# --- ECS Cluster ---
resource "aws_ecs_cluster" "main" {
  name = "${var.project_name}-${var.ecs_cluster_name}"

  tags = {
    Name = "${var.project_name}-${var.ecs_cluster_name}"
  }
}

# --- ECS Service Linked Role ---
# Ensure the ECS Service Linked Role exists
resource "aws_iam_service_linked_role" "ecs" {
  aws_service_name = "ecs.amazonaws.com"
}

# --- IAM Role for ECS Task Execution ---
resource "aws_iam_role" "ecs_task_execution_role" {
  name = "${var.project_name}-ecs-task-execution-role"

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
    Name = "${var.project_name}-ecs-task-execution-role"
  }
}

resource "aws_iam_role_policy_attachment" "ecs_task_execution_role_policy" {
  role       = aws_iam_role.ecs_task_execution_role.name
  policy_arn = "arn:aws:iam::aws:policy/service-role/AmazonECSTaskExecutionRolePolicy"
}

# --- CloudWatch Log Group ---
# Log group for ECS tasks
resource "aws_cloudwatch_log_group" "ecs_task_logs" {
  name = "${var.project_name}${var.log_group_name}"

  tags = {
    Name = "${var.project_name}-ecs-task-log-group"
  }
}

# --- ECS Task Definition ---
resource "aws_ecs_task_definition" "main" {
  family                   = "${var.project_name}-${var.ecs_task_family}"
  network_mode             = "awsvpc" # Required for Fargate
  requires_compatibilities = ["FARGATE"]
  cpu                      = var.ecs_task_cpu
  memory                   = var.ecs_task_memory
  execution_role_arn       = aws_iam_role.ecs_task_execution_role.arn
  # task_role_arn = aws_iam_role.ecs_task_role.arn # Add if a task role is needed later

  # Define volumes like in docker-compose.yml
  # Using Fargate-managed ephemeral storage initially. Mount EFS later for persistence.
  volume {
    name = var.ollama_volume_name
    # No host path specified for Fargate managed volume
  }
  volume {
    name = var.webui_volume_name
    # No host path specified for Fargate managed volume
  }

  # Container Definitions (JSON format)
  container_definitions = jsonencode([
    {
      name      = var.ollama_container_name
      image     = var.ollama_image
      essential = true
      portMappings = [
        {
          containerPort = var.ollama_container_port
          hostPort      = var.ollama_container_port # Optional in awsvpc, but good practice
          protocol      = "tcp"
          name          = "${var.ollama_container_name}-${var.ollama_container_port}-tcp"
          appProtocol   = "http"
        }
      ]
      mountPoints = [
        {
          sourceVolume  = var.ollama_volume_name
          containerPath = var.ollama_volume_path
          readOnly      = false
        }
      ]
      logConfiguration = {
        logDriver = "awslogs"
        options = {
          "awslogs-group"         = aws_cloudwatch_log_group.ecs_task_logs.name
          "awslogs-region"        = var.aws_region
          "awslogs-stream-prefix" = var.ollama_container_name
        }
      }
      # Health check could be added later
    },
    {
      name      = var.webui_container_name
      image     = var.webui_image
      essential = true
      portMappings = [
        {
          containerPort = var.webui_container_port
          hostPort      = var.webui_container_port # Optional in awsvpc
          protocol      = "tcp"
          name          = "${var.webui_container_name}-${var.webui_container_port}-tcp"
          appProtocol   = "http"
        }
      ]
      environment = [
        # Use localhost for communication within the same task in awsvpc mode
        { name = "OLLAMA_BASE_URL", value = "http://localhost:${var.ollama_container_port}" }
      ]
      mountPoints = [
        {
          sourceVolume  = var.webui_volume_name
          containerPath = var.webui_volume_path
          readOnly      = false
        }
      ]
      dependsOn = [
        {
          containerName = var.ollama_container_name
          condition     = "START" # Wait for ollama to start (or HEALTHY if health check defined)
        }
      ]
      logConfiguration = {
        logDriver = "awslogs"
        options = {
          "awslogs-group"         = aws_cloudwatch_log_group.ecs_task_logs.name
          "awslogs-region"        = var.aws_region
          "awslogs-stream-prefix" = var.webui_container_name
        }
      }
    }
  ])

  tags = {
    Name = "${var.project_name}-${var.ecs_task_family}-definition"
  }
}

# --- Security Group for ECS Tasks ---
resource "aws_security_group" "ecs_task_sg" {
  name        = "${var.project_name}-ecs-task-sg"
  description = "Allow inbound traffic to ECS tasks and controlled outbound traffic"
  vpc_id      = data.terraform_remote_state.network.outputs.vpc_id

  ingress {
    description = "Allow inbound to Open WebUI (Placeholder - restrict to ALB SG later)"
    from_port   = var.webui_container_port
    to_port     = var.webui_container_port
    protocol    = "tcp"
    # TODO: Restrict this to the ALB security group ID once the ALB is created.
    cidr_blocks = ["0.0.0.0/0"] # TEMPORARY: Allows direct access if assign_public_ip=true
  }

  # Allow outbound traffic
  egress {
    description     = "Allow HTTPS to VPC Endpoint SG (SSM, ECR, Logs)"
    from_port       = 443
    to_port         = 443
    protocol        = "tcp"
    security_groups = [data.terraform_remote_state.network.outputs.vpc_endpoint_sg_id]
  }

  egress {
    description = "Allow DNS (UDP 53) within VPC for service discovery and endpoint resolution"
    from_port   = 53
    to_port     = 53
    protocol    = "udp"
    cidr_blocks = [data.terraform_remote_state.network.outputs.vpc_cidr_block]
  }

  egress {
    description = "Allow outbound HTTPS to external services (e.g., DockerHub, GHCR for image pulls)"
    from_port   = 443
    to_port     = 443
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"] # Required for pulling images from external registries.
                                # Consider removing/restricting if all images are in ECR.
  }

  # Note: Removed TODOs and commented-out rules as existing rules cover required access
  # via VPC endpoints and external HTTPS.

  tags = {
    Name = "${var.project_name}-ecs-task-sg"
  }
}

# --- ECS Service ---
resource "aws_ecs_service" "main" {
  name            = "${var.project_name}-${var.ecs_service_name}"
  cluster         = aws_ecs_cluster.main.id
  task_definition = aws_ecs_task_definition.main.arn
  desired_count   = var.desired_count
  launch_type     = "FARGATE"

  # Network configuration for Fargate tasks
  network_configuration {
    subnets         = data.terraform_remote_state.network.outputs.public_subnet_ids # Use the list of public subnet IDs from the network module
    security_groups = [aws_security_group.ecs_task_sg.id]  # Attach the task security group
    assign_public_ip = var.assign_public_ip # Control public IP assignment via variable
  }

  # Optional: Load Balancer configuration (will add later)
  # load_balancer {
  #   target_group_arn = aws_lb_target_group.main.arn
  #   container_name   = "open-webui"
  #   container_port   = 8080
  # }

  # Ensure service waits for dependencies like IAM roles
  depends_on = [
    aws_iam_role_policy_attachment.ecs_task_execution_role_policy,
    # Add ALB listener rule dependency here if using ALB
  ]

  tags = {
    Name = "${var.project_name}-${var.ecs_service_name}"
  }
}

# --- Outputs ---
# Output the ECS Task public IP to access WebUI (if assign_public_ip is true)
# Note: This is harder to get directly for Fargate services.
#       Accessing via ALB DNS is the standard way.
#       For now, find the IP in the AWS Console ECS Task details. 