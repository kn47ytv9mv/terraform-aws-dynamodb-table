# terraform-aws-dynamodb-table

Terraform module for a DynamoDB table — a managed key-value and
document store with single-digit millisecond reads at any scale.

## Cost

On-demand billing (`PAY_PER_REQUEST`, the default here) charges per
read and write request with nothing to pay while idle. Provisioned
billing charges per capacity unit-hour whether or not it is used, and
is cheaper only at sustained, predictable load. Storage, backups,
streams, and cross-region replica traffic bill separately.
`STANDARD_INFREQUENT_ACCESS` trades higher request costs for cheaper
storage. See AWS's
[DynamoDB pricing](https://aws.amazon.com/dynamodb/pricing/) page for
current rates.

## Design

Only **key** attributes go in `attributes` — those used as a partition
key, sort key, or index key. DynamoDB is schemaless for everything
else, and listing a non-key attribute is rejected outright. This is the
most common first-time error with this resource.

`billing_mode` defaults to `PAY_PER_REQUEST` rather than AWS's own
`PROVISIONED`. On-demand costs nothing when idle and never throttles a
traffic spike, which makes it the safer default for a table whose load
is not yet known; a table with steady, well-understood throughput is
cheaper provisioned.

`point_in_time_recovery_enabled` defaults **true**, matching this
family's direction elsewhere of enabling durability protections out of
the box. Without it, an accidental delete or a bad bulk write is
unrecoverable.

`server_side_encryption_enabled` defaults **false**, which is *not* the
same as unencrypted: DynamoDB always encrypts at rest, and this setting
only chooses a customer managed KMS key over AWS's own owned key.
Enable it when an audit requires control and rotation of the key
itself.

Local secondary indexes can only be created alongside the table —
adding one later replaces the table. Global secondary indexes can be
added and removed freely.

### A note on `hash_key` and `range_key`

Provider 6.66.0 emits a deprecation warning on these, pointing at a
`key_schema` replacement. That replacement does not exist in the
provider version this family pins (`~> 6.61` resolves to 6.66.0), where
`key_schema` is absent from the resource schema entirely and
`hash_key`/`range_key` are not themselves marked deprecated in the
schema metadata — the warning ships ahead of the feature. These remain
the only working arguments here until the pin moves to a provider that
actually offers the replacement.

## Usage

```hcl
module "sessions" {
  source = "kn47ytv9mv/dynamodb-table/aws"

  name     = "sessions"
  hash_key = "id"

  attributes = [
    { name = "id", type = "S" },
  ]

  ttl = {
    attribute_name = "expires_at"
  }
}
```

Or directly from this repository, provisioned with a secondary index:

```hcl
module "orders" {
  source = "github.com/kn47ytv9mv/terraform-aws-dynamodb-table"

  name           = "orders"
  billing_mode   = "PROVISIONED"
  read_capacity  = 20
  write_capacity = 20

  hash_key  = "order_id"
  range_key = "created_at"

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
```

## Requirements

| Name | Version |
|---|---|
| terraform | >= 1.9 |
| aws | ~> 6.61 |
| random | ~> 3.9 |

## Providers

| Name | Version |
|---|---|
| aws | ~> 6.61 |
| random | ~> 3.9 |

## Inputs

| Name | Description | Default | Required |
|---|---|---|---|
| name | Name of the table. If null, a unique name is generated. | `null` | no |
| billing_mode | How throughput is billed. `'PAY_PER_REQUEST'` bills per request with no capacity to plan. `'PROVISIONED'` is cheaper at sustained load but requires `read_capacity` and `write_capacity`. | `"PAY_PER_REQUEST"` | no |
| hash_key | Attribute used as the partition key. Must also appear in `attributes`. Cannot be changed without replacing the table. | `null` | no |
| range_key | Attribute used as the sort key. Must also appear in `attributes` if set. Cannot be changed without replacing the table. | `null` | no |
| attributes | Attributes used as a key by the table or any index, each with a `name` and a `type`: `'S'`, `'N'`, or `'B'`. Only key attributes go here. | `[]` | no |
| read_capacity | Provisioned read capacity units. Only used when `billing_mode` is `'PROVISIONED'`, and required in that case. | `null` | no |
| write_capacity | Provisioned write capacity units. Only used when `billing_mode` is `'PROVISIONED'`, and required in that case. | `null` | no |
| global_secondary_indexes | Indexes with their own partition key. `projection_type` is `'ALL'`, `'KEYS_ONLY'`, or `'INCLUDE'` (which alone permits `non_key_attributes`). | `[]` | no |
| local_secondary_indexes | Indexes sharing the table's partition key but sorting on a different attribute. Can only be created with the table. | `[]` | no |
| server_side_encryption_enabled | Whether the table uses a customer managed KMS key. DynamoDB always encrypts at rest regardless; this only chooses the key. | `false` | no |
| server_side_encryption_kms_key_arn | ARN of the KMS key encrypting the table, from `terraform-aws-kms-key`. | `null` | no |
| point_in_time_recovery_enabled | Whether continuous backups allow restoring to any second in the retention window. | `true` | no |
| point_in_time_recovery_period_in_days | Days of recovery history retained, 1 to 35. If null, AWS's own default (35) applies. | `null` | no |
| ttl | Time-to-live configuration, deleting each item once the epoch timestamp in `attribute_name` has passed. | `null` | no |
| stream_enabled | Whether a change stream of item-level modifications is published. | `null` | no |
| stream_view_type | What each stream record contains: `'KEYS_ONLY'`, `'NEW_IMAGE'`, `'OLD_IMAGE'`, or `'NEW_AND_OLD_IMAGES'`. Required when `stream_enabled` is true. | `null` | no |
| replicas | Regions this table is replicated to as a global table. Requires `stream_enabled` with a `'NEW_AND_OLD_IMAGES'` view type. | `[]` | no |
| table_class | Storage class, `'STANDARD'` or `'STANDARD_INFREQUENT_ACCESS'`. | `null` | no |
| deletion_protection_enabled | Whether AWS refuses to delete the table while set. | `null` | no |
| tags | A map of tags to assign to the table. | `null` | no |

## Outputs

| Name | Description |
|---|---|
| id | The ID (name) of the table. |
| arn | The ARN of the table. |
| name | The name of the table. |
| stream_arn | ARN of the table's change stream, when `stream_enabled` is true. |
| stream_label | Timestamp identifying the current incarnation of the stream. |

## License

MIT — see [LICENSE.md](LICENSE.md).
