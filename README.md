
# Terraform AWS Auto Scaling Module

A reusable Terraform module for deploying a generic Ubuntu-based Amazon EC2
Auto Scaling Group using an EC2 Launch Template.

The module is designed to provide a consistent foundation for application,
worker, backend, and other EC2-based workloads without embedding
application-specific configuration.

## Features

- Ubuntu 24.04 LTS x86_64 AMI discovery
- EC2 Launch Template
- On-Demand EC2 Auto Scaling Group
- Multi-AZ subnet support
- Security group integration
- Optional Application Load Balancer or Network Load Balancer target groups
- Optional AWS Systems Manager access
- Optional Amazon ECR read access
- Additional IAM policy support
- IMDSv2 enforcement
- Encrypted root EBS volume
- Configurable instance type
- Configurable capacity
- Optional detailed monitoring
- Generic user-data support
- Consistent resource tagging

## Architecture

The module creates:

1. IAM role
2. IAM policy attachments
3. IAM instance profile
4. EC2 Launch Template
5. Auto Scaling Group

The module dynamically resolves the latest Ubuntu 24.04 LTS AMI published by
Canonical in the AWS region configured by the consuming Terraform project.

## Usage

```hcl
module "application_autoscaling" {
  source = "git::https://github.com/iamwonodi/terraform-aws-autoscaling.git?ref=v1.0.0"

  project_name = var.project_name
  environment  = local.environment
  service_name = "application"

  app_security_group_id = module.private_sg.security_group_id
  subnet_ids            = module.vpc_base.private_subnet_ids

  instance_type = "t3.medium"

  min_size     = 2
  desired_size = 4
  max_size     = 6

  enable_ssm_access      = true
  enable_ecr_read_access = true

  user_data = local.user_data
}
````

## Application Initialization

The module does not contain application-specific startup logic.

Consumers can provide their own user-data script through:

```hcl
user_data = local.user_data
```

This keeps infrastructure provisioning separate from application deployment.

For example, Core Infrastructure can provide a generic EC2 bootstrap script
that installs Docker, AWS CLI, application deployment tooling, and other
required host dependencies.

## Target Groups

Target groups are optional.

For a workload behind an Application Load Balancer or Network Load Balancer:

```hcl
target_group_arns = [
  module.application_target_group.target_group_arn
]
```

For a standalone worker fleet:

```hcl
target_group_arns = []
```

## IAM Permissions

Systems Manager access can be enabled with:

```hcl
enable_ssm_access = true
```

ECR read access can be enabled with:

```hcl
enable_ecr_read_access = true
```

Additional policies can be supplied when required:

```hcl
additional_policy_arns = [
  "arn:aws:iam::aws:policy/AmazonS3ReadOnlyAccess"
]
```

Only permissions required by the workload should be enabled.

## Security

The module:

* uses private instances by default
* disables public IP assignment by default
* requires IMDSv2
* encrypts the root EBS volume
* uses an EC2 IAM role instead of static AWS credentials
* supports Systems Manager to avoid requiring SSH access

## Capacity

The following relationship must always be satisfied:

```text
min_size <= desired_size <= max_size
```

The module enforces this relationship through an Auto Scaling Group
precondition.

## Requirements

* Terraform >= 1.6.0
* AWS provider >= 6.0 and < 7.0
* An AWS VPC
* At least one subnet
* An EC2-compatible security group

## Inputs

| Name                        | Type         | Default     | Description                          |
| --------------------------- | ------------ | ----------- | ------------------------------------ |
| project_name                | string       | n/a         | Project name                         |
| environment                 | string       | n/a         | Deployment environment               |
| service_name                | string       | n/a         | Service or worker fleet name         |
| app_security_group_id       | string       | n/a         | EC2 security group ID                |
| subnet_ids                  | list(string) | n/a         | Subnets used by the ASG              |
| target_group_arns           | list(string) | `[]`        | Optional load balancer target groups |
| instance_type               | string       | `t3.micro`  | EC2 instance type                    |
| min_size                    | number       | `1`         | Minimum ASG capacity                 |
| desired_size                | number       | `1`         | Desired ASG capacity                 |
| max_size                    | number       | `3`         | Maximum ASG capacity                 |
| user_data                   | string       | `null`      | Optional EC2 user-data               |
| associate_public_ip_address | bool         | `false`     | Public IP assignment                 |
| health_check_type           | string       | `EC2`       | ASG health check type                |
| health_check_grace_period   | number       | `300`       | Health check grace period            |
| enable_detailed_monitoring  | bool         | `false`     | Enable detailed monitoring           |
| root_device_name            | string       | `/dev/sda1` | Ubuntu root device                   |
| root_volume_size            | number       | `20`        | Root EBS size in GiB                 |
| root_volume_type            | string       | `gp3`       | Root EBS volume type                 |
| enable_ssm_access           | bool         | `true`      | Enable SSM                           |
| enable_ecr_read_access      | bool         | `false`     | Enable ECR read access               |
| additional_policy_arns      | list(string) | `[]`        | Additional IAM policies              |

## Outputs

* `autoscaling_group_id`
* `autoscaling_group_name`
* `autoscaling_group_arn`
* `launch_template_id`
* `launch_template_name`
* `launch_template_latest_version`
* `instance_role_name`
* `instance_role_arn`
* `instance_profile_name`
* `ami_id`
* `ami_name`

## Example

A complete example is available under:

```text
examples/complete/
```

## License

This project is licensed under the MIT License.
