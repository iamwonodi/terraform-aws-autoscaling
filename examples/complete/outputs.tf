output "name" {
  description = "Name of the Auto Scaling Group."
  value       = module.autoscaling.name
}

output "arn" {
  description = "ARN of the Auto Scaling Group."
  value       = module.autoscaling.arn
}
