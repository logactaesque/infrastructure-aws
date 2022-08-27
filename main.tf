provider "aws" {
  region = var.region
}

terraform {
  backend "s3" {}
}

# This autoloads files with suffix ".tf" hence variables.tf is referenced

# We assume in place:
# AWS IAM account with relevant privileges to construct AWS resources.
# AWS Access and Secret Key configured (for Linux this would sit under ~/.aws)
# An AWS S3 bucket to hold terraform state


resource "aws_vpc" "logactaesque-vpc" {
  cidr_block = "10.0.0.0/16"
}


# A public and private subnet - we will only use 2 availability zones for now
# The Fargate service will run in the private subnet
resource "aws_subnet" "logactaesque-subnet-public-1" {
  vpc_id            = aws_vpc.logactaesque-vpc.id
  cidr_block        = "10.0.1.0/25"
  availability_zone = var.availability-zone_1
  tags = {
    "name" = "Public logactaesque subnet-1"
  }
}

resource "aws_subnet" "logactaesque-subnet-public-2" {
  vpc_id            = aws_vpc.logactaesque-vpc.id
  cidr_block        = "10.0.1.128/25"
  availability_zone = var.availability-zone_2
  tags = {
    "name" = "Public logactaesque subnet-2"
  }
}

resource "aws_subnet" "logactaesque-subnet-private-1" {
  vpc_id            = aws_vpc.logactaesque-vpc.id
  cidr_block        = "10.0.2.0/25"
  availability_zone = var.availability-zone_1
  tags = {
    "name" = "Private logactaesque subnet"
  }
}

resource "aws_subnet" "logactaesque-subnet-private-2" {
  vpc_id            = aws_vpc.logactaesque-vpc.id
  cidr_block        = "10.0.2.128/25"
  availability_zone = var.availability-zone_2
  tags = {
    "name" = "Private logactaesque subnet-2"
  }
}


# Route tables...
resource "aws_route_table" "logactaesque-route-table-public" {
  vpc_id = aws_vpc.logactaesque-vpc.id
  tags = {
    "name" = "Public logactaesque route table"
  }
}

resource "aws_route_table" "logactaesque-route-table-private" {
  vpc_id = aws_vpc.logactaesque-vpc.id
  tags = {
    "name" = "Private logactaesque route table"
  }
}

# ...and route table associations
resource "aws_route_table_association" "logactaesque-rta-public" {
  subnet_id      = aws_subnet.logactaesque-subnet-public-1.id
  route_table_id = aws_route_table.logactaesque-route-table-public.id
}

resource "aws_route_table_association" "logactaesque-rta-private" {
  subnet_id      = aws_subnet.logactaesque-subnet-private-1.id
  route_table_id = aws_route_table.logactaesque-route-table-private.id
}


# Internet and NAT gateway to enable  resources in the private subnet to access  resources outside of the private subnet.
resource "aws_eip" "logactaesque-nat" {
}

resource "aws_internet_gateway" "logactaesque-igw" {
  vpc_id = aws_vpc.logactaesque-vpc.id
}

resource "aws_nat_gateway" "logactaesque-natgw" {
  allocation_id = aws_eip.logactaesque-nat.id
  subnet_id     = aws_subnet.logactaesque-subnet-public-1.id
  depends_on    = [aws_internet_gateway.logactaesque-igw]
}


# Routes required to enable connection from the resources in the private subnet to outside
resource "aws_route" "public_igw" {
  route_table_id         = aws_route_table.logactaesque-route-table-public.id
  destination_cidr_block = "0.0.0.0/0"
  gateway_id             = aws_internet_gateway.logactaesque-igw.id
}

resource "aws_route" "private_ngw" {
  route_table_id         = aws_route_table.logactaesque-route-table-private.id
  destination_cidr_block = "0.0.0.0/0"
  nat_gateway_id         = aws_nat_gateway.logactaesque-natgw.id
}

# Security Groups

resource "aws_security_group" "http" {
  name        = "http"
  description = "HTTP traffic"
  vpc_id      = aws_vpc.logactaesque-vpc.id
  ingress {
    from_port   = 80
    to_port     = 80
    protocol    = "TCP"
    cidr_blocks = ["0.0.0.0/0"]
  }
}
resource "aws_security_group" "https" {
  name        = "https"
  description = "HTTPS traffic"
  vpc_id      = aws_vpc.logactaesque-vpc.id
  ingress {
    from_port   = 443
    to_port     = 443
    protocol    = "TCP"
    cidr_blocks = ["0.0.0.0/0"]
  }
}
resource "aws_security_group" "egress_all" {
  name        = "egress-all"
  description = "Allow all outbound traffic"
  vpc_id      = aws_vpc.logactaesque-vpc.id
  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }
}
resource "aws_security_group" "ingress_api" {
  name        = "ingress-api"
  description = "Allow ingress to API"
  vpc_id      = aws_vpc.logactaesque-vpc.id
  ingress {
    from_port   = 9001
    to_port     = 9001
    protocol    = "TCP"
    cidr_blocks = ["0.0.0.0/0"]
  }
}

