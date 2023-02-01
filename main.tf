resource "aws_wafv2_web_acl_association" "default" {
  count = module.this.enabled && !var.ignore_waf_associations && length(var.association_resource_arns) > 0 ? length(var.association_resource_arns) : 0

  resource_arn = var.association_resource_arns[count.index]
  web_acl_arn  = join("", aws_wafv2_web_acl.default.*.arn)
}

resource "aws_wafv2_web_acl_association" "ignore_waf_associations" {
  count = module.this.enabled && var.ignore_waf_associations && length(var.association_resource_arns) > 0 ? length(var.association_resource_arns) : 0

  resource_arn = var.association_resource_arns[count.index]
  web_acl_arn  = join("", aws_wafv2_web_acl.default.*.arn)

  lifecycle {
    ignore_changes = [resource_arn]
  }
}

resource "aws_kinesis_firehose_delivery_stream" "default" {
  count = module.this.enabled && var.extended_s3_configuration != null ? 1 : 0

  name        = "aws-waf-logs-${var.environment}-${var.name}-${element(module.kinesis.attributes, 0)}" //https://github.com/pulumi/pulumi-aws/issues/1214#issuecomment-891868939
  destination = "extended_s3"

  extended_s3_configuration {
    role_arn           = var.extended_s3_configuration.role_arn
    bucket_arn         = var.extended_s3_configuration.bucket_arn
    buffer_size        = var.extended_s3_configuration.buffer_size
    buffer_interval    = var.extended_s3_configuration.buffer_interval
    compression_format = var.extended_s3_configuration.compression_format
  }
}

resource "aws_wafv2_web_acl_logging_configuration" "default" {
  count = module.this.enabled && var.extended_s3_configuration != null ? 1 : 0

  log_destination_configs = [aws_kinesis_firehose_delivery_stream.default.arn]
  resource_arn            = join("", aws_wafv2_web_acl.default.*.arn)

  dynamic "redacted_fields" {
    for_each = var.redacted_fields

    content {
      dynamic "method" {
        for_each = redacted_fields.value.method_enabled ? [1] : []

        content {
        }
      }

      dynamic "query_string" {
        for_each = redacted_fields.value.query_string_enabled ? [1] : []

        content {
        }
      }

      dynamic "uri_path" {
        for_each = redacted_fields.value.uri_path_enabled ? [1] : []

        content {
        }
      }

      dynamic "single_header" {
        for_each = lookup(redacted_fields.value, "single_header", null) != null ? toset(redacted_fields.value.single_header) : []
        content {
          name = single_header.value
        }
      }
    }
  }
}
