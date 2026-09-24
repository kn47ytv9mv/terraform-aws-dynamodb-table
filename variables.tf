variable "name" {
  default     = null
  description = "Name of the table. If null, a unique name is generated."
}

variable "billing_mode" {
  default     = "PAY_PER_REQUEST"
  description = "How throughput is billed. 'PAY_PER_REQUEST' bills per request with no capacity to plan and is the default here — it costs nothing when idle and never throttles a traffic spike. 'PROVISIONED' is cheaper at sustained, predictable load but requires read_capacity and write_capacity."

  validation {
    condition     = contains(["PAY_PER_REQUEST", "PROVISIONED"], var.billing_mode)
    error_message = "billing_mode must be either 'PAY_PER_REQUEST' or 'PROVISIONED'."
  }
}

variable "hash_key" {
  default     = null
  description = "Attribute used as the partition key. Must also appear in attributes. Cannot be changed without replacing the table."
}

variable "range_key" {
  default     = null
  description = "Attribute used as the sort key. Must also appear in attributes if set. Cannot be changed without replacing the table."
}

variable "attributes" {
  default     = []
  description = "Attributes used as a key by the table or any of its indexes, each with a name and a type: 'S' (string), 'N' (number), or 'B' (binary). Only key attributes go here — DynamoDB is schemaless for everything else, and listing a non-key attribute is rejected."
  type = list(object({
    name = string
    type = string
  }))

  validation {
    condition     = alltrue([for a in var.attributes : contains(["S", "N", "B"], a.type)])
    error_message = "An attribute's type must be 'S' (string), 'N' (number), or 'B' (binary)."
  }
}

variable "read_capacity" {
  default     = null
  description = "Provisioned read capacity units. Only used when billing_mode is 'PROVISIONED', and required in that case."
}

variable "write_capacity" {
  default     = null
  description = "Provisioned write capacity units. Only used when billing_mode is 'PROVISIONED', and required in that case."

  validation {
    condition     = var.billing_mode != "PROVISIONED" || (var.read_capacity != null && var.write_capacity != null)
    error_message = "read_capacity and write_capacity are both required when billing_mode is 'PROVISIONED'."
  }
}

variable "global_secondary_indexes" {
  default     = []
  description = "Indexes with their own partition key, queryable independently of the table's own keys. projection_type is 'ALL' (every attribute), 'KEYS_ONLY' (key attributes only), or 'INCLUDE' (keys plus non_key_attributes). read_capacity and write_capacity apply only under 'PROVISIONED' billing. Every key referenced must appear in attributes."
  type = list(object({
    name               = string
    hash_key           = string
    projection_type    = string
    range_key          = optional(string)
    non_key_attributes = optional(list(string))
    read_capacity      = optional(number)
    write_capacity     = optional(number)
  }))

  validation {
    condition     = alltrue([for i in var.global_secondary_indexes : contains(["ALL", "KEYS_ONLY", "INCLUDE"], i.projection_type)])
    error_message = "A global secondary index's projection_type must be 'ALL', 'KEYS_ONLY', or 'INCLUDE'."
  }

  validation {
    condition     = alltrue([for i in var.global_secondary_indexes : i.projection_type == "INCLUDE" || i.non_key_attributes == null])
    error_message = "non_key_attributes may only be set on an index whose projection_type is 'INCLUDE'."
  }
}

variable "local_secondary_indexes" {
  default     = []
  description = "Indexes sharing the table's partition key but sorting on a different attribute. Can only be created with the table — adding one later requires replacing it. Every key referenced must appear in attributes."
  type = list(object({
    name               = string
    range_key          = string
    projection_type    = string
    non_key_attributes = optional(list(string))
  }))

  validation {
    condition     = alltrue([for i in var.local_secondary_indexes : contains(["ALL", "KEYS_ONLY", "INCLUDE"], i.projection_type)])
    error_message = "A local secondary index's projection_type must be 'ALL', 'KEYS_ONLY', or 'INCLUDE'."
  }
}

variable "server_side_encryption_enabled" {
  default     = false
  description = "Whether the table is encrypted with a customer managed KMS key. DynamoDB always encrypts at rest regardless — this only chooses a customer managed key over AWS's own owned key, which is what an audit requiring key control and rotation asks for. Defaults false, matching AWS's own default, since the owned key already satisfies encryption-at-rest on its own."
}

variable "server_side_encryption_kms_key_arn" {
  default     = null
  description = "ARN of the KMS key encrypting the table, from terraform-aws-kms-key. Only used when server_side_encryption_enabled is true. If null, AWS's own managed key for DynamoDB is used."
}

variable "point_in_time_recovery_enabled" {
  default     = true
  description = "Whether continuous backups allow restoring the table to any second in the retention window. Defaults true, matching this family's direction elsewhere of enabling durability protections out of the box — without it, an accidental delete or bad write is unrecoverable."
}

variable "point_in_time_recovery_period_in_days" {
  default     = null
  description = "Days of point-in-time recovery history retained, 1 to 35. Only used when point_in_time_recovery_enabled is true. If null, AWS's own default (35) applies."
}

variable "ttl" {
  default     = null
  description = "Time-to-live configuration, deleting each item once the epoch timestamp in attribute_name has passed. DynamoDB deletes expired items on its own schedule, typically within days, and they remain readable until it does. If null, no expiry is applied."
  type = object({
    attribute_name = string
    enabled        = optional(bool, true)
  })
}

variable "stream_enabled" {
  default     = null
  description = "Whether a change stream of item-level modifications is published, for a Lambda trigger or a cross-region replica. If null, AWS's own default (disabled) applies."
}

variable "stream_view_type" {
  default     = null
  description = "What each stream record contains: 'KEYS_ONLY', 'NEW_IMAGE', 'OLD_IMAGE', or 'NEW_AND_OLD_IMAGES'. Required when stream_enabled is true."

  validation {
    condition     = var.stream_enabled != true || var.stream_view_type != null
    error_message = "stream_view_type is required when stream_enabled is true."
  }
}

variable "replicas" {
  default     = []
  description = "Regions this table is replicated to as a global table, each a fully writable copy. Requires stream_enabled with a 'NEW_AND_OLD_IMAGES' view type. point_in_time_recovery and kms_key_arn configure the replica independently of the primary."
  type = list(object({
    region_name            = string
    kms_key_arn            = optional(string)
    point_in_time_recovery = optional(bool)
    propagate_tags         = optional(bool)
    consistency_mode       = optional(string)
  }))
}

variable "table_class" {
  default     = null
  description = "Storage class, 'STANDARD' or 'STANDARD_INFREQUENT_ACCESS'. Infrequent access trades higher read and write costs for materially cheaper storage, worth it for a table holding far more data than it serves. If null, AWS's own default ('STANDARD') applies."
}

variable "deletion_protection_enabled" {
  default     = null
  description = "Whether AWS refuses to delete the table while set. Enabling it makes terraform destroy fail until a separate apply turns it off again. If null, AWS's own default (disabled) applies."
}

variable "tags" {
  default     = null
  description = "A map of tags to assign to the table."
}
