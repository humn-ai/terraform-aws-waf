resource "aws_wafv2_web_acl_association" "default" {
  count = module.this.enabled && length(var.association_resource_arns) > 0 ? length(var.association_resource_arns) : 0

  resource_arn = var.association_resource_arns[count.index]
  web_acl_arn  = join("", aws_wafv2_web_acl.default.*.arn)
}

resource "aws_kinesis_firehose_delivery_stream" "default" {
  name        = "aws-waf-logs-${var.environment}-${var.name}-${element(module.kinesis.attributes, 0)}" //https://github.com/pulumi/pulumi-aws/issues/1214#issuecomment-891868939
  destination = "extended_s3"

  dynamic "extended_s3_configuration" {
    for_each = var.extended_s3_configuration
    content {
      role_arn            = extended_s3_configuration.value.role_arn
      bucket_arn          = extended_s3_configuration.value.bucket_arn
      prefix              = "${module.this.id}/"
      error_output_prefix = "error-${module.this.id}/"
      buffer_size         = extended_s3_configuration.value.buffer_size
      buffer_interval     = extended_s3_configuration.value.buffer_interval
      compression_format  = extended_s3_configuration.value.compression_format
      dynamic "data_format_conversion_configuration" {
        for_each = extended_s3_configuration.value.data_format_conversion_configuration != [] ? [1] : []
        content {
        }
      }
      dynamic "processing_configuration" {
        for_each = extended_s3_configuration.value.processing_configuration != [] ? [1] : []
        content {
        }
      }
    }
  }
}

resource "aws_wafv2_web_acl_logging_configuration" "default" {
  count = module.this.enabled ? 1 : 0

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
