resource "aws_elasticsearch_domain" "jaeger_storage" {
  count       = var.storage_domain_name == null ? 1 : 0
  tags        = var.tags
  domain_name = "${local.name_prefix}jaeger-storage"
  ebs_options {
    ebs_enabled = var.storage_volume_size != null ? true : false
    volume_size = var.storage_volume_size
  }
  cluster_config {
    instance_type          = var.storage_instance_type
    instance_count         = var.storage_instance_count
    zone_awareness_enabled = var.storage_instance_count > 1 ? true : false
    dynamic "zone_awareness_config" {
      for_each = length(var.subnets) > 1 ? [1] : []
      content {
        availability_zone_count = var.storage_instance_count < 3 ? var.storage_instance_count : 3
      }
    }
  }
  vpc_options {
    subnet_ids         = var.storage_instance_count < 3 ? slice(var.subnets, 0, var.storage_instance_count) : var.subnets
    security_group_ids = [aws_security_group.jaeger_storage[0].id]
  }
  access_policies       = <<-POLICY
    {
      "Version": "2012-10-17",
      "Statement": [
        {
          "Action": "es:*",
          "Principal": "*",
          "Effect": "Allow",
          "Resource": "arn:aws:es:${data.aws_region.current.name}:${data.aws_caller_identity.effective.account_id}:domain/${local.name_prefix}jaeger-storage/*"
        }
      ]
    }
  POLICY
  elasticsearch_version = "7.7"

  // Encryption
  encrypt_at_rest {
    enabled = var.storage_encrypt_at_rest
  }
  domain_endpoint_options {
    enforce_https       = true
    tls_security_policy = "Policy-Min-TLS-1-2-2019-07"
  }
  node_to_node_encryption {
    enabled = true
  }
}

data "aws_elasticsearch_domain" "jaeger_storage" {
  domain_name = var.storage_domain_name == null ? "${local.name_prefix}jaeger-storage" : var.storage_domain_name
  depends_on  = [aws_elasticsearch_domain.jaeger_storage]
}

resource "aws_security_group" "jaeger_storage" {
  count  = var.storage_domain_name == null ? 1 : 0
  tags   = var.tags
  name   = "${local.name_prefix}jaeger-storage"
  vpc_id = var.vpc
  ingress {
    from_port = 443
    to_port   = 443
    security_groups = concat(
      [
        aws_security_group.jaeger_collector.id,
        aws_security_group.jaeger_query.id,
      ],
      var.storage_retention_days == null ? [] : [aws_security_group.jaeger_housekeep[0].id]
    )
    protocol = "tcp"
  }
  ingress {
    from_port   = 443
    to_port     = 443
    cidr_blocks = var.storage_allow_cidrs
    protocol    = "tcp"
  }
}
