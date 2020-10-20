// VPC
data "aws_vpc" "default_vpc" {
  default = true
}

data "aws_subnet_ids" "subnets" {
  vpc_id = data.aws_vpc.default_vpc.id
}

// Resources that should be provisioned before the tests are run
data "aws_elasticsearch_domain" "jaeger" {
  domain_name = "jaeger"
}

data "aws_lb" "jaeger_lb" {
  name = "jaeger"
}

// Instantiate a basic deployment
module "jaeger" {
  source              = "../.."
  name_prefix         = var.name_prefix
  query_allow_cidrs   = ["0.0.0.0/0"]
  storage_domain_name = data.aws_elasticsearch_domain.jaeger.domain_name
  lb_arn              = data.aws_lb.jaeger_lb.arn
  lb_internal         = false
  vpc                 = data.aws_vpc.default_vpc.id
  subnets             = data.aws_subnet_ids.subnets.ids
}
