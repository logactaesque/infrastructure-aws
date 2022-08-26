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

resource "aws_internet_gateway" "logactaesque-igw" {
  vpc_id = aws_vpc.logactaesque-vpc.id
}

resource "aws_subnet" "logactaesque-subnet-public" {
  vpc_id            = aws_vpc.logactaesque-vpc.id
  cidr_block        = "10.0.1.0/24"
  availability_zone = var.availability-zone
  tags = {
    "name" = "Public logactaesque subnet"
  }
}

resource "aws_subnet" "logactaesque-subnet-private" {
  vpc_id            = aws_vpc.logactaesque-vpc.id
  cidr_block        = "10.0.2.0/24"
  availability_zone = var.availability-zone
  tags = {
    "name" = "Private logactaesque subnet"
  }
}

resource "aws_route_table" "logactaesque-route-table-public" {
  vpc_id = aws_vpc.logactaesque-vpc.id
}

resource "aws_route" "public" {
  route_table_id         = aws_route_table.logactaesque-route-table-public.id
  destination_cidr_block = "0.0.0.0/0"
  gateway_id             = aws_internet_gateway.logactaesque-igw.id
}

resource "aws_route_table_association" "logactaesque-rta-public" {
  count          = length(aws_subnet.logactaesque-subnet-public)
  subnet_id      = element(aws_subnet.logactaesque-subnet-public.*.id, count.index)
  route_table_id = aws_route_table.logactaesque-route-table-public.id
}

resource "aws_eip" "logactaesque-eip" {
  count = length(aws_subnet.logactaesque-subnet-private)
  vpc   = true
}
resource "aws_nat_gateway" "logactaesque-natgw" {
  count         = length(aws_subnet.logactaesque-subnet-private)
  allocation_id = element(aws_eip.logactaesque-eip.*.id, count.index)
  subnet_id     = element(aws_subnet.logactaesque-subnet-public.*.id, count.index)
  depends_on    = [aws_internet_gateway.logactaesque-igw]
}


resource "aws_route_table" "logactaesque-route-table-private" {
  count  = length(aws_subnet.logactaesque-subnet-private)
  vpc_id = aws_vpc.logactaesque-vpc.id
}

resource "aws_route" "private" {
  count                  = length(aws_subnet.logactaesque-subnet-private)
  route_table_id         = element(aws_route_table.logactaesque-route-table-private.*.id, count.index)
  destination_cidr_block = "0.0.0.0/0"
  nat_gateway_id         = element(aws_nat_gateway.logactaesque-natgw.*.id, count.index)
}

resource "aws_route_table_association" "logactaesque-rta-private" {
  count          = length(aws_subnet.logactaesque-subnet-private)
  subnet_id      = element(aws_subnet.logactaesque-subnet-private.*.id, count.index)
  route_table_id = element(aws_route_table.logactaesque-route-table-private.*.id, count.index)
}

# Security Groups

resource "aws_security_group" "logactaesque-sg_alb" {
  vpc_id = aws_vpc.logactaesque-vpc.id

  ingress {
    protocol         = "tcp"
    from_port        = 80
    to_port          = 80
    cidr_blocks      = ["0.0.0.0/0"]
    ipv6_cidr_blocks = ["::/0"]
  }

  ingress {
    protocol         = "tcp"
    from_port        = 443
    to_port          = 443
    cidr_blocks      = ["0.0.0.0/0"]
    ipv6_cidr_blocks = ["::/0"]
  }

  egress {
    protocol         = "-1"
    from_port        = 0
    to_port          = 0
    cidr_blocks      = ["0.0.0.0/0"]
    ipv6_cidr_blocks = ["::/0"]
  }

  tags = {
    Name = "Logactaesque Application Load Balancer Security Group"
  }
}

resource "aws_security_group" "logactaesque-sg_ecs_tasks" {
  vpc_id = aws_vpc.logactaesque-vpc.id

  ingress {
    protocol         = "tcp"
    from_port        = 8080
    to_port          = 8080
    cidr_blocks      = ["0.0.0.0/0"]
    ipv6_cidr_blocks = ["::/0"]
  }

  egress {
    protocol         = "-1"
    from_port        = 0
    to_port          = 0
    cidr_blocks      = ["0.0.0.0/0"]
    ipv6_cidr_blocks = ["::/0"]
  }

  tags = {
    Name = "Logactaesque ECS Tasks Security Group"
  }
}

# Log group
resource "aws_cloudwatch_log_group" "my_api" {
  name = "/ecs/logactaesque"
}


# IAM roles to run the task
resource "aws_iam_role" "dice-roller-task-execution-role" {
  name               = "dice-roller-task-execution-role"
  assume_role_policy = data.aws_iam_policy_document.ecs_task_assume_role.json
}
data "aws_iam_policy_document" "ecs_task_assume_role" {
  statement {
    actions = ["sts:AssumeRole"]
    principals {
      type        = "Service"
      identifiers = ["ecs-tasks.amazonaws.com"]
    }
  }
}

data "aws_iam_policy" "ecs_task_execution_role" {
  arn = "arn:aws:iam::aws:policy/service-role/AmazonECSTaskExecutionRolePolicy"
}

# Attach the above policy to the execution role.
resource "aws_iam_role_policy_attachment" "ecs_task_execution_role-policy-attachment" {
  role       = aws_iam_role.dice-roller-task-execution-role.name
  policy_arn = data.aws_iam_policy.ecs_task_execution_role.arn
}


# ECS Cluster
resource "aws_ecs_cluster" "dice-roller-cluster" {
  name = "Dice Roller Cluster"
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
          "containerPort": 8080
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

# ECS Service definition
resource "aws_ecs_service" "dice-roller-ecs-service" {
  name = "dice-roller"
  task_definition = aws_ecs_task_definition.logactaesque-dice-roller-td.arn
  cluster = aws_ecs_cluster.dice-roller-cluster.id
  launch_type = "FARGATE"
  load_balancer {
    target_group_arn = aws_lb_target_group.dice-roller-target-group.arn
    container_name = "dice-roller"
    container_port = "8080"
  }
  desired_count = 1
  network_configuration {
    assign_public_ip = false
    security_groups = [
      aws_security_group.logactaesque-sg_ecs_tasks.id
    ]
    subnets = [
      aws_subnet.logactaesque-subnet-private.id
    ]
  }
}

resource "aws_lb_target_group" "dice-roller-target-group" {
  port = 8080
  protocol = "HTTP"
  target_type = "ip"
  vpc_id = aws_vpc.logactaesque-vpc.id
  health_check {
    enabled = true
    path = "/health"
  }
  depends_on = [aws_alb.dice-roller-alb]
}

resource "aws_alb" "dice-roller-alb" {
  name = "dice-roller-alb"
  internal = false
  load_balancer_type = "application"
  subnets = [
    aws_subnet.logactaesque-subnet-public.id
  ]
  security_groups = [
    aws_security_group.logactaesque-sg_alb.id,
    aws_security_group.logactaesque-sg_ecs_tasks.id
  ]
  depends_on = [aws_internet_gateway.logactaesque-igw]
}

resource "aws_alb_listener" "dice-roller-http-listener" {
  load_balancer_arn = aws_alb.dice-roller-alb.arn
  port = "8080"
  protocol = "HTTP"
  default_action {
    type = "forward"
    target_group_arn = aws_lb_target_group.dice-roller-target-group.arn
  }
}

output "alb_url" {
  value = "http://${aws_alb.dice-roller-alb.dns_name}"
}

