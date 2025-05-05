variable "aws_region" {
  default = "il-central-1"
}

variable "vpc_id" {
  default = "vpc-042cee0fdc6a5a7e2"
}

variable "subnet_id" {
  default = "subnet-088b7d937a4cd5d85"
}

variable "security_group_id" {
  default = "sg-0ac3749215afde82a"
}

# variable "target_group_arn" {
#   default = "arn:aws:elasticloadbalancing:il-central-1:314525640319:targetgroup/tg-lior-terraform/91cd376d8b300bf6"
# }

variable "log_group_name" {
  default = "/ecs/lior-nginx"
}

variable "task_family" {
  default = "lior-nginx-task-mysql"
}


variable "frontend_image" {
  default = "314525640319.dkr.ecr.il-central-1.amazonaws.com/lior/nodejs-mysql:v2"
}


variable "ecs_service_name" {
  default = "lior-nodejs-service"
}

variable "ecs_cluster" {
  default = "imtech"
}
