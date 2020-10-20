resource "aws_ecs_cluster" "jaeger" {
  tags = var.tags
  name = "${local.name_prefix}jaeger"
}

resource "aws_iam_role" "jaeger_ecs_tasks" {
  tags               = var.tags
  name               = "${local.name_prefix}jaeger-ecs-tasks"
  assume_role_policy = data.aws_iam_policy_document.tasks_assume.json
}

data "aws_iam_policy_document" "tasks_assume" {
  statement {
    effect  = "Allow"
    actions = ["sts:AssumeRole"]

    principals {
      type        = "Service"
      identifiers = ["ecs-tasks.amazonaws.com"]
    }
  }
}

resource "aws_iam_role_policy_attachment" "jaeger_ecs_tasks" {
  role       = aws_iam_role.jaeger_ecs_tasks.name
  policy_arn = "arn:aws:iam::aws:policy/service-role/AmazonECSTaskExecutionRolePolicy"
}
