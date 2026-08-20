
################################################################################
# UBUNTU AMI CONFIGURATION
#
# The module uses the latest Ubuntu 24.04 LTS x86_64 AMI published by Canonical.
#
# AMI IDs are resolved dynamically so the module remains portable across AWS
# regions without requiring consumers to maintain region-specific AMI IDs.
################################################################################

locals {
  ami_owner = "099720109477"

  ami_name = "ubuntu/images/hvm-ssd-gp3/ubuntu-noble-24.04-amd64-server-*"

  ################################################################################
  # COMMON RESOURCE TAGS
  ################################################################################

  common_tags = {
    Project     = var.project_name
    Environment = var.environment
    Service     = var.service_name
    ManagedBy   = "Terraform"
  }

  ################################################################################
  # AUTO SCALING GROUP TAGS
  ################################################################################

  asg_tags = merge(
    local.common_tags,
    {
      Name = "${var.project_name}-${var.environment}-${var.service_name}-worker"
    }
  )
}