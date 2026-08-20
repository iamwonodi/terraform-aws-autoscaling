
output "autoscaling_group_name" {
  description = "Name of the example Auto Scaling Group."
  value       = module.autoscaling.autoscaling_group_name
}

output "launch_template_id" {
  description = "ID of the example Launch Template."
  value       = module.autoscaling.launch_template_id
}

output "instance_role_arn" {
  description = "ARN of the EC2 instance IAM role."
  value       = module.autoscaling.instance_role_arn
}

output "ami_id" {
  description = "Ubuntu AMI selected by the module."
  value       = module.autoscaling.ami_id
}