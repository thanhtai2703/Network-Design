# =============================================================================
# App Fargate (4A) - Nginx "Hello VietMove" + ALB
# =============================================================================
# Inline HTML injected via task definition command -> no custom image, no ECR.
# =============================================================================

data "aws_region" "current" {}

# -----------------------------------------------------------------------------
# 1. ECS Cluster
# -----------------------------------------------------------------------------
resource "aws_ecs_cluster" "main" {
  name = "${var.project_name}-cluster"
  
  setting {
    name  = "containerInsights"
    value = "enabled"
  }
  
  tags = { Name = "${var.project_name}-cluster" }
}


# -----------------------------------------------------------------------------
# 2. CloudWatch log group for task logs
# -----------------------------------------------------------------------------
resource "aws_cloudwatch_log_group" "app" {
  name              = "/ecs/${var.project_name}-tms"
  retention_in_days = 7
}


# -----------------------------------------------------------------------------
# 3. IAM execution role (pull image, write logs)
# -----------------------------------------------------------------------------
data "aws_iam_policy_document" "ecs_assume" {
  statement {
    actions = ["sts:AssumeRole"]
    principals {
      type        = "Service"
      identifiers = ["ecs-tasks.amazonaws.com"]
    }
  }
}

resource "aws_iam_role" "task_execution" {
  name               = "${var.project_name}-ecs-task-exec"
  assume_role_policy = data.aws_iam_policy_document.ecs_assume.json
}

resource "aws_iam_role_policy_attachment" "task_execution_managed" {
  role       = aws_iam_role.task_execution.name
  policy_arn = "arn:aws:iam::aws:policy/service-role/AmazonECSTaskExecutionRolePolicy"
}


# -----------------------------------------------------------------------------
# 4. Task definition - nginx with inline HTML via command override
# -----------------------------------------------------------------------------
locals {
  # Generate HTML at task start so we can show the actual container hostname
  # on each refresh (proves ALB is load-balancing across tasks).
  index_html_cmd = <<-EOT
    sh -c "echo '<!doctype html><html><head><title>VietMove TMS</title>
    <style>body{font-family:sans-serif;text-align:center;margin-top:80px}
    h1{color:#0066cc}.tag{color:#888;font-size:14px}</style></head>
    <body><h1>VietMove TMS</h1>
    <p>Region: ${var.region_label}</p>
    <p class=tag>Served by container: <b>'$(hostname)'</b></p>
    </body></html>' > /usr/share/nginx/html/index.html && nginx -g 'daemon off;'"
  EOT
}

resource "aws_ecs_task_definition" "app" {
  family                   = "${var.project_name}-tms"
  network_mode             = "awsvpc"
  requires_compatibilities = ["FARGATE"]
  cpu                      = var.task_cpu
  memory                   = var.task_memory
  execution_role_arn       = aws_iam_role.task_execution.arn

  container_definitions = jsonencode([{
    name      = "nginx"
    image     = "public.ecr.aws/nginx/nginx:latest"
    essential = true
    portMappings = [{
      containerPort = 80
      protocol      = "tcp"
    }]
    entryPoint = ["/bin/sh", "-c"]
    command = [
      "echo \"<!doctype html><html><head><title>VietMove TMS</title><style>body{font-family:sans-serif;text-align:center;margin-top:80px}h1{color:#0066cc}.tag{color:#888;font-size:14px}</style></head><body><h1>VietMove TMS</h1><p>Region: ${var.region_label}</p><p class=tag>Served by container: <b>$(hostname)</b></p></body></html>\" > /usr/share/nginx/html/index.html && nginx -g 'daemon off;'"
    ]
    logConfiguration = {
      logDriver = "awslogs"
      options = {
        "awslogs-group"         = aws_cloudwatch_log_group.app.name
        "awslogs-region"        = data.aws_region.current.region
        "awslogs-stream-prefix" = "nginx"
      }
    }
  }])

  tags = { Name = "${var.project_name}-tms-task" }
}


# -----------------------------------------------------------------------------
# 5. ALB (internet-facing in public subnets)
# -----------------------------------------------------------------------------
resource "aws_lb" "main" {
  name               = "${var.project_name}-alb"
  load_balancer_type = "application"
  subnets            = var.public_subnet_ids
  security_groups    = [var.alb_security_group_id]
  internal           = false

  tags = { Name = "${var.project_name}-alb" }
}

resource "aws_lb_target_group" "app" {
  name        = "${var.project_name}-tg"
  port        = 80
  protocol    = "HTTP"
  vpc_id      = var.vpc_id
  target_type = "ip" # awsvpc mode -> IP targets

  health_check {
    path                = "/"
    healthy_threshold   = 2
    unhealthy_threshold = 3
    interval            = 15
    timeout             = 5
    matcher             = "200"
  }

  tags = { Name = "${var.project_name}-tg" }
}

resource "aws_lb_listener" "http" {
  load_balancer_arn = aws_lb.main.arn
  port              = 80
  protocol          = "HTTP"

  default_action {
    type             = "forward"
    target_group_arn = aws_lb_target_group.app.arn
  }
}


# -----------------------------------------------------------------------------
# 6. ECS Service
# -----------------------------------------------------------------------------
resource "aws_ecs_service" "app" {
  name            = "${var.project_name}-tms-svc"
  cluster         = aws_ecs_cluster.main.id
  task_definition = aws_ecs_task_definition.app.arn
  desired_count   = var.desired_count
  launch_type     = "FARGATE"

  network_configuration {
    subnets          = var.private_subnet_ids
    security_groups  = [var.fargate_security_group_id]
    assign_public_ip = false
  }

  load_balancer {
    target_group_arn = aws_lb_target_group.app.arn
    container_name   = "nginx"
    container_port   = 80
  }

  depends_on = [aws_lb_listener.http]

  tags = { Name = "${var.project_name}-tms-svc" }
}
