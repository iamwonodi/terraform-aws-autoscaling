###################################################################################
# AUTOSCALING GROUP RESOURCE
#
# The launch template is not created here -- launch_template_id and
# launch_template_version are supplied by the caller, sourced from a
# dedicated launch-template module. This lets the two evolve and be tested
# independently, and lets more than one Auto Scaling Group reference the
# same launch template if ever needed.
###################################################################################

resource "aws_autoscaling_group" "this" {
  name                = "${var.project_name}-${var.environment}-${var.service_name}-asg"
  vpc_zone_identifier = var.subnet_ids

  min_size         = var.min_size
  desired_capacity = var.desired_capacity
  max_size         = var.max_size

  max_instance_lifetime = var.max_instance_lifetime > 0 ? var.max_instance_lifetime : null
  protect_from_scale_in = var.protect_from_scale_in

  # Set only when this module owns the group's traffic sources; otherwise left
  # alone, so attachments made elsewhere are not reverted (see the lifecycle block).
  target_group_arns = var.manage_traffic_sources ? var.target_group_arns : null

  dynamic "traffic_source" {
    for_each = var.manage_traffic_sources ? var.traffic_sources : []

    content {
      identifier = traffic_source.value.identifier
      type       = traffic_source.value.type
    }
  }

  health_check_type         = var.health_check_type
  health_check_grace_period = var.health_check_grace_period
  capacity_rebalance        = var.capacity_rebalance

  default_cooldown        = var.default_cooldown
  default_instance_warmup = var.default_instance_warmup

  termination_policies = var.termination_policies
  suspended_processes  = var.suspended_processes

  force_delete              = var.force_delete
  wait_for_capacity_timeout = var.wait_for_capacity_timeout

  enabled_metrics = length(var.enabled_metrics) > 0 ? var.enabled_metrics : null

  placement_group = var.placement_group

  dynamic "availability_zone_distribution" {
    for_each = var.availability_zone_distribution_strategy == null ? [] : [var.availability_zone_distribution_strategy]

    content {
      capacity_distribution_strategy = availability_zone_distribution.value
    }
  }

  dynamic "capacity_reservation_specification" {
    for_each = local.capacity_reservation_specification_enabled ? [var.capacity_reservation_preference] : []

    content {
      capacity_reservation_preference = capacity_reservation_specification.value

      dynamic "capacity_reservation_target" {
        for_each = (
          length(var.capacity_reservation_ids) > 0 || length(var.capacity_reservation_resource_group_arns) > 0
        ) ? [1] : []

        content {
          capacity_reservation_ids                 = length(var.capacity_reservation_ids) > 0 ? var.capacity_reservation_ids : null
          capacity_reservation_resource_group_arns = length(var.capacity_reservation_resource_group_arns) > 0 ? var.capacity_reservation_resource_group_arns : null
        }
      }
    }
  }

  dynamic "warm_pool" {
    for_each = var.warm_pool == null ? [] : [var.warm_pool]

    content {
      pool_state                  = warm_pool.value.pool_state
      min_size                    = warm_pool.value.min_size
      max_group_prepared_capacity = warm_pool.value.max_group_prepared_capacity

      instance_reuse_policy {
        reuse_on_scale_in = warm_pool.value.reuse_on_scale_in
      }
    }
  }

  dynamic "initial_lifecycle_hook" {
    for_each = var.initial_lifecycle_hooks

    content {
      name                    = initial_lifecycle_hook.value.name
      lifecycle_transition    = initial_lifecycle_hook.value.lifecycle_transition
      default_result          = initial_lifecycle_hook.value.default_result
      heartbeat_timeout       = initial_lifecycle_hook.value.heartbeat_timeout
      notification_target_arn = initial_lifecycle_hook.value.notification_target_arn
      role_arn                = initial_lifecycle_hook.value.role_arn
      notification_metadata   = initial_lifecycle_hook.value.notification_metadata
    }
  }

  dynamic "instance_maintenance_policy" {
    for_each = var.instance_maintenance_policy == null ? [] : [var.instance_maintenance_policy]

    content {
      min_healthy_percentage = instance_maintenance_policy.value.min_healthy_percentage
      max_healthy_percentage = instance_maintenance_policy.value.max_healthy_percentage
    }
  }

  # ---------------------------------------------------------------------------
  # LAUNCH MODE
  #
  # Exactly one of these two blocks is emitted, chosen by
  # var.mixed_instances_enabled -- see that variable's description for what
  # each mode expects from the referenced launch template.
  # ---------------------------------------------------------------------------
  dynamic "launch_template" {
    for_each = var.mixed_instances_enabled ? [] : [1]

    content {
      id      = var.launch_template_id
      version = var.launch_template_version
    }
  }

  dynamic "mixed_instances_policy" {
    for_each = var.mixed_instances_enabled ? [1] : []

    content {
      launch_template {
        launch_template_specification {
          launch_template_id = var.launch_template_id
          version            = var.launch_template_version
        }

        dynamic "override" {
          for_each = local.simple_overrides

          content {
            instance_type     = override.value.instance_type
            weighted_capacity = override.value.weighted_capacity
          }
        }

        dynamic "override" {
          for_each = local.use_instance_requirements ? [var.instance_requirements] : []

          content {
            instance_requirements {
              memory_mib {
                min = override.value.memory_mib.min
                max = override.value.memory_mib.max
              }

              vcpu_count {
                min = override.value.vcpu_count.min
                max = override.value.vcpu_count.max
              }

              allowed_instance_types    = override.value.allowed_instance_types
              excluded_instance_types   = override.value.excluded_instance_types
              instance_generations      = override.value.instance_generations
              cpu_manufacturers         = override.value.cpu_manufacturers
              bare_metal                = override.value.bare_metal
              burstable_performance     = override.value.burstable_performance
              local_storage             = override.value.local_storage
              local_storage_types       = override.value.local_storage_types
              require_hibernate_support = override.value.require_hibernate_support

              dynamic "memory_gib_per_vcpu" {
                for_each = override.value.memory_gib_per_vcpu == null ? [] : [override.value.memory_gib_per_vcpu]

                content {
                  min = memory_gib_per_vcpu.value.min
                  max = memory_gib_per_vcpu.value.max
                }
              }

              dynamic "network_bandwidth_gbps" {
                for_each = override.value.network_bandwidth_gbps == null ? [] : [override.value.network_bandwidth_gbps]

                content {
                  min = network_bandwidth_gbps.value.min
                  max = network_bandwidth_gbps.value.max
                }
              }

              on_demand_max_price_percentage_over_lowest_price = override.value.on_demand_max_price_percentage_over_lowest_price
              spot_max_price_percentage_over_lowest_price      = override.value.spot_max_price_percentage_over_lowest_price
            }
          }
        }
      }

      instances_distribution {
        on_demand_allocation_strategy            = var.on_demand_allocation_strategy
        on_demand_base_capacity                  = var.on_demand_base_capacity
        on_demand_percentage_above_base_capacity = var.on_demand_percentage_above_base_capacity
        spot_allocation_strategy                 = var.spot_allocation_strategy
        spot_instance_pools                      = var.spot_instance_pools
        spot_max_price                           = var.spot_max_price
      }
    }
  }

  # ============================================================================
  # THE AUTOMATED ROLLING INSTANCE REFRESH CONFIGURATION
  # ============================================================================
  instance_refresh {
    strategy = "Rolling"

    preferences {
      min_healthy_percentage       = var.instance_refresh_min_healthy_percentage
      max_healthy_percentage       = var.instance_refresh_max_healthy_percentage
      instance_warmup              = var.instance_refresh_warmup
      auto_rollback                = var.instance_refresh_auto_rollback
      checkpoint_delay             = var.instance_refresh_checkpoint_delay
      checkpoint_percentages       = length(var.instance_refresh_checkpoint_percentages) > 0 ? var.instance_refresh_checkpoint_percentages : null
      skip_matching                = var.instance_refresh_skip_matching
      scale_in_protected_instances = var.instance_refresh_scale_in_protected_instances
      standby_instances            = var.instance_refresh_standby_instances

      dynamic "alarm_specification" {
        for_each = length(var.instance_refresh_alarm_arns) > 0 ? [var.instance_refresh_alarm_arns] : []

        content {
          alarms = alarm_specification.value
        }
      }
    }

    triggers = local.instance_refresh_triggers
  }

  lifecycle {
    create_before_destroy = true

    # Target groups are an attribute of the group, so an attachment made anywhere
    # else reads as drift and the next apply would remove it. On a shared group
    # that takes every service out of its load balancer at once.
    #
    # ignore_changes cannot be conditional, so it is unconditional and
    # manage_traffic_sources decides whether the attribute is set at all. The
    # consequence is stated plainly: with manage_traffic_sources = true,
    # target_group_arns is applied when the group is CREATED and changes to it
    # afterwards are ignored; change them with attachment resources instead.
    #
    # Only the two ATTRIBUTES are listed. A traffic_source BLOCK attached
    # elsewhere (VPC Lattice) is not protected by this; attach those from the
    # configuration that owns the group.
    ignore_changes = [target_group_arns, load_balancers]

    precondition {
      condition     = var.manage_traffic_sources || (length(var.target_group_arns) == 0 && length(var.traffic_sources) == 0)
      error_message = "target_group_arns and traffic_sources are set, but manage_traffic_sources is false, so they would be ignored. Set manage_traffic_sources = true, or attach them from the configuration that owns the target group."
    }

    precondition {
      condition = (
        var.min_size <= var.desired_capacity &&
        var.desired_capacity <= var.max_size
      )

      error_message = "Auto Scaling capacity values must satisfy min_size <= desired_capacity <= max_size."
    }

    precondition {
      condition = (
        length(var.capacity_reservation_ids) == 0 ||
        length(var.capacity_reservation_resource_group_arns) == 0
      )

      error_message = "capacity_reservation_ids and capacity_reservation_resource_group_arns are mutually exclusive."
    }

    precondition {
      condition = (
        (length(var.capacity_reservation_ids) == 0 && length(var.capacity_reservation_resource_group_arns) == 0) ||
        var.capacity_reservation_preference != null
      )

      error_message = "capacity_reservation_preference must be set when capacity_reservation_ids or capacity_reservation_resource_group_arns is provided."
    }

    precondition {
      condition = (
        var.spot_instance_pools == 0 ||
        var.spot_allocation_strategy == "lowest-price"
      )

      error_message = "spot_instance_pools is only available when spot_allocation_strategy is lowest-price; otherwise it must be left at 0."
    }
  }

  dynamic "tag" {
    for_each = local.common_tags

    content {
      key                 = tag.key
      value               = tag.value
      propagate_at_launch = true
    }
  }
}
