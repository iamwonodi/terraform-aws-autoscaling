################################################################################
# AUTO SCALING GROUP - COMPLETE EXAMPLE
#
# Demonstrates the mixed-instances mode (the module's default). For a
# single-instance-type Auto Scaling Group instead, set
# mixed_instances_enabled = false and point launch_template_id /
# launch_template_version at a launch template whose own instance_type is
# set (see the launch-template module's own example).
#
# launch_template_id / launch_template_version are supplied as plain
# variables in this example so it can be validated standalone. In a real
# setup these come from a launch-template module, e.g.:
#
#   launch_template_id      = module.launch_template.id
#   launch_template_version = module.launch_template.latest_version
################################################################################

module "autoscaling" {
  source = "../../"

  project_name = var.project_name
  environment  = var.environment
  service_name = var.service_name

  launch_template_id      = var.launch_template_id
  launch_template_version = var.launch_template_version

  subnet_ids = var.subnet_ids

  min_size         = 2
  desired_capacity = 4
  max_size         = 8

  instance_types = [
    "t3.small",
    "t3.medium",
    "t3a.small"
  ]

  instance_type_weights = {
    "t3.medium" = 2
  }

  on_demand_base_capacity                  = 2
  on_demand_percentage_above_base_capacity = 0
  spot_allocation_strategy                 = "price-capacity-optimized"
  capacity_rebalance                       = true

  health_check_type         = "ELB"
  health_check_grace_period = 300

  target_group_arns = [var.target_group_arn]

  termination_policies = ["OldestLaunchTemplate", "Default"]

  # Keeps two pre-initialized instances ready so scale-out doesn't wait on a
  # full boot + warmup cycle.
  warm_pool = {
    pool_state        = "Stopped"
    min_size          = 2
    reuse_on_scale_in = true
  }

  instance_refresh_min_healthy_percentage = 50
  instance_refresh_warmup                 = 300
  instance_refresh_auto_rollback          = true

  tags = {
    Owner = "platform"
  }
}
