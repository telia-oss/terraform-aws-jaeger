//
// Input variables
//

// VPC related
variable "vpc" {
  type        = string
  description = "VPC where the components will be deployed"
}

variable "subnets" {
  type        = list(string)
  description = "Subnet IDs where the components will be deployed"
}

// Access to components
variable "collector_allow_cidrs" {
  type        = list(string)
  description = "CIDRs from where jaeger-collector instances are accessible (\"subnets\" are already allowed)"
  default     = []
}

variable "storage_allow_cidrs" {
  type        = list(string)
  description = "CIDRs from where Elasticsearch is accessible"
  default     = []
}

variable "query_allow_cidrs" {
  type        = list(string)
  description = "CIDRs from where jaeger-query will accessible"
}

// Load balancer related
variable lb_arn {
  type        = string
  description = "Use this NLB instead of creating a new one"
  default     = null
}

variable "lb_internal" {
  type        = bool
  description = "Load balancer is exposed to the internet"
  default     = true
}

variable "lb_certificate" {
  type        = string
  description = "ARN of ACM certificate to use on the load balancer listeners (no TLS on the load balancer if not set)"
  default     = null
}

// Storage related
variable "storage_domain_name" {
  type        = string
  description = "Use this AWS Elasticsearch domain instead of creating a new one"
  default     = null
}

variable "storage_instance_type" {
  type        = string
  description = "Elasticsearch instance type (see https://aws.amazon.com/elasticsearch-service/pricing/)"
  default     = null
}

variable "storage_instance_count" {
  type        = number
  description = "Number of Elasticsearch instances"
  default     = 2
}

variable "storage_volume_size" {
  type        = number
  description = "EBS volume size (in GB) for Elasticsearch"
  default     = null
}

variable "storage_encrypt_at_rest" {
  type        = bool
  description = "Encrypt Elasticsearch EBS volumes (only these instance types support this: https://docs.aws.amazon.com/elasticsearch-service/latest/developerguide/aes-supported-instance-types.html)"
  default     = false
}

variable "storage_retention_days" {
  type        = number
  description = "Delete traces older than this number of days"
  default     = null
}

// Other settings
variable "collector_count" {
  type        = number
  description = "Number of jaeger-collector instances"
  default     = 1
}

variable "name_prefix" {
  type        = string
  description = "Name prefix for all resources"
  default     = null
}

variable "tags" {
  type        = map(string)
  description = "A map of tags passed to resources"
  default     = {}
}

//
// Internal use variables
//

locals {
  lb_arn      = var.lb_arn == null ? aws_lb.jaeger[0].arn : var.lb_arn
  name_prefix = var.name_prefix == null ? "" : "${var.name_prefix}-"
  tls_policy  = "ELBSecurityPolicy-TLS-1-2-2017-01"
}

//
// Outputs
//

output "hostname" {
  value = data.aws_lb.jaeger.dns_name
}

output "url" {
  value = join(
    "",
    [
      var.lb_certificate == true ? "https" : "http",
      "://",
      data.aws_lb.jaeger.dns_name,
      ":16686"
    ]
  )
}

output "lb_zone_id" {
  value = data.aws_lb.jaeger.zone_id
}
