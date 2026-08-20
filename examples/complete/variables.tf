
variable "project_name" {
  type        = string
  description = "Project name."
  default     = "example"
}

variable "environment" {
  type        = string
  description = "Deployment environment."
  default     = "development"
}

variable "service_name" {
  type        = string
  description = "Service or worker fleet name."
  default     = "application"
}

variable "vpc_id" {
  type        = string
  description = "Existing VPC ID."
}

variable "security_group_id" {
  type        = string
  description = "Existing security group ID."
}

variable "subnet_ids" {
  type        = list(string)
  description = "Private subnet IDs for the Auto Scaling Group."
}

variable "instance_type" {
  type        = string
  description = "EC2 instance type."
  default     = "t3.micro"
}

variable "min_size" {
  type        = number
  description = "Minimum ASG capacity."
  default     = 1
}

variable "desired_size" {
  type        = number
  description = "Desired ASG capacity."
  default     = 1
}

variable "max_size" {
  type        = number
  description = "Maximum ASG capacity."
  default     = 2
}
