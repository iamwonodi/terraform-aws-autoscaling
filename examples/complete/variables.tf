variable "project_name" {
  description = "Name of the project."
  type        = string
  default     = "myapp"
}

variable "environment" {
  description = "Deployment environment."
  type        = string
  default     = "production"
}

variable "service_name" {
  description = "Logical name of the service this Auto Scaling Group belongs to."
  type        = string
  default     = "worker"
}

variable "launch_template_id" {
  description = "ID of the launch template to use. In a real setup, this is typically the id output of a launch-template module."
  type        = string
}

variable "launch_template_version" {
  description = "Launch template version to use. In a real setup, this is typically the latest_version output of a launch-template module."
  type        = string
}

variable "subnet_ids" {
  description = "Subnet IDs where instances are launched."
  type        = list(string)
}

variable "target_group_arn" {
  description = "ALB target group ARN this Auto Scaling Group registers instances with."
  type        = string
}
