# terraform-aws-jaeger
This module creates the backend components needed for Jaeger Tracing in your AWS account.

## Module argument explanation:
Required arguments are in bold

| Argument | Type | Description | Default value |
| -------- | ---- | ----------- | ------------- |
| **vpc** | string | VPC where the components will be deployed
| **subnets** | list(string) | Subnet IDs where the components will be deployed
| collector_allow_cidrs | list(string) | CIDRs from where jaeger-collector instances are accessible ('subnets' are already allowed) | []
| storage_allow_cidrs | list(string) | CIDRs from where Elasticsearch is accessible | []
| **query_allow_cidrs** | list(string) | CIDRs from where jaeger-query will accessible | []
| lb_arn | string | Use this NLB instead of creating a new one
| lb_internal | bool | Load balancer is exposed to the internet | false
| lb_certificate | string | ARN of ACM certificate to use on the load balancer listeners (no TLS on the load balancer if not set) | null
| storage_domain_name | string | Use this AWS Elasticsearch domain instead of creating a new one
| storage_instance_type | string | Elasticsearch instance type (see https://aws.amazon.com/elasticsearch-service/pricing/)
| storage_instance_count | number | Number of Elasticsearch instances | 2
| storage_volume_size | number | EBS volume size (in GB) for Elasticsearch
| storage_encrypt_at_rest | bool | Encrypt Elasticsearch EBS volumes (only these instance types support this: https://docs.aws.amazon.com/elasticsearch-service/latest/developerguide/aes-supported-instance-types.html) | false
| storage_retention_days | number | Delete traces older than this number of days (0 disables this)
| collector_count | number | Number of jaeger-collector instances | 1
| name_prefix | string | Name prefix for all resources
| tags | map(string) | A map of tags passed to resources | {}

## Module outputs
**hostname** - hostname of the load balancer fronting the components

**url** - full url to the jaeger-query web interface

**lb_zone_id** - route53 zone id of the load balancer

## Notes

Due to limitations in AWS and Terraform, service-linked roles cannot reliably be created automatically.

You can use the following code in your Terraform to create the roles if they don't exist:
```
resource "aws_iam_service_linked_role" "ecs" {
  aws_service_name = "ecs.amazonaws.com"
}

resource "aws_iam_service_linked_role" "es" {
  aws_service_name = "es.amazonaws.com"
}
```
Or you can import them if they already exist:
```bash
terraform import aws_iam_service_linked_role.ecs arn:aws:iam::<ACCOUNT_ID>:role/aws-service-role/ecs.amazonaws.com/AWSServiceRoleForECS
terraform import aws_iam_service_linked_role.es arn:aws:iam::<ACCOUNT_ID>:role/aws-service-role/es.amazonaws.com/AWSServiceRoleForAmazonElasticsearchService
```
