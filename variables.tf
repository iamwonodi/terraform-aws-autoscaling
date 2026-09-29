################################################################################
# CORE IDENTIFICATION
################################################################################

variable "project_name" {
  type        = string
  description = "Name of the project."

  validation {
    condition     = trimspace(var.project_name) != ""
    error_message = "project_name must not be empty."
  }
}

variable "environment" {
  type        = string
  description = "Deployment environment."

  validation {
    condition     = trimspace(var.environment) != ""
    error_message = "environment must not be empty."
  }
}

variable "service_name" {
  type        = string
  description = "Logical name of the service or fleet this Auto Scaling Group belongs to. Used to name the group and tag the instances it launches."

  validation {
    condition     = trimspace(var.service_name) != ""
    error_message = "service_name must not be empty."
  }
}

################################################################################
# LAUNCH TEMPLATE REFERENCE
#
# This module does not create a launch template -- it references one from
# a dedicated launch-template module, so the two can evolve and be tested
# independently.
################################################################################

variable "launch_template_id" {
  type        = string
  description = "ID of the launch template to use. Typically the id output of a launch-template module."

  validation {
    condition     = trimspace(var.launch_template_id) != ""
    error_message = "launch_template_id must not be empty."
  }
}

variable "launch_template_version" {
  type        = string
  description = "Launch template version to use. Typically the latest_version output of a launch-template module, so each new template version is picked up automatically. Left null defers to AWS's own default ($Default)."
  default     = null
}

################################################################################
# LAUNCH MODE
#
# AWS's aws_autoscaling_group requires choosing exactly one of a plain
# launch_template block or a mixed_instances_policy block. This module
# supports both behind a single toggle instead of requiring two separate
# modules, since nearly everything else about an Auto Scaling Group -- health
# checks, capacity, termination behavior, warm pools, lifecycle hooks,
# instance refresh -- is identical between the two.
#
# When true, the referenced launch template's own instance_type must be left
# unset (instance selection happens through this module's instance_types /
# instance_requirements instead). When false, the referenced launch
# template's instance_type must be set, and instance_types /
# instance_requirements and every instances-distribution variable below are
# ignored.
################################################################################

variable "mixed_instances_enabled" {
  type        = bool
  description = "Whether to use mixed_instances_policy (multiple instance types, On-Demand/Spot mixing) instead of a single-instance-type launch_template block."
  default     = true
}

################################################################################
# NETWORKING
################################################################################

variable "subnet_ids" {
  type        = list(string)
  description = "Subnet IDs where Auto Scaling instances will be launched."

  validation {
    condition     = length(var.subnet_ids) > 0
    error_message = "subnet_ids must contain at least one subnet ID."
  }
}

################################################################################
# CAPACITY
################################################################################

variable "min_size" {
  type        = number
  description = "Minimum number of instances in the Auto Scaling Group."
  default     = 2

  validation {
    condition     = var.min_size >= 0
    error_message = "min_size must be greater than or equal to 0."
  }
}

variable "desired_capacity" {
  type        = number
  description = "Desired number of instances in the Auto Scaling Group."
  default     = 4

  validation {
    condition     = var.desired_capacity >= 0
    error_message = "desired_capacity must be greater than or equal to 0."
  }
}

variable "max_size" {
  type        = number
  description = "Maximum number of instances in the Auto Scaling Group."
  default     = 8

  validation {
    condition     = var.max_size >= 0
    error_message = "max_size must be greater than or equal to 0."
  }
}

variable "max_instance_lifetime" {
  type        = number
  description = "Maximum number of seconds an instance may remain in service before forced replacement. Must be 0 (disabled) or between 86400 and 31536000."
  default     = 0

  validation {
    condition     = var.max_instance_lifetime == 0 || (var.max_instance_lifetime >= 86400 && var.max_instance_lifetime <= 31536000)
    error_message = "max_instance_lifetime must be 0, or between 86400 and 31536000 seconds."
  }
}

variable "protect_from_scale_in" {
  type        = bool
  description = "Whether newly launched instances are protected from termination during scale-in."
  default     = false
}

################################################################################
# MIXED INSTANCES POLICY - INSTANCE TYPES
#
# Only used when mixed_instances_enabled is true.
################################################################################

