
################################################################################
# AUTO SCALING GROUP
################################################################################

output "autoscaling_group_id" {
  description = "ID of the Auto Scaling Group."
  value       = aws_autoscaling_group.service_asg.id
}

output "autoscaling_group_name" {
  description = "Name of the Auto Scaling Group."
  value       = aws_autoscaling_group.service_asg.name
}

output "autoscaling_group_arn" {
  description = "ARN of the Auto Scaling Group."
  value       = aws_autoscaling_group.service_asg.arn
}

################################################################################
# LAUNCH TEMPLATE
################################################################################

output "launch_template_id" {
  description = "ID of the EC2 Launch Template."
  value       = aws_launch_template.service_template.id
}

output "launch_template_name" {
  description = "Name of the EC2 Launch Template."
  value       = aws_launch_template.service_template.name
}

output "launch_template_latest_version" {
  description = "Latest version of the EC2 Launch Template."
  value       = aws_launch_template.service_template.latest_version
}

################################################################################
# IAM
################################################################################

output "instance_role_name" {
  description = "Name of the IAM role assigned to the EC2 instances."
  value       = aws_iam_role.instance_role.name
}

output "instance_role_arn" {
  description = "ARN of the IAM role assigned to the EC2 instances."
  value       = aws_iam_role.instance_role.arn
}

output "instance_profile_name" {
  description = "Name of the IAM instance profile assigned to the EC2 instances."
  value       = aws_iam_instance_profile.instance_profile.name
}

################################################################################
# AMI
################################################################################

output "ami_id" {
  description = "Ubuntu AMI ID selected for the Launch Template."
  value       = data.aws_ami.ubuntu_linux.id
}

output "ami_name" {
  description = "Ubuntu AMI name selected for the Launch Template."
  value       = data.aws_ami.ubuntu_linux.name
}