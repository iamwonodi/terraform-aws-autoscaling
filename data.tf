
################################################################################
# UBUNTU 24.04 LTS AMI
#
# Resolves the latest Ubuntu 24.04 LTS x86_64 AMI published by Canonical.
################################################################################

data "aws_ami" "ubuntu_linux" {
  most_recent = true

  owners = [local.ami_owner]

  filter {
    name   = "name"
    values = [local.ami_name]
  }

  filter {
    name   = "architecture"
    values = ["x86_64"]
  }

  filter {
    name   = "virtualization-type"
    values = ["hvm"]
  }

  filter {
    name   = "root-device-type"
    values = ["ebs"]
  }

  filter {
    name   = "state"
    values = ["available"]
  }
}