variable "instance_types" {
  type        = list(string)
  description = "Instance types available via simple overrides. Ignored when instance_requirements is set, or when mixed_instances_enabled is false."

  default = [
    "t3.small",
    "t3.medium",
    "t3a.small"
  ]

  validation {
    condition = alltrue([
      for instance_type in var.instance_types :
      can(regex("^[a-z0-9]+\\.[a-z0-9]+$", instance_type))
    ])

    error_message = "Each instance type must use a valid AWS instance-type format such as t3.small or t4g.medium."
  }
}

variable "instance_type_weights" {
  type        = map(number)
  description = "Optional weighted_capacity per instance type in instance_types, keyed by instance type. Instance types not listed here get no explicit weight (AWS treats this as a weight of 1)."
  default     = {}
}

variable "instance_requirements" {
  type = object({
    memory_mib = object({
      min = number
      max = optional(number)
    })

    vcpu_count = object({
      min = number
      max = optional(number)
    })

    allowed_instance_types    = optional(list(string))
    excluded_instance_types   = optional(list(string))
    instance_generations      = optional(list(string))
    cpu_manufacturers         = optional(list(string))
    bare_metal                = optional(string)
    burstable_performance     = optional(string)
    local_storage             = optional(string)
    local_storage_types       = optional(list(string))
    require_hibernate_support = optional(bool)

    memory_gib_per_vcpu = optional(object({
      min = optional(number)
      max = optional(number)
    }))

    network_bandwidth_gbps = optional(object({
      min = optional(number)
      max = optional(number)
    }))

    on_demand_max_price_percentage_over_lowest_price = optional(number)
    spot_max_price_percentage_over_lowest_price      = optional(number)
  })

  description = <<-EOT
    Optional attribute-based instance selection, used instead of an explicit
    instance_types list. When set, this module lets AWS choose eligible
    instance types automatically based on the requirements described here,
    rather than the caller enumerating instance types by name.

    Mutually exclusive with instance_types being used for overrides -- when
    instance_requirements is set, it is applied as a single override instead
    of one override per entry in instance_types. Ignored when
    mixed_instances_enabled is false.
  EOT

  default = null

  validation {
    condition = (
      var.instance_requirements == null || (
        var.instance_requirements.bare_metal == null ||
        contains(["included", "excluded", "required"], var.instance_requirements.bare_metal)
      )
    )

    error_message = "instance_requirements.bare_metal must be included, excluded, or required."
  }

  validation {
    condition = (
      var.instance_requirements == null || (
        var.instance_requirements.burstable_performance == null ||
        contains(["included", "excluded", "required"], var.instance_requirements.burstable_performance)
      )
    )

    error_message = "instance_requirements.burstable_performance must be included, excluded, or required."
  }

  validation {
    condition = (
      var.instance_requirements == null || (
        var.instance_requirements.local_storage == null ||
        contains(["included", "excluded", "required"], var.instance_requirements.local_storage)
      )
    )

    error_message = "instance_requirements.local_storage must be included, excluded, or required."
  }

  validation {
    condition = (
      var.instance_requirements == null ||
      var.instance_requirements.allowed_instance_types == null ||
      var.instance_requirements.excluded_instance_types == null
    )

    error_message = "instance_requirements.allowed_instance_types and excluded_instance_types are mutually exclusive."
  }
}

################################################################################
# MIXED INSTANCE DISTRIBUTION
#
# Only used when mixed_instances_enabled is true.
################################################################################

variable "on_demand_allocation_strategy" {
  type        = string
  description = "Strategy used when launching On-Demand instances."
  default     = "prioritized"

  validation {
    condition     = contains(["prioritized", "lowest-price"], var.on_demand_allocation_strategy)
    error_message = "on_demand_allocation_strategy must be prioritized or lowest-price."
  }
}

variable "on_demand_base_capacity" {
  type        = number
  description = "Number of On-Demand instances maintained before Spot capacity is used."
  default     = 2

  validation {
    condition     = var.on_demand_base_capacity >= 0
    error_message = "on_demand_base_capacity must be greater than or equal to 0."
  }
}

variable "on_demand_percentage_above_base_capacity" {
  type        = number
  description = "Percentage of On-Demand capacity above the base capacity."
  default     = 0

  validation {
    condition = (
      var.on_demand_percentage_above_base_capacity >= 0 &&
      var.on_demand_percentage_above_base_capacity <= 100
    )

    error_message = "on_demand_percentage_above_base_capacity must be between 0 and 100."
  }
}

