variable "access_key" {}

variable "secret_key" {}

variable "region" {}

variable "project" {} 

variable "environment" {}

variable "image_ecr_repo" {}

variable "api_cert_arn"  {}

variable "vpc_id" {}

variable "vpc_sg_id" {}

locals {
  cloudwatch_group = "api-task-group-${var.environment}"
}

data "aws_vpc" "db_vpc" {
    id = var.vpc_id
}

data "aws_subnet_ids" "public_subnets" {
  vpc_id = var.vpc_id

  tags = {
    Name = "*public*"
  }
}

resource "aws_ecs_cluster" "api_cluster" {
  name = "api-cluster-${var.environment}"
}

resource "aws_cloudwatch_log_group" "api-log-group" {
  name = local.cloudwatch_group

  tags = {
    Environment = var.environment
    Application = "api"
  }
}

resource "aws_ecs_task_definition" "api_task" {
  family                   = "api-task-${var.environment}"# Naming our first task
  container_definitions    = <<DEFINITION
  [
    {
      "name": "api-task-${var.environment}",
      "image": "${var.image_ecr_repo}",
      "essential": true,
      "portMappings": [
        {
          "containerPort": 7000,
          "hostPort": 7000
        }
      ],
      "memory": 512,
      "cpu": 256,
      "logConfiguration": {
          "logDriver": "awslogs",
          "options": {
          "awslogs-group": "${local.cloudwatch_group}",
          "awslogs-region": "eu-west-1",
          "awslogs-stream-prefix": "ecs"
          }
      }
    }
  ]
  DEFINITION
  requires_compatibilities = ["FARGATE"] # Stating that we are using ECS Fargate
  network_mode             = "awsvpc"    # Using awsvpc as our network mode as this is required for Fargate
  memory                   = 512         # Specifying the memory our container requires
  cpu                      = 256         # Specifying the CPU our container requires
  execution_role_arn       = aws_iam_role.ecsTaskExecutionRole.arn
}

resource "aws_iam_role" "ecsTaskExecutionRole" {
  name               = "ecsTaskExecutionRole"
  assume_role_policy = data.aws_iam_policy_document.assume_role_policy.json
}

data "aws_iam_policy_document" "assume_role_policy" {
  statement {
    actions = ["sts:AssumeRole"]

    principals {
      type        = "Service"
      identifiers = ["ecs-tasks.amazonaws.com"]
    }
  }
}

resource "aws_iam_role_policy_attachment" "ecsTaskExecutionRole_policy" {
  role       = aws_iam_role.ecsTaskExecutionRole.name
  policy_arn = "arn:aws:iam::aws:policy/service-role/AmazonECSTaskExecutionRolePolicy"
}

resource "aws_ecs_service" "api-service" {
  name            = "api-service-${var.environment}"                             
  cluster         = aws_ecs_cluster.api_cluster.id             
  task_definition = aws_ecs_task_definition.api_task.arn 
  launch_type     = "FARGATE"
  desired_count   = 1

  load_balancer {
    target_group_arn = aws_lb_target_group.target_group.arn
    container_name   = aws_ecs_task_definition.api_task.family
    container_port   = 7000 
  }

  network_configuration {
    subnets          = data.aws_subnet_ids.public_subnets.ids
    assign_public_ip = true # Providing our containers with public IPs
    security_groups  = [aws_security_group.service_security_group.id, var.vpc_sg_id]
  }
}

resource "aws_security_group" "service_security_group" {
  vpc_id      = var.vpc_id
  ingress {
    from_port = 0
    to_port   = 0
    protocol  = "-1"
    # Only allowing traffic in from the load balancer security group
    security_groups = [aws_security_group.load_balancer_security_group.id]
  }

  egress {
    from_port   = 0 # Allowing any incoming port
    to_port     = 0 # Allowing any outgoing port
    protocol    = "-1" # Allowing any outgoing protocol 
    cidr_blocks = ["0.0.0.0/0"] # Allowing traffic out to all IP addresses
  }
}

resource "aws_alb" "application_load_balancer" {
  name                = "api-lb-tf-${var.environment}" # Naming our load balancer
  load_balancer_type  = "application"
  subnets             = data.aws_subnet_ids.public_subnets.ids
  # Referencing the security group
  security_groups     = [aws_security_group.load_balancer_security_group.id]
}

# Creating a security group for the load balancer:
resource "aws_security_group" "load_balancer_security_group" {
  vpc_id      = var.vpc_id
  ingress {
    from_port   = 80 # Allowing traffic in from port 80
    to_port     = 80
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"] # Allowing traffic in from all sources
  }

  ingress {
    from_port   = 443 # Allowing traffic in from port 80
    to_port     = 443
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"] # Allowing traffic in from all sources
  }

  egress {
    from_port   = 0 # Allowing any incoming port
    to_port     = 0 # Allowing any outgoing port
    protocol    = "-1" # Allowing any outgoing protocol 
    cidr_blocks = ["0.0.0.0/0"] # Allowing traffic out to all IP addresses
  }
}

resource "aws_lb_target_group" "target_group" {
  name        = "api-target-group-${var.environment}"
  port        = 80
  protocol    = "HTTP"
  target_type = "ip"
  vpc_id      = var.vpc_id
  health_check {
    matcher = "200,301,302"
    path = "/actuator/health"
  }
}

resource "aws_lb_listener" "listener_http" {
  load_balancer_arn = aws_alb.application_load_balancer.arn # Referencing our load balancer
  port              = "80"
  protocol          = "HTTP"
  default_action {
    type             = "redirect"
    redirect {
      port        = "443"
      protocol    = "HTTPS"
      status_code = "HTTP_301"
    }
  }
}

resource "aws_lb_listener" "listener_https" {
  load_balancer_arn = aws_alb.application_load_balancer.arn # Referencing our load balancer
  port              = "443"
  protocol          = "HTTPS"
  certificate_arn   = var.api_cert_arn
  default_action {
    type             = "forward"
    target_group_arn = aws_lb_target_group.target_group.arn # Referencing our tagrte group
  }
}