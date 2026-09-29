# The instance refresh triggers, with AWS mocked. Changes to launch_template and
# mixed_instances_policy always start a refresh, so the provider warns when
# either is listed as a trigger ("'launch_template' always triggers an
# instance refresh and can be removed"). They must never be sent.

mock_provider "aws" {}

variables {
  project_name       = "myapp"
  environment        = "development"
  service_name       = "worker"
  launch_template_id = "lt-0123456789abcdef0"
  subnet_ids         = ["subnet-0123456789abcdef0"]
}

run "no_triggers_by_default" {
  command = plan

  assert {
    condition     = aws_autoscaling_group.this.instance_refresh[0].triggers == null || length(aws_autoscaling_group.this.instance_refresh[0].triggers) == 0
    error_message = "with no extra triggers, none are sent: launch template changes refresh the group anyway"
  }
}

run "the_properties_that_always_trigger_are_dropped" {
  command = plan

  variables {
    instance_refresh_triggers = ["launch_template", "tag", "mixed_instances_policy", "tag"]
  }

  assert {
    condition     = toset(aws_autoscaling_group.this.instance_refresh[0].triggers) == toset(["tag"])
    error_message = "launch_template and mixed_instances_policy are dropped, duplicates removed, the rest kept"
  }
}