variable "spot_allocation_strategy" {
  type        = string
  description = "Spot allocation strategy used by the mixed instances policy."
  default     = "price-capacity-optimized"

  validation {
    condition = contains(
      [
        "capacity-optimized",
        "capacity-optimized-prioritized",
        "lowest-price",
        "price-capacity-optimized"
      ],
      var.spot_allocation_strategy
    )

    error_message = "spot_allocation_strategy must be one of: capacity-optimized, capacity-optimized-prioritized, lowest-price, or price-capacity-optimized."
  }
}

variable "spot_instance_pools" {
  type        = number
  description = "Number of Spot pools per Availability Zone to allocate capacity across. Only used when spot_allocation_strategy is lowest-price; must be 0 otherwise."
  default     = 0

  validation {
    condition     = var.spot_instance_pools >= 0
    error_message = "spot_instance_pools must be greater than or equal to 0."
  }
}

variable "spot_max_price" {
  type        = string
  description = "Maximum hourly price for Spot instances. Left null (the default) means the On-Demand price is used as the cap."
  default     = null
}

################################################################################
# HEALTH CHECK
################################################################################

variable "health_check_type" {
  type = string

  description = <<-DESCRIPTION
    How the group decides an instance is unhealthy.

    "EC2" watches the instance itself. "ELB" also replaces an instance that a
    target group reports unhealthy, which is what a group running ONE service
    wants -- and the wrong thing for a group running several, where one service
    failing its health check would make the group replace a host that every other
    service on it is also running.
  DESCRIPTION

  default = "EC2"

  validation {
    condition     = contains(["EC2", "ELB"], var.health_check_type)
    error_message = "health_check_type must be either EC2 or ELB."
  }
}

variable "health_check_grace_period" {
  type        = number
  description = "Seconds to wait after launching an instance before health checks begin."
  default     = 300

  validation {
    condition     = var.health_check_grace_period >= 0
    error_message = "health_check_grace_period must be greater than or equal to 0."
  }
}

variable "capacity_rebalance" {
  type        = bool
  description = "Whether the Auto Scaling Group should proactively replace Spot instances that are at elevated interruption risk. Most meaningful when Spot capacity is in use."
  default     = true
}

variable "default_cooldown" {
  type        = number
  description = "Seconds after a scaling activity completes before another can start."
  default     = null

  validation {
    condition     = var.default_cooldown == null || var.default_cooldown >= 0
    error_message = "default_cooldown must be greater than or equal to 0."
  }
}

variable "default_instance_warmup" {
  type        = number
  description = "Seconds until a newly launched instance contributes to CloudWatch metric aggregation. Distinct from health_check_grace_period."
  default     = null

  validation {
    condition     = var.default_instance_warmup == null || var.default_instance_warmup >= 0
    error_message = "default_instance_warmup must be greater than or equal to 0."
  }
}

################################################################################
# TARGET GROUPS AND TRAFFIC SOURCES
################################################################################

variable "manage_traffic_sources" {
  type        = bool
  default     = false
  description = <<-DESCRIPTION
    Whether THIS module owns the group's target groups.

    An Auto Scaling Group's target groups are an attribute of the group, so an
    attachment made anywhere else -- aws_autoscaling_attachment,
    aws_autoscaling_traffic_source_attachment, another configuration, the console --
    reads as drift here and the next apply removes it. Where several services each
    attach their own target group to one shared group, that quietly takes every
    service out of its load balancer.

    false (the default) leaves the attribute alone after the group is created, so
    attachments made elsewhere survive. Attach with
    aws_autoscaling_traffic_source_attachment in the configuration that owns the
    target group.

    true lets this module set target_group_arns and traffic_sources, and it will
    then revert anything attached elsewhere. Only sensible when this configuration
    is the single owner of the group's traffic sources.
  DESCRIPTION
}

variable "target_group_arns" {
  type        = list(string)
  default     = []
  description = "Target group ARNs to attach. Requires manage_traffic_sources = true; with it false, attach from the configuration that owns the target group instead."
}

variable "traffic_sources" {
  type = list(object({
    identifier = string
    type       = string
  }))
  default     = []
  description = "Traffic sources (VPC Lattice, and target groups by ARN) to attach. Requires manage_traffic_sources = true."
}

variable "availability_zone_distribution_strategy" {
  type        = string
  description = "Strategy for distributing capacity across Availability Zones."
  default     = null

  validation {
    condition = (
      var.availability_zone_distribution_strategy == null ||
      contains(["balanced-only", "balanced-best-effort", "reservations-then-balanced"], var.availability_zone_distribution_strategy)
    )

    error_message = "availability_zone_distribution_strategy must be balanced-only, balanced-best-effort, or reservations-then-balanced."
  }
}

