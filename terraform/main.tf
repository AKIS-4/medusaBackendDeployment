provider "aws" {
  region = "ap-south-1" 
}

data "aws_vpc" "default" {
  default = true
}

data "aws_subnets" "default" {
  filter {
    name = "vpc-id"
    values = [data.aws_vpc.default.id]
  }
}

resource "aws_security_group" "medusa_sg" {
  name = "medusa-backend-sg"
  vpc_id = data.aws_vpc.default.id

  ingress {
    description = "Allow all inbound traffic"
    from_port = 0
    to_port = 0
    protocol = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  egress {
    description = "Allow all outbound traffic"
    from_port = 0
    to_port = 0
    protocol = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = {
    Name = "medusa-backend-sg"
  }
}

resource "aws_iam_role" "ecs_task_execution" {
  name = "ecsTaskExecutionRole"

  assume_role_policy = jsonencode({
    Version = "2012-10-17",
    Statement = [{
      Action = "sts:AssumeRole",
      Effect = "Allow",
      Principal = {
        Service = "ecs-tasks.amazonaws.com"
      }
    }]
  })
}

resource "aws_iam_role_policy_attachment" "ecs_task_execution_policy" {
  role = aws_iam_role.ecs_task_execution.name
  policy_arn = "arn:aws:iam::aws:policy/service-role/AmazonECSTaskExecutionRolePolicy"
}

resource "aws_ecs_cluster" "medusa" {
  name = "medusa-cluster"
}

resource "aws_db_instance" "medusa_db" {
  identifier = "medusadb"
  engine = "postgres"
  instance_class = "db.t3.micro"
  allocated_storage = 20
  db_name = "medusadb"
  username = "medusa"
  password = "test1234"
  publicly_accessible = true
  skip_final_snapshot = true

  db_subnet_group_name = aws_db_subnet_group.default.name
  depends_on = [aws_db_subnet_group.default]
  vpc_security_group_ids = [aws_security_group.medusa_sg.id]
}

resource "aws_db_subnet_group" "default" {
  name = "medusa-db-subnet-group"
  subnet_ids = data.aws_subnets.default.ids
}


resource "aws_ecs_task_definition" "medusa" {
  family = "medusa-task"
  network_mode = "awsvpc"
  requires_compatibilities = ["FARGATE"]
  cpu = "1024"
  memory = "2048"
  execution_role_arn = aws_iam_role.ecs_task_execution.arn

  container_definitions = templatefile("${path.module}/container_definitions.json.tmpl", {
    db_host = aws_db_instance.medusa_db.address
  })
}

resource "aws_ecs_service" "medusa" {
  name = "medusa-service"
  cluster = aws_ecs_cluster.medusa.id
  task_definition = aws_ecs_task_definition.medusa.arn
  launch_type = "FARGATE"
  desired_count = 1

  network_configuration {
    subnets = data.aws_subnets.default.ids
    assign_public_ip = true
    security_groups = [aws_security_group.medusa_sg.id]
  }
}
