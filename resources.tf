resource "random_uuid" "resource" {}

resource "aws_dynamodb_table" "resource" {
  name         = coalesce(var.name, random_uuid.resource.id)
  billing_mode = var.billing_mode
  hash_key     = var.hash_key
  range_key    = var.range_key

  read_capacity  = var.read_capacity
  write_capacity = var.write_capacity

  stream_enabled   = var.stream_enabled
  stream_view_type = var.stream_view_type

  table_class                 = var.table_class
  deletion_protection_enabled = var.deletion_protection_enabled

  dynamic "attribute" {
    for_each = var.attributes

    content {
      name = attribute.value.name
      type = attribute.value.type
    }
  }

  dynamic "global_secondary_index" {
    for_each = var.global_secondary_indexes

    content {
      name               = global_secondary_index.value.name
      hash_key           = global_secondary_index.value.hash_key
      range_key          = global_secondary_index.value.range_key
      projection_type    = global_secondary_index.value.projection_type
      non_key_attributes = global_secondary_index.value.non_key_attributes
      read_capacity      = global_secondary_index.value.read_capacity
      write_capacity     = global_secondary_index.value.write_capacity
    }
  }

  dynamic "local_secondary_index" {
    for_each = var.local_secondary_indexes

    content {
      name               = local_secondary_index.value.name
      range_key          = local_secondary_index.value.range_key
      projection_type    = local_secondary_index.value.projection_type
      non_key_attributes = local_secondary_index.value.non_key_attributes
    }
  }

  server_side_encryption {
    enabled     = var.server_side_encryption_enabled
    kms_key_arn = var.server_side_encryption_kms_key_arn
  }

  point_in_time_recovery {
    enabled                 = var.point_in_time_recovery_enabled
    recovery_period_in_days = var.point_in_time_recovery_period_in_days
  }

  dynamic "ttl" {
    for_each = var.ttl[*]

    content {
      attribute_name = ttl.value.attribute_name
      enabled        = ttl.value.enabled
    }
  }

  dynamic "replica" {
    for_each = var.replicas

    content {
      region_name            = replica.value.region_name
      kms_key_arn            = replica.value.kms_key_arn
      point_in_time_recovery = replica.value.point_in_time_recovery
      propagate_tags         = replica.value.propagate_tags
      consistency_mode       = replica.value.consistency_mode
    }
  }

  tags = var.tags
}

output "id" {
  description = "The ID (name) of the table."
  value       = aws_dynamodb_table.resource.id
}

output "arn" {
  description = "The ARN of the table."
  value       = aws_dynamodb_table.resource.arn
}

output "name" {
  description = "The name of the table."
  value       = aws_dynamodb_table.resource.name
}

output "stream_arn" {
  description = "ARN of the table's change stream, when stream_enabled is true. Feed this into a Lambda event source mapping to trigger on item changes."
  value       = aws_dynamodb_table.resource.stream_arn
}

output "stream_label" {
  description = "Timestamp identifying the current incarnation of the stream, which changes if the stream is disabled and re-enabled."
  value       = aws_dynamodb_table.resource.stream_label
}