variable "capacity_reservation_preference" {
  type        = string
  description = "Whether the group prioritizes launching into On-Demand Capacity Reservations before On-Demand capacity."
  default     = null

  validation {
    condition = (
      var.capacity_reservation_preference == null ||
      contains(["default", "capacity-reservations-only", "capacity-reservations-first", "none"], var.capacity_reservation_preference)
    )

    error_message = "capacity_reservation_preference must be default, capacity-reservations-only, capacity-reservations-first, or none."
  }
}

variable "capacity_reservation_ids" {
  type        = list(string)
  description = "On-Demand Capacity Reservation IDs to target. Mutually exclusive with capacity_reservation_resource_group_arns."
  default     = []
}

variable "capacity_reservation_resource_group_arns" {
  type        = list(string)
  description = "On-Demand Capacity Reservation resource group ARNs to target. Mutually exclusive with capacity_reservation_ids."
  default     = []
}

################################################################################
# TERMINATION AND MAINTENANCE BEHAVIOR
################################################################################

variable "termination_policies" {
  type        = list(string)
  description = "Policies deciding which instances the Auto Scaling Group terminates first."
  default     = ["Default"]

  validation {
    condition = alltrue([
      for policy in var.termination_policies :
      contains(
        ["OldestInstance", "NewestInstance", "OldestLaunchConfiguration", "ClosestToNextInstanceHour", "OldestLaunchTemplate", "AllocationStrategy", "Default"],
        policy
      ) || can(regex("^arn:", policy))
    ])

    error_message = "Each termination policy must be a recognized AWS termination policy name or the ARN of a custom termination Lambda."
  }
}

variable "suspended_processes" {
  type        = list(string)
  description = "Auto Scaling processes to suspend. Suspending Launch or Terminate can prevent the group from functioning correctly."
  default     = []

  validation {
    condition = alltrue([
      for process in var.suspended_processes :
      contains(
        ["Launch", "Terminate", "HealthCheck", "ReplaceUnhealthy", "AZRebalance", "AlarmNotification", "ScheduledActions", "AddToLoadBalancer", "InstanceRefresh"],
        process
      )
    ])

    error_message = "Each suspended process must be a recognized Auto Scaling process name."
  }
}

variable "instance_maintenance_policy" {
  type = object({
    min_healthy_percentage = number
    max_healthy_percentage = number
  })

  description = "Optional bounds on in-service capacity during instance replacement, independent of instance_refresh."
  default     = null
}

variable "force_delete" {
  type        = bool
  description = "Whether to delete the Auto Scaling Group without waiting for instances to terminate."
  default     = false
}

variable "wait_for_capacity_timeout" {
  type        = string
  description = "Maximum duration Terraform waits for ASG instances to become healthy. \"0\" disables capacity waiting."
  default     = "10m"
}

################################################################################
# METRICS
################################################################################

variable "enabled_metrics" {
  type        = list(string)
  description = "CloudWatch group metrics to collect. Empty list disables metrics collection."
  default     = []
}

################################################################################
# PLACEMENT GROUP
################################################################################

variable "placement_group" {
  type        = string
  description = "Name of an existing placement group for the Auto Scaling Group."
  default     = null
}

################################################################################
# WARM POOL
################################################################################

variable "warm_pool" {
  type = object({
    pool_state                  = optional(string, "Stopped")
    min_size                    = optional(number, 0)
    max_group_prepared_capacity = optional(number)
    reuse_on_scale_in           = optional(bool, false)
  })

  description = "Optional Warm Pool configuration, keeping pre-initialized instances ready to reduce scale-out latency."
  default     = null

  validation {
    condition     = var.warm_pool == null || contains(["Stopped", "Running", "Hibernated"], var.warm_pool.pool_state)
    error_message = "warm_pool.pool_state must be Stopped, Running, or Hibernated."
  }
}

################################################################################
# LIFECYCLE HOOKS
################################################################################

