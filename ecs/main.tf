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

# --- Application Load Balancer (ALB) ---

resource "aws_lb" "main" {
  name               = "${var.project_name}-alb"
  internal           = false # Internet-facing
  load_balancer_type = "application"
  security_groups    = [data.terraform_remote_state.network.outputs.alb_security_group_id]
  subnets            = data.terraform_remote_state.network.outputs.public_subnet_ids # Place ALB in public subnets

  # Enable access logs (optional but recommended)
  # access_logs {
  #   bucket  = aws_s3_bucket.lb_logs.bucket
  #   prefix  = "${var.project_name}-lb-logs"
  #   enabled = true
  # }

  tags = {
    Name = "${var.project_name}-alb"
  }
}

# --- Target Group ---

resource "aws_lb_target_group" "webui" {
  name        = "${var.project_name}-webui-tg"
  port        = var.webui_container_port # Target port on the container
  protocol    = "HTTP"                  # Protocol between ALB and container
  target_type = "ip"                    # Required for Fargate
  vpc_id      = data.terraform_remote_state.network.outputs.vpc_id

  health_check {
    enabled             = true
    path                = "/" # Adjust to a specific health check endpoint if available (e.g., /health)
    port                = "traffic-port" # Use the target group port
    protocol            = "HTTP"
    matcher             = "200-399" # Expect a successful HTTP response
    interval            = 30
    timeout             = 5
    healthy_threshold   = 3
    unhealthy_threshold = 3
  }

  tags = {
    Name = "${var.project_name}-webui-tg"
  }
}

# --- Listener for HTTP ---
# Redirects HTTP traffic to HTTPS once HTTPS listener is set up.
# For now, forwards HTTP directly to the target group.
resource "aws_lb_listener" "http" {
  load_balancer_arn = aws_lb.main.arn
  port              = 80
  protocol          = "HTTP"

  default_action {
    type             = "forward"
    target_group_arn = aws_lb_target_group.webui.arn
  }
}

# --- Listener for HTTPS (Requires Certificate) ---
# TODO: Add HTTPS listener after obtaining an ACM certificate
# resource "aws_lb_listener" "https" {
#   load_balancer_arn = aws_lb.main.arn
#   port              = 443
#   protocol          = "HTTPS"
#   ssl_policy        = "ELBSecurityPolicy-2016-08" # Choose an appropriate policy
#   certificate_arn   = var.acm_certificate_arn # Pass certificate ARN as variable
#
#   default_action {
#     type             = "forward"
#     target_group_arn = aws_lb_target_group.webui.arn
#   }
# }

# --- Security Group for ECS Tasks ---
resource "aws_security_group" "ecs_task_sg" {
  name        = "${var.project_name}-ecs-task-sg"
  description = "Allow inbound traffic to ECS tasks and controlled outbound traffic"
  vpc_id      = data.terraform_remote_state.network.outputs.vpc_id

  ingress {
    description = "Allow inbound from ALB to Open WebUI"
    from_port   = var.webui_container_port
    to_port     = var.webui_container_port
    protocol    = "tcp"
    # TODO: Restrict this to the ALB security group ID once the ALB is created.
    # cidr_blocks = ["0.0.0.0/0"] # TEMPORARY: Allows direct access if assign_public_ip=true
    security_groups = [data.terraform_remote_state.network.outputs.alb_security_group_id]
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
    subnets         = data.terraform_remote_state.network.outputs.public_subnet_ids
    security_groups = [aws_security_group.ecs_task_sg.id]
    assign_public_ip = false # ALB provides the public access point
  }

  # Load Balancer configuration
  load_balancer {
    target_group_arn = aws_lb_target_group.webui.arn
    container_name   = var.webui_container_name
    container_port   = var.webui_container_port
  }

  # Ensure service waits for dependencies like IAM roles and the ALB listener
  depends_on = [
    aws_iam_role_policy_attachment.ecs_task_execution_role_policy,
    aws_lb_listener.http, # Wait for the HTTP listener to be ready
    # aws_lb_listener.https, # Add this if using HTTPS listener
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