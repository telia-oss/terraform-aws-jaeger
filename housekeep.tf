data "archive_file" "housekeep" {
  count       = var.storage_retention_days == null ? 0 : 1
  output_path = "housekeep.zip"
  type        = "zip"
  source_file = "${path.module}/housekeep.py"
}

resource "aws_security_group" "jaeger_housekeep" {
  tags   = var.tags
  count  = var.storage_retention_days == null ? 0 : 1
  name   = "${local.name_prefix}jaeger-housekeep"
  vpc_id = var.vpc
  egress {
    from_port   = 0
    to_port     = 0
    cidr_blocks = ["0.0.0.0/0"]
    protocol    = "-1"
  }
}

resource "aws_lambda_function" "jaeger_housekeep" {
  tags          = var.tags
  count         = var.storage_retention_days == null ? 0 : 1
  function_name = "${local.name_prefix}jaeger-housekeep"
  role          = aws_iam_role.jaeger_housekeep[0].arn
  handler       = "housekeep.lambda_handler"
  runtime       = "python3.7"
  environment {
    variables = {
      ES_HOSTNAME       = data.aws_elasticsearch_domain.jaeger_storage.endpoint
      ES_RETENTION_DAYS = var.storage_retention_days
    }
  }
  vpc_config {
    security_group_ids = [aws_security_group.jaeger_housekeep[0].id]
    subnet_ids         = var.subnets
  }
  filename         = data.archive_file.housekeep[0].output_path
  source_code_hash = data.archive_file.housekeep[0].output_base64sha256
}

//
// IAM
//
resource "aws_iam_role" "jaeger_housekeep" {
  tags               = var.tags
  count              = var.storage_retention_days == null ? 0 : 1
  name               = "${local.name_prefix}jaeger-housekeep"
  assume_role_policy = data.aws_iam_policy_document.lambda_assume[0].json
}

data "aws_iam_policy_document" "lambda_assume" {
  count = var.storage_retention_days == null ? 0 : 1
  statement {
    effect  = "Allow"
    actions = ["sts:AssumeRole"]

    principals {
      type        = "Service"
      identifiers = ["lambda.amazonaws.com"]
    }
  }
}

resource "aws_iam_policy_attachment" "housekeep_lambda" {
  count      = var.storage_retention_days == null ? 0 : 1
  name       = "jaeger-housekeep"
  roles      = [aws_iam_role.jaeger_housekeep[0].name]
  policy_arn = "arn:aws:iam::aws:policy/service-role/AWSLambdaVPCAccessExecutionRole"
}

//
// CloudWatch
//
resource "aws_cloudwatch_event_rule" "housekeep" {
  tags                = var.tags
  count               = var.storage_retention_days == null ? 0 : 1
  name                = "${local.name_prefix}jaeger-housekeep"
  schedule_expression = "rate(1 day)"
}

resource "aws_cloudwatch_event_target" "housekeep" {
  count = var.storage_retention_days == null ? 0 : 1
  rule  = aws_cloudwatch_event_rule.housekeep[0].name
  arn   = aws_lambda_function.jaeger_housekeep[0].arn
}

resource "aws_lambda_permission" "housekeep" {
  count         = var.storage_retention_days == null ? 0 : 1
  action        = "lambda:InvokeFunction"
  function_name = aws_lambda_function.jaeger_housekeep[0].function_name
  principal     = "events.amazonaws.com"
}