variable "initial_lifecycle_hooks" {
  type = list(object({
    name                    = string
    lifecycle_transition    = string
    default_result          = optional(string, "ABANDON")
    heartbeat_timeout       = optional(number)
    notification_target_arn = optional(string)
    role_arn                = optional(string)
    notification_metadata   = optional(string)
  }))

  description = "Lifecycle hooks attached before instances are launched. For hooks added after the group already exists, use a standalone aws_autoscaling_lifecycle_hook resource instead."
  default     = []

  validation {
    condition = alltrue([
      for hook in var.initial_lifecycle_hooks :
      contains(
        ["autoscaling:EC2_INSTANCE_LAUNCHING", "autoscaling:EC2_INSTANCE_TERMINATING"],
        hook.lifecycle_transition
      )
    ])

    error_message = "Each lifecycle hook's lifecycle_transition must be autoscaling:EC2_INSTANCE_LAUNCHING or autoscaling:EC2_INSTANCE_TERMINATING."
  }

  validation {
    condition = alltrue([
      for hook in var.initial_lifecycle_hooks :
      contains(["CONTINUE", "ABANDON"], hook.default_result)
    ])

    error_message = "Each lifecycle hook's default_result must be CONTINUE or ABANDON."
  }
}

################################################################################
# INSTANCE REFRESH
################################################################################

variable "instance_refresh_min_healthy_percentage" {
  type        = number
  description = "Minimum percentage of instances that must remain healthy during refresh."
  default     = 50

  validation {
    condition     = var.instance_refresh_min_healthy_percentage >= 0 && var.instance_refresh_min_healthy_percentage <= 100
    error_message = "instance_refresh_min_healthy_percentage must be between 0 and 100."
  }
}

variable "instance_refresh_max_healthy_percentage" {
  type        = number
  description = "Maximum percentage of in-service-or-pending capacity allowed during refresh."
  default     = 100

  validation {
    condition     = var.instance_refresh_max_healthy_percentage >= 100 && var.instance_refresh_max_healthy_percentage <= 200
    error_message = "instance_refresh_max_healthy_percentage must be between 100 and 200."
  }
}

variable "instance_refresh_warmup" {
  type        = number
  description = "Seconds to wait for a new instance to warm up during instance refresh."
  default     = 300

  validation {
    condition     = var.instance_refresh_warmup >= 0
    error_message = "instance_refresh_warmup must be greater than or equal to 0."
  }
}

variable "instance_refresh_auto_rollback" {
  type        = bool
  description = "Whether failed instance refreshes should automatically roll back."
  default     = true
}

variable "instance_refresh_checkpoint_delay" {
  type        = number
  description = "Seconds to wait after each instance refresh checkpoint."
  default     = null
}

variable "instance_refresh_checkpoint_percentages" {
  type        = list(number)
  description = "Ascending list of checkpoint percentages for instance refresh; the final value must be 100 if set."
  default     = []

  validation {
    condition = (
      length(var.instance_refresh_checkpoint_percentages) == 0 ||
      var.instance_refresh_checkpoint_percentages == sort(var.instance_refresh_checkpoint_percentages)
    )

    error_message = "instance_refresh_checkpoint_percentages must be in ascending order."
  }

  validation {
    condition = (
      length(var.instance_refresh_checkpoint_percentages) == 0 ||
      var.instance_refresh_checkpoint_percentages[length(var.instance_refresh_checkpoint_percentages) - 1] == 100
    )

    error_message = "instance_refresh_checkpoint_percentages must end in 100 to fully replace instances."
  }
}

variable "instance_refresh_skip_matching" {
  type        = bool
  description = "Whether to skip replacing instances that already match the desired configuration."
  default     = false
}

variable "instance_refresh_scale_in_protected_instances" {
  type        = string
  description = "Behavior for instances protected from scale-in during a refresh."
  default     = "Ignore"

  validation {
    condition     = contains(["Refresh", "Ignore", "Wait"], var.instance_refresh_scale_in_protected_instances)
    error_message = "instance_refresh_scale_in_protected_instances must be Refresh, Ignore, or Wait."
  }
}

variable "instance_refresh_standby_instances" {
  type        = string
  description = "Behavior for instances in the Standby state during a refresh."
  default     = "Ignore"

  validation {
    condition     = contains(["Terminate", "Ignore", "Wait"], var.instance_refresh_standby_instances)
    error_message = "instance_refresh_standby_instances must be Terminate, Ignore, or Wait."
  }
}

variable "instance_refresh_alarm_arns" {
  type        = list(string)
  description = "CloudWatch alarm ARNs that abort an in-progress instance refresh if any enters ALARM state."
  default     = []
}

variable "instance_refresh_triggers" {
  type        = list(string)
  description = "Additional ASG property names that trigger an instance refresh. Changes to launch_template and mixed_instances_policy always trigger one, so those two are ignored if listed."
  default     = []
}

################################################################################
# TAGS
################################################################################

variable "tags" {
  type        = map(string)
  description = "Additional tags applied to the instances and Auto Scaling Group."
  default     = {}
}
