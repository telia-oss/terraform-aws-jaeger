resource "aws_ecs_task_definition" "jaeger_query" {
  tags                     = var.tags
  cpu                      = 256
  memory                   = 512
  network_mode             = "awsvpc"
  requires_compatibilities = ["FARGATE"]
  container_definitions = <<-DEFINITION
      [
          {
              "name": "${local.name_prefix}jaeger-query",
              "image": "quay.io/jaegertracing/jaeger-query:1.23.0",
              "portMappings": [
                  {
                      "containerPort": 16686,
                      "hostPort": 16686,
                      "protocol": "tcp"
                  },
                  {
                      "containerPort": 16687,
                      "hostPort": 16687,
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
                  },
                  {
                    ${var.lb_certificate == null ? <<EOS
                        "name": "JAEGER_ENDPOINT",
                        "value": "http://${data.aws_lb.jaeger.dns_name}:14268/api/traces"
                    EOS
                    : <<EOS
                        "name": "JAEGER_DISABLED",
                        "value": "true"
                    EOS
                    }
                  },
                  {
                      "name": "JAEGER_SERVICE_NAME",
                      "value": "jaeger-query"
                  }
              ],
              "logConfiguration": {
                  "logDriver": "awslogs",
                  "options": {
                      "awslogs-group": "/ecs/${local.name_prefix}jaeger-query",
                      "awslogs-region": "${data.aws_region.current.name}",
                      "awslogs-stream-prefix": "${local.name_prefix}jaeger"
                  }
              }
          }
      ]
  DEFINITION
execution_role_arn = aws_iam_role.jaeger_ecs_tasks.arn
family             = "${local.name_prefix}jaeger-query"
}

resource "aws_ecs_service" "jaeger_query" {
  tags            = var.tags
  cluster         = aws_ecs_cluster.jaeger.arn
  name            = "${local.name_prefix}jaeger-query"
  task_definition = aws_ecs_task_definition.jaeger_query.arn
  desired_count   = 1
  launch_type     = "FARGATE"

  network_configuration {
    assign_public_ip = alltrue(data.aws_subnet.selected[*].map_public_ip_on_launch) ? true : false
    subnets          = var.subnets
    security_groups  = [aws_security_group.jaeger_query.id]
  }

  load_balancer {
    target_group_arn = aws_lb_target_group.jaeger_query.arn
    container_name   = "${local.name_prefix}jaeger-query"
    container_port   = 16686
  }
}

resource "aws_security_group" "jaeger_query" {
  tags   = var.tags
  name   = "${local.name_prefix}jaeger-query"
  vpc_id = var.vpc
  ingress {
    from_port   = 16686
    to_port     = 16686
    cidr_blocks = var.query_allow_cidrs
    protocol    = "tcp"
    description = "Web UI"
  }
  ingress {
    from_port   = 16687
    to_port     = 16687
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

resource "aws_cloudwatch_log_group" "jaeger_query" {
  tags = var.tags
  name = "/ecs/${local.name_prefix}jaeger-query"
}
