provider "aws" {
  region = var.aws_region 
}
# from vars.tf
data "aws_vpc"            "vpc"    { id = var.vpc_id }
data "aws_subnet"         "subnet" { id = var.subnet_id }
data "aws_security_group" "sg"     { id = var.security_group_id }
data "aws_lb"             "imtec"  { name = "imtec" }


#  DB endpoint + Secret
data "aws_db_instance" "existing_db" {
  db_instance_identifier = "database-1"
}

data "aws_secretsmanager_secret" "creds_secret" {
  arn = "arn:aws:secretsmanager:il-central-1:314525640319:secret:imtech/lior-ailn3R"
}

resource "aws_ssm_parameter" "db_endpoint_param" {
  name  = "/lior/db"
  type  = "String"
  value = data.aws_db_instance.existing_db.endpoint
}


#  EXISTING TASK ROLE
data "aws_iam_role" "existing_task_role" {
  name = "ECS-Task-Role-imtech"         # <-- your pre‑created role
}

# attach SSM read‑only
resource "aws_iam_role_policy_attachment" "task_ssm_access" {
  role       = data.aws_iam_role.existing_task_role.name
  policy_arn = "arn:aws:iam::aws:policy/AmazonSSMReadOnlyAccess"
}

# custom inline policy for Secrets Manager + Parameter Store
resource "aws_iam_policy" "secret_read_policy" {
  name   = "lior_app_secret_read"
  policy = jsonencode({
    Version = "2012-10-17",
    Statement = [
      {
        Effect   = "Allow",
        Action   = ["secretsmanager:GetSecretValue"],
        Resource = data.aws_secretsmanager_secret.creds_secret.arn
      },
      {
        Effect   = "Allow",
        Action   = ["ssm:GetParameter"],
        Resource = aws_ssm_parameter.db_endpoint_param.arn
      }
    ]
  })
}

resource "aws_iam_role_policy_attachment" "attach_secret_policy" {
  role       = data.aws_iam_role.existing_task_role.name
  policy_arn = aws_iam_policy.secret_read_policy.arn
}


#  CloudWatch log group
resource "aws_cloudwatch_log_group" "app_logs" {
  name              = "/ecs/lior-nodeapp"
  retention_in_days = 14
}


#  Target Group (port 3000)
resource "aws_lb_target_group" "tg_node" {
  name        = "tg-lior-nodejs-mysql"
  port        = 3000
  protocol    = "HTTP"
  vpc_id      = data.aws_vpc.vpc.id
  target_type = "ip"

  health_check {
    path                = "/health"
    protocol            = "HTTP"
    matcher             = "200-499"
    interval            = 30
    timeout             = 5
    healthy_threshold   = 2
    unhealthy_threshold = 3
  }
}


#  Listener (port 101 ➜ TG)
resource "aws_lb_listener" "listener_node" {
  load_balancer_arn = data.aws_lb.imtec.arn
  port              = 8090
  protocol          = "HTTPS"

  default_action {
    type             = "forward"
    target_group_arn = aws_lb_target_group.tg_node.arn
  }
}


#  TASK DEFINITION (single container)
resource "aws_ecs_task_definition" "node_task" {
  family                   = var.task_family           
  execution_role_arn       = "arn:aws:iam::314525640319:role/ecsTaskExecutionRole"
  task_role_arn            = data.aws_iam_role.existing_task_role.arn   # <-- use existing role
  requires_compatibilities = ["FARGATE"]
  network_mode             = "awsvpc"
  cpu                      = "1024"
  memory                   = "2048"

  container_definitions = jsonencode([
    {
      name  : "lior-nodejs-mysql",
      image : var.my_image,
      cpu   : 1024,
      memory: 2048,
      portMappings : [
        { containerPort : 3000, hostPort : 3000, protocol : "tcp" }
      ],
      environment : [
        { name : "PORT"       , value : "3000" },
        { name : "DB_ENDPOINT", value : data.aws_db_instance.existing_db.endpoint },
        { name : "SECRET_ARN" , value : data.aws_secretsmanager_secret.creds_secret.arn }
      ],
      logConfiguration : {
        logDriver : "awslogs",
        options   : {
          awslogs-group         : aws_cloudwatch_log_group.app_logs.name,
          awslogs-region        : var.aws_region,
          awslogs-stream-prefix : "nodejs"
        }
      }
    }
  ])
}

#  ECS Service
resource "aws_ecs_service" "node_service" {
  name            = var.ecs_service_name
  cluster         = var.ecs_cluster
  task_definition = aws_ecs_task_definition.node_task.arn
  launch_type     = "FARGATE"
  desired_count   = 1

  network_configuration {
    subnets         = [data.aws_subnet.subnet.id]
    security_groups = [data.aws_security_group.sg.id]
    assign_public_ip = true
  }

  load_balancer {
    target_group_arn = aws_lb_target_group.tg_node.arn
    container_name   = "lior-nodejs-mysql"
    container_port   = 3000
  }
}
