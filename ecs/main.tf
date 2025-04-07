resource "aws_ecs_cluster" "main" {
  name = local.ecs_cluster_name

  tags = {
    Name = local.ecs_cluster_name
  }
}

resource "aws_iam_service_linked_role" "ecs" {
  aws_service_name = "ecs.amazonaws.com"
}

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

resource "aws_cloudwatch_log_group" "ecs_task_logs" {
  name = local.log_group_name

  tags = {
    Name = "${var.project_name}-ecs-task-log-group"
  }
}

resource "aws_ecs_task_definition" "main" {
  family                   = local.ecs_task_family
  network_mode             = "awsvpc"
  requires_compatibilities = ["FARGATE"]
  cpu                      = var.ecs_task_cpu
  memory                   = var.ecs_task_memory
  execution_role_arn       = aws_iam_role.ecs_task_execution_role.arn

  volume {
    name = local.ollama_volume_name
  }
  volume {
    name = local.webui_volume_name
  }

  container_definitions = jsonencode([
    {
      name      = local.ollama_container_name
      image     = var.ollama_image
      essential = true
      portMappings = [
        {
          containerPort = var.ollama_container_port
          hostPort      = var.ollama_container_port
          protocol      = "tcp"
          name          = "${local.ollama_container_name}-${var.ollama_container_port}-tcp"
          appProtocol   = "http"
        }
      ]
      mountPoints = [
        {
          sourceVolume  = local.ollama_volume_name
          containerPath = local.ollama_volume_path
          readOnly      = false
        }
      ]
      logConfiguration = {
        logDriver = "awslogs"
        options = {
          "awslogs-group"         = local.log_group_name
          "awslogs-region"        = var.aws_region
          "awslogs-stream-prefix" = local.ollama_container_name
        }
      }
    },
    {
      name      = local.webui_container_name
      image     = var.webui_image
      essential = true
      portMappings = [
        {
          containerPort = var.webui_container_port
          hostPort      = var.webui_container_port
          protocol      = "tcp"
          name          = "${local.webui_container_name}-${var.webui_container_port}-tcp"
          appProtocol   = "http"
        }
      ]
      environment = [
        { name = "OLLAMA_BASE_URL", value = "http://localhost:${var.ollama_container_port}" }
      ]
      mountPoints = [
        {
          sourceVolume  = local.webui_volume_name
          containerPath = local.webui_volume_path
          readOnly      = false
        }
      ]
      dependsOn = [
        {
          containerName = local.ollama_container_name
          condition     = "START"
        }
      ]
      logConfiguration = {
        logDriver = "awslogs"
        options = {
          "awslogs-group"         = local.log_group_name
          "awslogs-region"        = var.aws_region
          "awslogs-stream-prefix" = local.webui_container_name
        }
      }
    }
  ])

  tags = {
    Name = "${local.ecs_task_family}-definition"
  }
}

resource "aws_lb_target_group" "webui" {
  name        = "${local.ecs_service_name}-tg"
  port        = var.webui_container_port
  protocol    = "HTTP"
  target_type = "ip"
  vpc_id      = var.vpc_id

  health_check {
    enabled             = true
    path                = "/"
    port                = "traffic-port"
    protocol            = "HTTP"
    matcher             = "200-399"
    interval            = 30
    timeout             = 5
    healthy_threshold   = 3
    unhealthy_threshold = 3
  }

  tags = {
    Name = "${local.ecs_service_name}-tg"
  }
}

resource "aws_lb_listener" "http" {
  load_balancer_arn = var.alb_arn
  port              = 80
  protocol          = "HTTP"

  default_action {
    type             = "forward"
    target_group_arn = aws_lb_target_group.webui.arn
  }
}

resource "aws_security_group" "ecs_task_sg" {
  name        = "${local.ecs_task_family}-sg"
  description = "Allow inbound traffic to ECS tasks and controlled outbound traffic"
  vpc_id      = var.vpc_id

  egress {
    description     = "Allow HTTPS to VPC Endpoint SG (SSM, ECR, Logs)"
    from_port       = 443
    to_port         = 443
    protocol        = "tcp"
    security_groups = [var.vpc_endpoint_sg_id]
  }

  egress {
    description = "Allow DNS (UDP 53) within VPC for service discovery and endpoint resolution"
    from_port   = 53
    to_port     = 53
    protocol    = "udp"
    cidr_blocks = [var.vpc_cidr_block]
  }

  tags = {
    Name = "${local.ecs_task_family}-sg"
  }
}

resource "aws_ecs_service" "main" {
  name            = local.ecs_service_name
  cluster         = aws_ecs_cluster.main.id
  task_definition = aws_ecs_task_definition.main.arn
  desired_count   = var.desired_count
  launch_type     = "FARGATE"

  network_configuration {
    subnets         = var.public_subnet_ids
    security_groups = [aws_security_group.ecs_task_sg.id]
    assign_public_ip = false
  }

  load_balancer {
    target_group_arn = aws_lb_target_group.webui.arn
    container_name   = local.webui_container_name
    container_port   = var.webui_container_port
  }

  depends_on = [
    aws_iam_role_policy_attachment.ecs_task_execution_role_policy,
    aws_lb_listener.http,
  ]

  tags = {
    Name = local.ecs_service_name
  }
}