# ECS Cluster and the  task where  container and the service in it will run
resource "aws_ecs_cluster" "dice-roller-cluster" {
  name = "dice-roller-cluster"
}

resource "aws_ecs_task_definition" "logactaesque-dice-roller-td" {
  family                = "logactaesque"
  execution_role_arn    = aws_iam_role.dice-roller-task-execution-role.arn
  container_definitions = <<DEFINITION
  [
    {
      "name": "dice-roller",
      "image": "logactaesque-dice-roller:latest",
      "portMappings": [
        {
          "containerPort": 9001
        }
      ],
      "logConfiguration": {
        "logDriver": "awslogs",
        "options": {
          "awslogs-region": "eu-west-1",
          "awslogs-group": "/ecs/logactaesque",
          "awslogs-stream-prefix": "ecs"
        }
      }
    }
  ]
  DEFINITION
  cpu = 256
  memory = 512
  requires_compatibilities = ["FARGATE"]
  network_mode = "awsvpc"
}

# Log group
resource "aws_cloudwatch_log_group" "logactaesque-log-group" {
  name = "/ecs/logactaesque"
}


# IAM roles to run the task
resource "aws_iam_role" "dice-roller-task-execution-role" {
  name = "dice-roller-task-execution-role"
  assume_role_policy = data.aws_iam_policy_document.ecs_task_assume_role.json
}

data "aws_iam_policy_document" "ecs_task_assume_role" {
  statement {
    actions = ["sts:AssumeRole"]
    principals {
      type = "Service"
      identifiers = ["ecs-tasks.amazonaws.com"]
    }
  }
}

data "aws_iam_policy" "ecs_task_execution_role" {
  arn = "arn:aws:iam::aws:policy/service-role/AmazonECSTaskExecutionRolePolicy"
}

# Attach the above policy to the execution role.
resource "aws_iam_role_policy_attachment" "ecs_task_execution_role-policy-attachment" {
  role = aws_iam_role.dice-roller-task-execution-role.name
  policy_arn = data.aws_iam_policy.ecs_task_execution_role.arn
}

# ECS Service definition
resource "aws_ecs_service" "dice-roller-ecs-service" {
  name = "dice-roller"
  task_definition = aws_ecs_task_definition.logactaesque-dice-roller-td.arn
  cluster = aws_ecs_cluster.dice-roller-cluster.id
  launch_type = "FARGATE"
  load_balancer {
    target_group_arn = aws_lb_target_group.dice-roller-target-group.arn
    container_name = "dice-roller"
    container_port = "9001"
  }
  desired_count = 1
  network_configuration {
    assign_public_ip = false
    security_groups = [
      aws_security_group.egress_all.id,
      aws_security_group.ingress_api.id
    ]
    subnets = [
      aws_subnet.logactaesque-subnet-private-1.id
    ]
  }
}

resource "aws_lb_target_group" "dice-roller-target-group" {
  name = "dice-roller"
  port = 9001
  protocol = "HTTP"
  target_type = "ip"
  vpc_id = aws_vpc.logactaesque-vpc.id
  health_check {
    enabled = true
    path = "/actuator/health"
  }
  depends_on = [aws_alb.dice-roller-alb]
}

resource "aws_alb" "dice-roller-alb" {
  name = "dice-roller-alb"
  internal = false
  load_balancer_type = "application"
  subnets = [
    aws_subnet.logactaesque-subnet-public-1.id,
    aws_subnet.logactaesque-subnet-public-2.id
  ]
  security_groups = [
    aws_security_group.http.id,
    aws_security_group.egress_all.id
  ]
  depends_on = [aws_internet_gateway.logactaesque-igw]
}

resource "aws_alb_listener" "dice-roller-http-listener" {
  load_balancer_arn = aws_alb.dice-roller-alb.arn
  port = "80"
  protocol = "HTTP"
  default_action {
    type = "forward"
    target_group_arn = aws_lb_target_group.dice-roller-target-group.arn
  }
}

# Prints out the URL to reference
output "alb_url" {
  value = "http://${aws_alb.dice-roller-alb.dns_name}"
}

