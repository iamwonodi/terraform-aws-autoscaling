
################################################################################
# IAM ROLE FOR EC2 INSTANCES
#
# Provides the IAM identity used by EC2 workloads.
################################################################################

resource "aws_iam_role" "instance_role" {
  name = "${var.project_name}-${var.environment}-${var.service_name}-role"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"

    Statement = [
      {
        Effect = "Allow"

        Principal = {
          Service = "ec2.amazonaws.com"
        }

        Action = "sts:AssumeRole"
      }
    ]
  })

  tags = local.common_tags
}

################################################################################
# AWS SYSTEMS MANAGER ACCESS
################################################################################

resource "aws_iam_role_policy_attachment" "ssm_access" {
  count = var.enable_ssm_access ? 1 : 0

  role       = aws_iam_role.instance_role.name
  policy_arn = "arn:aws:iam::aws:policy/AmazonSSMManagedInstanceCore"
}

################################################################################
# AMAZON ECR READ ACCESS
################################################################################

resource "aws_iam_role_policy_attachment" "ecr_read_access" {
  count = var.enable_ecr_read_access ? 1 : 0

  role       = aws_iam_role.instance_role.name
  policy_arn = "arn:aws:iam::aws:policy/AmazonEC2ContainerRegistryReadOnly"
}

################################################################################
# ADDITIONAL IAM POLICIES
################################################################################

resource "aws_iam_role_policy_attachment" "additional_policies" {
  for_each = toset(var.additional_policy_arns)

  role       = aws_iam_role.instance_role.name
  policy_arn = each.value
}

################################################################################
# EC2 INSTANCE PROFILE
################################################################################

resource "aws_iam_instance_profile" "instance_profile" {
  name = "${var.project_name}-${var.environment}-${var.service_name}-profile"
  role = aws_iam_role.instance_role.name

  tags = local.common_tags
}

################################################################################
# LAUNCH TEMPLATE
#
# Defines the configuration used to launch each Ubuntu EC2 instance.
#
# Application-specific initialization is supplied through user_data by the
# consuming infrastructure.
################################################################################

resource "aws_launch_template" "service_template" {
  name = "${var.project_name}-${var.environment}-${var.service_name}-template"

  image_id      = data.aws_ami.ubuntu_linux.id
  instance_type = var.instance_type

  update_default_version = true

  iam_instance_profile {
    name = aws_iam_instance_profile.instance_profile.name
  }

  network_interfaces {
    associate_public_ip_address = var.associate_public_ip_address
    security_groups             = [var.app_security_group_id]
  }

  user_data = var.user_data != null ? base64encode(var.user_data) : null

  metadata_options {
    http_endpoint               = "enabled"
    http_tokens                 = "required"
    http_put_response_hop_limit = 2
    instance_metadata_tags      = "enabled"
  }

  monitoring {
    enabled = var.enable_detailed_monitoring
  }

  block_device_mappings {
    device_name = var.root_device_name

    ebs {
      volume_size           = var.root_volume_size
      volume_type           = var.root_volume_type
      encrypted             = true
      delete_on_termination = true
    }
  }

  tag_specifications {
    resource_type = "instance"

    tags = merge(
      local.common_tags,
      {
        Name = "${var.project_name}-${var.environment}-${var.service_name}-worker"
      }
    )
  }

  tag_specifications {
    resource_type = "volume"

    tags = merge(
      local.common_tags,
      {
        Name = "${var.project_name}-${var.environment}-${var.service_name}-root"
      }
    )
  }

  tags = merge(
    local.common_tags,
    {
      Name = "${var.project_name}-${var.environment}-${var.service_name}-template"
    }
  )

  lifecycle {
    create_before_destroy = true
  }
}

################################################################################
# AUTO SCALING GROUP
################################################################################

resource "aws_autoscaling_group" "service_asg" {
  name = "${var.project_name}-${var.environment}-${var.service_name}-asg"

  vpc_zone_identifier = var.subnet_ids

  min_size         = var.min_size
  desired_capacity = var.desired_size
  max_size         = var.max_size

  target_group_arns = var.target_group_arns

  health_check_type         = var.health_check_type
  health_check_grace_period = var.health_check_grace_period

  launch_template {
    id      = aws_launch_template.service_template.id
    version = aws_launch_template.service_template.latest_version
  }

  dynamic "tag" {
    for_each = local.asg_tags

    content {
      key                 = tag.key
      value               = tag.value
      propagate_at_launch = true
    }
  }

  lifecycle {
    create_before_destroy = true

    precondition {
      condition     = var.min_size <= var.desired_size && var.desired_size <= var.max_size
      error_message = "Capacity values must satisfy min_size <= desired_size <= max_size."
    }
  }
}