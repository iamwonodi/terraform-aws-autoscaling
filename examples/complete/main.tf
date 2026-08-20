
################################################################################
# ON-DEMAND AUTO SCALING GROUP
################################################################################

module "autoscaling" {
  source = "../.."

  project_name = var.project_name
  environment  = var.environment
  service_name = var.service_name

  app_security_group_id = var.security_group_id
  subnet_ids            = var.subnet_ids

  instance_type = var.instance_type

  min_size     = var.min_size
  desired_size = var.desired_size
  max_size     = var.max_size

  enable_ssm_access      = true
  enable_ecr_read_access = true

  user_data = <<-EOF
    #!/bin/bash

    echo "EC2 worker initialized."
  EOF
}