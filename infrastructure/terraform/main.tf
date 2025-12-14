# infrastructure/terraform/main.tf

terraform {
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 4.16"
    }
  }
  required_version = ">= 1.2.0"

  # BLOQUE BACKEND VACÍO (CRUCIAL)
  # GitHub Actions llenará esto automáticamente con tu bucket S3.
  backend "s3" {}
}

provider "aws" {
  region = "us-east-1" # Región correcta (N. Virginia)
}

# ------------------------------------------------------------------------------
# 1. RED (Networking)
# ------------------------------------------------------------------------------
resource "aws_default_vpc" "default" {}

data "aws_subnets" "default" {
  filter {
    name   = "vpc-id"
    values = [aws_default_vpc.default.id]
  }
}

# ------------------------------------------------------------------------------
# 2. ECR (Repositorio de Imágenes Docker)
# ------------------------------------------------------------------------------
resource "aws_ecr_repository" "repo" {
  name         = "dermatech/${var.env}-auth-service"
  force_delete = true
}

# ------------------------------------------------------------------------------
# 3. SEGURIDAD & ROLES (IAM)
# ------------------------------------------------------------------------------
# Creamos el rol explícitamente para evitar errores de "Entity Not Found"
resource "aws_iam_role" "ecs_execution_role" {
  name = "dermatech-${var.env}-ecs-exec-role"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Action = "sts:AssumeRole"
      Effect = "Allow"
      Principal = { Service = "ecs-tasks.amazonaws.com" }
    }]
  })
}

resource "aws_iam_role_policy_attachment" "ecs_execution_role_policy" {
  role       = aws_iam_role.ecs_execution_role.name
  policy_arn = "arn:aws:iam::aws:policy/service-role/AmazonECSTaskExecutionRolePolicy"
}

# ------------------------------------------------------------------------------
# 4. LOAD BALANCER (ALB) - High Availability
# ------------------------------------------------------------------------------
resource "aws_security_group" "lb_sg" {
  name        = "${var.env}-auth-lb-sg"
  description = "Allow HTTP traffic"
  vpc_id      = aws_default_vpc.default.id

  ingress {
    from_port   = 80
    to_port     = 80
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }
  
  # Comunicación interna Balanceador -> Contenedor
  ingress {
    from_port   = 3000
    to_port     = 3000
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }
}

resource "aws_lb" "app_lb" {
  name               = "${var.env}-auth-alb"
  internal           = false
  load_balancer_type = "application"
  security_groups    = [aws_security_group.lb_sg.id]
  subnets            = data.aws_subnets.default.ids
}

resource "aws_lb_target_group" "app_tg" {
  name        = "${var.env}-auth-tg"
  port        = 3000
  protocol    = "HTTP"
  target_type = "ip"
  vpc_id      = aws_default_vpc.default.id
  health_check {
    path = "/api/health" # Debe coincidir con tu HealthController
  }
}

resource "aws_lb_listener" "front_end" {
  load_balancer_arn = aws_lb.app_lb.arn
  port              = "80"
  protocol          = "HTTP"
  default_action {
    type             = "forward"
    target_group_arn = aws_lb_target_group.app_tg.arn
  }
}

# ------------------------------------------------------------------------------
# 5. LOGS (CloudWatch)
# ------------------------------------------------------------------------------
resource "aws_cloudwatch_log_group" "ecs_logs" {
  name              = "/ecs/dermatech-${var.env}-auth"
  retention_in_days = 1
}

# ------------------------------------------------------------------------------
# 6. ECS (Cluster y Servicio)
# ------------------------------------------------------------------------------
resource "aws_ecs_cluster" "main" {
  name = "dermatech-${var.env}-cluster"
}

resource "aws_ecs_task_definition" "app_task" {
  family                   = "${var.env}-auth-task"
  network_mode             = "awsvpc"
  requires_compatibilities = ["FARGATE"]
  cpu                      = 256
  memory                   = 512
  execution_role_arn       = aws_iam_role.ecs_execution_role.arn

  container_definitions = jsonencode([{
    name      = "auth-service"
    image     = "${aws_ecr_repository.repo.repository_url}:latest"
    essential = true
    portMappings = [{ containerPort = 3000 }]
    logConfiguration = {
      logDriver = "awslogs"
      options = {
        # Usamos el grupo creado arriba para evitar errores de permisos
        "awslogs-group"         = aws_cloudwatch_log_group.ecs_logs.name
        "awslogs-region"        = "us-east-1" # CORREGIDO: Ahora coincide con el provider
        "awslogs-stream-prefix" = "ecs"
      }
    }
  }])
}

resource "aws_ecs_service" "main" {
  name            = "${var.env}-auth-svc"
  cluster         = aws_ecs_cluster.main.id
  task_definition = aws_ecs_task_definition.app_task.arn
  launch_type     = "FARGATE"
  desired_count   = 2 # High Availability (2 réplicas)
  force_new_deployment = true

  network_configuration {
    subnets          = data.aws_subnets.default.ids
    security_groups  = [aws_security_group.lb_sg.id]
    assign_public_ip = true
  }

  load_balancer {
    target_group_arn = aws_lb_target_group.app_tg.arn
    container_name   = "auth-service"
    container_port   = 3000
  }
  
  depends_on = [aws_lb_listener.front_end]
}

# ------------------------------------------------------------------------------
# 7. JUMP BOX (BASTION HOST) - Requisito de Seguridad
# ------------------------------------------------------------------------------
resource "aws_security_group" "bastion_sg" {
  name        = "${var.env}-bastion-sg"
  description = "SSH access for Admin"
  vpc_id      = aws_default_vpc.default.id

  ingress {
    from_port   = 22
    to_port     = 22
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"] # Idealmente restringir a tu IP
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }
}

resource "aws_instance" "bastion" {
  # AMI de Amazon Linux 2023 en us-east-1 (Verificado)
  ami           = "ami-051f7e7f6c2f40dc1" 
  instance_type = "t2.micro"
  subnet_id     = tolist(data.aws_subnets.default.ids)[0]
  
  vpc_security_group_ids = [aws_security_group.bastion_sg.id]
  
  # 'vockey' es la clave por defecto en AWS Academy Learner Labs.
  # Si no existe, debes crear una "Key Pair" en la consola EC2 llamada "vockey"
  key_name = "vockey" 

  tags = {
    Name = "${var.env}-jump-box-bastion"
  }
}

# ------------------------------------------------------------------------------
# OUTPUTS
# ------------------------------------------------------------------------------
output "load_balancer_dns" {
  description = "Entregar este DNS al docente para Cloudflare"
  value       = aws_lb.app_lb.dns_name
}

output "bastion_public_ip" {
  description = "Entregar esta IP al docente como 'Jump Box IP'"
  value       = aws_instance.bastion.public_ip
}

output "ecr_repository_url" {
  value = aws_ecr_repository.repo.repository_url
}