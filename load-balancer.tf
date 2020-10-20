resource "aws_lb" "jaeger" {
  count              = var.lb_arn == null ? 1 : 0
  tags               = var.tags
  name               = "${local.name_prefix}jaeger"
  load_balancer_type = "network"
  internal           = var.lb_internal
  subnets            = var.subnets
}

data "aws_lb" "jaeger" {
  arn = local.lb_arn
}

// jaeger-collector grpc resources
resource "aws_lb_listener" "jaeger_collector_grpc" {
  load_balancer_arn = local.lb_arn
  protocol          = var.lb_certificate == null ? "TCP" : "TLS"
  ssl_policy        = var.lb_certificate == null ? null : local.tls_policy
  certificate_arn   = var.lb_certificate
  port              = 14250
  default_action {
    type             = "forward"
    target_group_arn = aws_lb_target_group.jaeger_collector_grpc.arn
  }
}

resource "aws_lb_target_group" "jaeger_collector_grpc" {
  tags        = var.tags
  name        = "${local.name_prefix}jaeger-collector-grpc"
  vpc_id      = var.vpc
  target_type = "ip"
  protocol    = "TCP"
  port        = 14250
  health_check {
    port = 14269
    path = "/"
  }
}

// jaeger-collector http resources
resource "aws_lb_listener" "jaeger_collector_http" {
  load_balancer_arn = local.lb_arn
  protocol          = var.lb_certificate == null ? "TCP" : "TLS"
  ssl_policy        = var.lb_certificate == null ? null : local.tls_policy
  certificate_arn   = var.lb_certificate
  port              = 14268
  default_action {
    type             = "forward"
    target_group_arn = aws_lb_target_group.jaeger_collector_http.arn
  }
}

resource "aws_lb_target_group" "jaeger_collector_http" {
  tags        = var.tags
  name        = "${local.name_prefix}jaeger-collector-http"
  vpc_id      = var.vpc
  target_type = "ip"
  protocol    = "TCP"
  port        = 14268
  health_check {
    port = 14269
    path = "/"
  }
}

// jaeger-query resources
resource "aws_lb_listener" "jaeger_query" {
  load_balancer_arn = local.lb_arn
  protocol          = var.lb_certificate == null ? "TCP" : "TLS"
  ssl_policy        = var.lb_certificate == null ? null : local.tls_policy
  certificate_arn   = var.lb_certificate
  port              = 16686
  default_action {
    type             = "forward"
    target_group_arn = aws_lb_target_group.jaeger_query.arn
  }
}

resource "aws_lb_target_group" "jaeger_query" {
  tags        = var.tags
  name        = "${local.name_prefix}jaeger-query"
  vpc_id      = var.vpc
  target_type = "ip"
  protocol    = "TCP"
  port        = 16686
  health_check {
    port = 16687
    path = "/"
  }
}
