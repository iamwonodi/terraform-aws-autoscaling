terraform {
  required_version = ">= 1.6.0"

  required_providers {
    aws = {
      source = "hashicorp/aws"
      # >= 6.0.0 comfortably covers every feature this module uses --
      # mixed_instances_policy, instance_refresh (including its expanded
      # preferences), warm_pool, instance_maintenance_policy,
      # availability_zone_distribution, and traffic_source all predate the
      # 6.x provider line.
      version = ">= 6.0.0, < 7.0.0"
    }
  }
}
