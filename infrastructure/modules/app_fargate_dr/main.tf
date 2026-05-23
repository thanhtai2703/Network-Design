# =============================================================================
# App Fargate DR (5C) - Nginx standby in DR region
# =============================================================================
# Same setup as the primary app_fargate module, but all resources live in the
# DR region (provider aws.dr). HTML displays "Region: Ha Noi (DR)" so a viewer
# can tell which region served their request.
# =============================================================================

terraform {
  required_providers {
    aws = {
      source                = "hashicorp/aws"
      configuration_aliases = [aws.dr]
    }
  }
}

data "aws_region" "current" {
  provider = aws.dr
}


# -----------------------------------------------------------------------------
# 1. Security groups (DR region)
# -----------------------------------------------------------------------------
resource "aws_security_group" "alb_dr" {
  provider    = aws.dr
  name        = "${var.project_name}-sg-alb-dr"
  description = "ALB DR public, HTTP from CloudFront/Internet"
  vpc_id      = var.vpc_id
  tags        = { Name = "${var.project_name}-sg-alb-dr" }
}

resource "aws_vpc_security_group_ingress_rule" "alb_dr_http" {
  provider          = aws.dr
  security_group_id = aws_security_group.alb_dr.id
  cidr_ipv4         = "0.0.0.0/0"
  from_port         = 80
  to_port           = 80
  ip_protocol       = "tcp"
  description       = "HTTP from Internet/CloudFront"
}

resource "aws_vpc_security_group_egress_rule" "alb_dr_to_fargate" {
  provider                     = aws.dr
  security_group_id            = aws_security_group.alb_dr.id
  referenced_security_group_id = aws_security_group.fargate_dr.id
  from_port                    = 80
  to_port                      = 80
  ip_protocol                  = "tcp"
  description                  = "ALB DR to Fargate DR task"
}

resource "aws_security_group" "fargate_dr" {
  provider    = aws.dr
  name        = "${var.project_name}-sg-fargate-dr"
  description = "Fargate DR task, accept from ALB DR only"
  vpc_id      = var.vpc_id
  tags        = { Name = "${var.project_name}-sg-fargate-dr" }
}

resource "aws_vpc_security_group_ingress_rule" "fargate_dr_from_alb" {
  provider                     = aws.dr
  security_group_id            = aws_security_group.fargate_dr.id
  referenced_security_group_id = aws_security_group.alb_dr.id
  from_port                    = 80
  to_port                      = 80
  ip_protocol                  = "tcp"
  description                  = "From ALB DR"
}

resource "aws_vpc_security_group_egress_rule" "fargate_dr_https" {
  provider          = aws.dr
  security_group_id = aws_security_group.fargate_dr.id
  cidr_ipv4         = "0.0.0.0/0"
  from_port         = 443
  to_port           = 443
  ip_protocol       = "tcp"
  description       = "Pull image, AWS API"
}


# -----------------------------------------------------------------------------
# 2. ECS Cluster + log group + IAM
# -----------------------------------------------------------------------------
resource "aws_ecs_cluster" "main" {
  provider = aws.dr
  name     = "${var.project_name}-cluster-dr"
  tags     = { Name = "${var.project_name}-cluster-dr" }
}

resource "aws_cloudwatch_log_group" "app" {
  provider          = aws.dr
  name              = "/ecs/${var.project_name}-tms-dr"
  retention_in_days = 7
}

data "aws_iam_policy_document" "ecs_assume" {
  provider = aws.dr
  statement {
    actions = ["sts:AssumeRole"]
    principals {
      type        = "Service"
      identifiers = ["ecs-tasks.amazonaws.com"]
    }
  }
}

resource "aws_iam_role" "task_execution" {
  provider           = aws.dr
  name               = "${var.project_name}-ecs-task-exec-dr"
  assume_role_policy = data.aws_iam_policy_document.ecs_assume.json
}

resource "aws_iam_role_policy_attachment" "task_execution_managed" {
  provider   = aws.dr
  role       = aws_iam_role.task_execution.name
  policy_arn = "arn:aws:iam::aws:policy/service-role/AmazonECSTaskExecutionRolePolicy"
}


# -----------------------------------------------------------------------------
# 3. Task definition
# -----------------------------------------------------------------------------
resource "aws_ecs_task_definition" "app" {
  provider                 = aws.dr
  family                   = "${var.project_name}-tms-dr"
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
      "echo \"<!doctype html><html><head><title>VietMove TMS - DR</title><style>body{font-family:sans-serif;text-align:center;margin-top:80px}h1{color:#cc6600}.tag{color:#888;font-size:14px}.dr{color:#cc0000;font-weight:bold}</style></head><body><h1>VietMove TMS</h1><p>Region: <span class=dr>${var.region_label}</span></p><p class=tag>Served by container: <b>$(hostname)</b></p></body></html>\" > /usr/share/nginx/html/index.html && nginx -g 'daemon off;'"
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

  tags = { Name = "${var.project_name}-tms-dr-task" }
}


# -----------------------------------------------------------------------------
# 4. ALB DR (internet-facing in public subnets)
# -----------------------------------------------------------------------------
resource "aws_lb" "main" {
  provider           = aws.dr
  name               = "${var.project_name}-alb-dr"
  load_balancer_type = "application"
  subnets            = var.public_subnet_ids
  security_groups    = [aws_security_group.alb_dr.id]
  internal           = false

  tags = { Name = "${var.project_name}-alb-dr" }
}

resource "aws_lb_target_group" "app" {
  provider    = aws.dr
  name        = "${var.project_name}-tg-dr"
  port        = 80
  protocol    = "HTTP"
  vpc_id      = var.vpc_id
  target_type = "ip"

  health_check {
    path                = "/"
    healthy_threshold   = 2
    unhealthy_threshold = 3
    interval            = 15
    timeout             = 5
    matcher             = "200"
  }

  tags = { Name = "${var.project_name}-tg-dr" }
}

resource "aws_lb_listener" "http" {
  provider          = aws.dr
  load_balancer_arn = aws_lb.main.arn
  port              = 80
  protocol          = "HTTP"

  default_action {
    type             = "forward"
    target_group_arn = aws_lb_target_group.app.arn
  }
}


# -----------------------------------------------------------------------------
# 5. ECS Service
# -----------------------------------------------------------------------------
resource "aws_ecs_service" "app" {
  provider        = aws.dr
  name            = "${var.project_name}-tms-svc-dr"
  cluster         = aws_ecs_cluster.main.id
  task_definition = aws_ecs_task_definition.app.arn
  desired_count   = var.desired_count
  launch_type     = "FARGATE"

  network_configuration {
    subnets          = var.private_subnet_ids
    security_groups  = [aws_security_group.fargate_dr.id]
    assign_public_ip = false
  }

  load_balancer {
    target_group_arn = aws_lb_target_group.app.arn
    container_name   = "nginx"
    container_port   = 80
  }

  depends_on = [aws_lb_listener.http]

  tags = { Name = "${var.project_name}-tms-svc-dr" }
}
