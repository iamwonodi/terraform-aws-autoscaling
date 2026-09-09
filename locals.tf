locals {
  common_tags = merge(
    var.tags,
    {
      Name        = "${var.project_name}-${var.environment}-${var.service_name}-worker"
      Environment = var.environment
      Service     = var.service_name
    }
  )

  # mixed_instances_policy accepts either a list of simple instance_type
  # overrides, or a single attribute-based instance_requirements override --
  # not both at once. instance_requirements, when set, replaces the whole
  # instance_types-derived override list with one attribute-based override.
  # Both are irrelevant when mixed_instances_enabled is false.
  use_instance_requirements = var.mixed_instances_enabled && var.instance_requirements != null

  simple_overrides = (var.mixed_instances_enabled && !local.use_instance_requirements) ? [
    for instance_type in var.instance_types : {
      instance_type     = instance_type
      weighted_capacity = try(tostring(var.instance_type_weights[instance_type]), null)
    }
  ] : []

  # capacity_reservation_specification's capacity_reservation_preference is
  # itself a Required field within the block, so the whole block is only
  # emitted when the caller has actually set a preference.
  capacity_reservation_specification_enabled = var.capacity_reservation_preference != null

  # instance_refresh always refreshes on launch_template/mixed_instances_policy
  # changes; additional trigger properties are appended and de-duplicated in
  # case the caller also lists "launch_template" explicitly.
  instance_refresh_triggers = distinct(concat(["launch_template"], var.instance_refresh_triggers))
}
