
################################################################################
# PROJECT NAME
################################################################################

variable "project_name" {
  type        = string
  description = "Name of the project that owns the Auto Scaling Group."

  validation {
    condition     = trimspace(var.project_name) != ""
    error_message = "project_name must not be empty."
  }
}

################################################################################
# ENVIRONMENT
################################################################################

variable "environment" {
  type        = string
  description = "Deployment environment such as development, staging, or production."

  validation {
    condition     = trimspace(var.environment) != ""
    error_message = "environment must not be empty."
  }
}

################################################################################
# SERVICE NAME
################################################################################

variable "service_name" {
  type        = string
  description = "Logical name of the service or worker fleet."

  validation {
    condition     = trimspace(var.service_name) != ""
    error_message = "service_name must not be empty."
  }
}

################################################################################
# SECURITY GROUP
################################################################################

variable "app_security_group_id" {
  type        = string
  description = "Security group ID assigned to the EC2 instances."

  validation {
    condition     = can(regex("^sg-[0-9a-fA-F]+$", var.app_security_group_id))
    error_message = "app_security_group_id must be a valid security group ID."
  }
}

################################################################################
# SUBNETS
################################################################################

variable "subnet_ids" {
  type        = list(string)
  description = "Private subnet IDs across which the Auto Scaling Group distributes instances."

  validation {
    condition     = length(var.subnet_ids) > 0
    error_message = "subnet_ids must contain at least one subnet ID."
  }

  validation {
    condition = alltrue([
      for subnet_id in var.subnet_ids :
      can(regex("^subnet-[0-9a-fA-F]+$", subnet_id))
    ])

    error_message = "Every value in subnet_ids must be a valid subnet ID."
  }
}

################################################################################
# TARGET GROUPS
################################################################################

variable "target_group_arns" {
  type        = list(string)
  description = "Optional load balancer target group ARNs associated with the Auto Scaling Group."

  default = []
}

################################################################################
# CAPACITY
################################################################################

variable "min_size" {
  type        = number
  description = "Minimum number of EC2 instances maintained by the Auto Scaling Group."
  default     = 1

  validation {
    condition     = var.min_size >= 0
    error_message = "min_size must be greater than or equal to zero."
  }
}

variable "desired_size" {
  type        = number
  description = "Desired number of EC2 instances maintained by the Auto Scaling Group."
  default     = 1

  validation {
    condition     = var.desired_size >= 0
    error_message = "desired_size must be greater than or equal to zero."
  }
}

variable "max_size" {
  type        = number
  description = "Maximum number of EC2 instances allowed in the Auto Scaling Group."
  default     = 3

  validation {
    condition     = var.max_size >= 1
    error_message = "max_size must be greater than or equal to one."
  }
}

################################################################################
# INSTANCE TYPE
################################################################################

variable "instance_type" {
  type        = string
  description = "EC2 instance type used by the Auto Scaling Group."
  default     = "t3.micro"

  validation {
    condition     = trimspace(var.instance_type) != ""
    error_message = "instance_type must not be empty."
  }
}

################################################################################
# USER DATA
################################################################################

variable "user_data" {
  type        = string
  description = "Optional user-data script executed when an EC2 instance is launched."
  default     = null
}

################################################################################
# NETWORKING
################################################################################

variable "associate_public_ip_address" {
  type        = bool
  description = "Whether launched EC2 instances should receive public IP addresses."
  default     = false
}

################################################################################
# HEALTH CHECK
################################################################################

variable "health_check_type" {
  type        = string
  description = "Auto Scaling health check type. Use EC2 for standalone fleets or ELB for load-balanced fleets."
  default     = "EC2"

  validation {
    condition     = contains(["EC2", "ELB"], var.health_check_type)
    error_message = "health_check_type must be either EC2 or ELB."
  }
}

variable "health_check_grace_period" {
  type        = number
  description = "Seconds Auto Scaling waits before evaluating a newly launched instance."
  default     = 300

  validation {
    condition     = var.health_check_grace_period >= 0
    error_message = "health_check_grace_period must be greater than or equal to zero."
  }
}

################################################################################
# MONITORING
################################################################################

variable "enable_detailed_monitoring" {
  type        = bool
  description = "Whether to enable one-minute EC2 detailed monitoring."
  default     = false
}

################################################################################
# ROOT EBS VOLUME
################################################################################

variable "root_device_name" {
  type        = string
  description = "Root device name used by the Ubuntu AMI."
  default     = "/dev/sda1"
}

variable "root_volume_size" {
  type        = number
  description = "Encrypted root EBS volume size in GiB."
  default     = 20

  validation {
    condition     = var.root_volume_size >= 8
    error_message = "root_volume_size must be at least 8 GiB."
  }
}

variable "root_volume_type" {
  type        = string
  description = "EBS volume type used for the root volume."
  default     = "gp3"

  validation {
    condition     = contains(["gp3", "gp2"], var.root_volume_type)
    error_message = "root_volume_type must be gp3 or gp2."
  }
}

################################################################################
# IAM ACCESS
################################################################################

variable "enable_ssm_access" {
  type        = bool
  description = "Whether to grant the EC2 instances AWS Systems Manager access."
  default     = true
}

variable "enable_ecr_read_access" {
  type        = bool
  description = "Whether to grant the EC2 instances permission to pull private ECR images."
  default     = false
}

variable "additional_policy_arns" {
  type        = list(string)
  description = "Additional IAM policy ARNs attached to the EC2 instance role."
  default     = []
}