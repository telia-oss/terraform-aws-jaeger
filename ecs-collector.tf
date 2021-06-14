resource "aws_ecs_task_definition" "jaeger_collector" {
  tags                     = var.tags
  cpu                      = 256
  memory                   = 512
  network_mode             = "awsvpc"
  requires_compatibilities = ["FARGATE"]
  container_definitions    = <<-DEFINITION
      [
          {
              "name": "${local.name_prefix}jaeger-collector",
              "image": "quay.io/jaegertracing/jaeger-collector:1.23.0",
              "portMappings": [
                  {
                      "containerPort": 14250,
                      "hostPort": 14250,
                      "protocol": "tcp"
                  },
                  {
                      "containerPort": 14268,
                      "hostPort": 14268,
                      "protocol": "tcp"
                  },
                  {
                      "containerPort": 14269,
                      "hostPort": 14269,
                      "protocol": "tcp"
                  }
              ],
              "environment": [
                  {
                    "name": "SPAN_STORAGE_TYPE",
                    "value": "elasticsearch"
                  },
                  {
                    "name": "ES_SERVER_URLS",
                    "value": "https://${data.aws_elasticsearch_domain.jaeger_storage.endpoint}"
                  }
              ],
              "logConfiguration": {
                  "logDriver": "awslogs",
                  "options": {
                      "awslogs-group": "/ecs/${local.name_prefix}jaeger-collector",
                      "awslogs-region": "${data.aws_region.current.name}",
                      "awslogs-stream-prefix": "${local.name_prefix}jaeger"
                  }
              }
          }
      ]
  DEFINITION
  execution_role_arn       = aws_iam_role.jaeger_ecs_tasks.arn
  family                   = "${local.name_prefix}jaeger-collector"
}

resource "aws_ecs_service" "jaeger_collector" {
  tags            = var.tags
  cluster         = aws_ecs_cluster.jaeger.arn
  name            = "${local.name_prefix}jaeger-collector"
  task_definition = aws_ecs_task_definition.jaeger_collector.arn
  desired_count   = var.collector_count
  launch_type     = "FARGATE"

  network_configuration {
    assign_public_ip = alltrue(data.aws_subnet.selected[*].map_public_ip_on_launch) ? true : false
    subnets          = var.subnets
    security_groups  = [aws_security_group.jaeger_collector.id]
  }

  load_balancer {
    target_group_arn = aws_lb_target_group.jaeger_collector_grpc.arn
    container_name   = "${local.name_prefix}jaeger-collector"
    container_port   = 14250
  }

  load_balancer {
    target_group_arn = aws_lb_target_group.jaeger_collector_http.arn
    container_name   = "${local.name_prefix}jaeger-collector"
    container_port   = 14268
  }
}

resource "aws_security_group" "jaeger_collector" {
  tags   = var.tags
  name   = "${local.name_prefix}jaeger-collector"
  vpc_id = var.vpc
  ingress {
    from_port = 14250
    to_port   = 14250
    cidr_blocks = concat(
      var.collector_allow_cidrs,
      [for subnet in data.aws_subnet.selected : subnet.cidr_block]
    )
    protocol    = "tcp"
    description = "HTTP/gRPC"
  }
  ingress {
    from_port = 14268
    to_port   = 14268
    cidr_blocks = concat(
      var.collector_allow_cidrs,
      [for subnet in data.aws_subnet.selected : subnet.cidr_block]
    )
    protocol    = "tcp"
    description = "HTTP/Thrift"
  }
  ingress {
    from_port   = 14269
    to_port     = 14269
    cidr_blocks = [for subnet in data.aws_subnet.selected : subnet.cidr_block]
    protocol    = "tcp"
    description = "Healthcheck"
  }
  egress {
    from_port   = 0
    to_port     = 0
    cidr_blocks = ["0.0.0.0/0"]
    protocol    = "-1"
  }
}

resource "aws_cloudwatch_log_group" "jaeger_collector" {
  tags = var.tags
  name = "/ecs/${local.name_prefix}jaeger-collector"
}
