provider "aws" {
  region = var.region
}
//
// Common resources that do not fit in elsewhere
//
data "aws_caller_identity" "effective" {}

data "aws_region" "current" {}

data "aws_subnet" "selected" {
  count = length(var.subnets)
  id    = var.subnets[count.index]
}
