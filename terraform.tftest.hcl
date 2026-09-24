mock_provider "aws" {}

run "invalid_billing_mode_is_rejected" {
  command = plan

  variables {
    billing_mode = "FREE"
    hash_key     = "id"
    attributes   = [{ name = "id", type = "S" }]
  }

  expect_failures = [var.billing_mode]
}

run "invalid_attribute_type_is_rejected" {
  command = plan

  variables {
    hash_key   = "id"
    attributes = [{ name = "id", type = "X" }]
  }

  expect_failures = [var.attributes]
}

run "provisioned_billing_requires_capacity" {
  command = plan

  variables {
    billing_mode = "PROVISIONED"
    hash_key     = "id"
    attributes   = [{ name = "id", type = "S" }]
  }

  expect_failures = [var.write_capacity]
}

run "invalid_projection_type_is_rejected" {
  command = plan

  variables {
    hash_key   = "id"
    attributes = [{ name = "id", type = "S" }, { name = "email", type = "S" }]
    global_secondary_indexes = [
      { name = "by-email", hash_key = "email", projection_type = "EVERYTHING" },
    ]
  }

  expect_failures = [var.global_secondary_indexes]
}

run "non_key_attributes_require_include_projection" {
  command = plan

  variables {
    hash_key   = "id"
    attributes = [{ name = "id", type = "S" }, { name = "email", type = "S" }]
    global_secondary_indexes = [
      { name = "by-email", hash_key = "email", projection_type = "ALL", non_key_attributes = ["name"] },
    ]
  }

  expect_failures = [var.global_secondary_indexes]
}

run "stream_requires_a_view_type" {
  command = plan

  variables {
    hash_key       = "id"
    attributes     = [{ name = "id", type = "S" }]
    stream_enabled = true
  }

  expect_failures = [var.stream_view_type]
}

run "invalid_local_secondary_index_projection_type_is_rejected" {
  command = plan

  variables {
    hash_key  = "id"
    range_key = "created_at"
    attributes = [
      { name = "id", type = "S" },
      { name = "created_at", type = "N" },
      { name = "status", type = "S" },
    ]
    local_secondary_indexes = [
      { name = "by-status", range_key = "status", projection_type = "EVERYTHING" },
    ]
  }

  expect_failures = [var.local_secondary_indexes]
}

run "name_defaults_to_random_uuid" {
  command = apply

  variables {
    hash_key   = "id"
    attributes = [{ name = "id", type = "S" }]
  }

  assert {
    condition     = aws_dynamodb_table.resource.name == random_uuid.resource.id
    error_message = "Leaving name unset should fall back to the generated random_uuid."
  }
}

run "defaults_are_on_demand_with_recovery" {
  command = plan

  variables {
    hash_key   = "id"
    attributes = [{ name = "id", type = "S" }]
  }

  assert {
    condition     = aws_dynamodb_table.resource.billing_mode == "PAY_PER_REQUEST"
    error_message = "Billing should default to on-demand, which costs nothing when idle and never throttles a spike."
  }

  assert {
    condition     = aws_dynamodb_table.resource.point_in_time_recovery[0].enabled == true
    error_message = "Point-in-time recovery should be enabled by default."
  }

  assert {
    condition     = aws_dynamodb_table.resource.server_side_encryption[0].enabled == false
    error_message = "A customer managed KMS key should be opt-in, since DynamoDB already encrypts at rest with an AWS owned key."
  }
}

run "indexes_create_one_block_each" {
  command = plan

  variables {
    hash_key  = "id"
    range_key = "created_at"
    attributes = [
      { name = "id", type = "S" },
      { name = "created_at", type = "N" },
      { name = "email", type = "S" },
    ]
    global_secondary_indexes = [
      { name = "by-email", hash_key = "email", projection_type = "ALL" },
    ]
    local_secondary_indexes = [
      { name = "by-created", range_key = "created_at", projection_type = "KEYS_ONLY" },
    ]
  }

  assert {
    condition     = length(aws_dynamodb_table.resource.global_secondary_index) == 1
    error_message = "Each global_secondary_indexes entry should produce one index block."
  }

  assert {
    condition     = length(aws_dynamodb_table.resource.local_secondary_index) == 1
    error_message = "Each local_secondary_indexes entry should produce one index block."
  }

  assert {
    condition     = length(aws_dynamodb_table.resource.attribute) == 3
    error_message = "Each attributes entry should produce one attribute block."
  }
}

run "no_ttl_or_replicas_by_default" {
  command = plan

  variables {
    hash_key   = "id"
    attributes = [{ name = "id", type = "S" }]
  }

  assert {
    condition     = length(aws_dynamodb_table.resource.ttl) == 0
    error_message = "Leaving ttl unset should emit no ttl block."
  }

  assert {
    condition     = length(aws_dynamodb_table.resource.replica) == 0
    error_message = "Leaving replicas unset should emit no replica blocks."
  }
}

run "ttl_and_replicas_pass_through" {
  command = plan

  variables {
    hash_key   = "id"
    attributes = [{ name = "id", type = "S" }]
    ttl        = { attribute_name = "expires_at" }

    stream_enabled   = true
    stream_view_type = "NEW_AND_OLD_IMAGES"
    replicas = [
      { region_name = "eu-west-1" },
      { region_name = "ap-southeast-2" },
    ]
  }

  assert {
    condition     = aws_dynamodb_table.resource.ttl[0].attribute_name == "expires_at"
    error_message = "The ttl block should carry the supplied attribute name."
  }

  assert {
    condition     = aws_dynamodb_table.resource.ttl[0].enabled == true
    error_message = "A ttl block should default to enabled when supplied."
  }

  assert {
    condition     = length(aws_dynamodb_table.resource.replica) == 2
    error_message = "Each replicas entry should produce one replica block."
  }
}

run "readme_default_example" {
  command = plan

  variables {
    name       = "sessions"
    hash_key   = "id"
    attributes = [{ name = "id", type = "S" }]
    ttl        = { attribute_name = "expires_at" }
  }
}

run "readme_provisioned_with_index_example" {
  command = plan

  variables {
    name           = "orders"
    billing_mode   = "PROVISIONED"
    read_capacity  = 20
    write_capacity = 20
    hash_key       = "order_id"
    range_key      = "created_at"

    attributes = [
      { name = "order_id", type = "S" },
      { name = "created_at", type = "N" },
      { name = "customer_id", type = "S" },
    ]

    global_secondary_indexes = [
      {
        name            = "by-customer"
        hash_key        = "customer_id"
        range_key       = "created_at"
        projection_type = "ALL"
        read_capacity   = 10
        write_capacity  = 10
      },
    ]
  }
}
