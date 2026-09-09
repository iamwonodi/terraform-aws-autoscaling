# Terraform AWS Auto Scaling Group

Reusable Terraform module for an AWS Auto Scaling Group, supporting both a single-instance-type launch mode and a mixed-instances mode (multiple instance types, On-Demand/Spot mixing) behind one toggle -- along with the current, non-legacy configurable surface of `aws_autoscaling_group`: termination policies, suspended processes, warm pools, lifecycle hooks, capacity reservations, Availability Zone distribution strategy, and a fully expanded instance refresh configuration.

This module supersedes what were previously two separate repos (`terraform-aws-autoscaling` and `terraform-aws-autoscaling-mixed`). The two shared roughly 90% of their Auto Scaling Group configuration and differed only in how instance types are selected -- that shared surface now lives in one place instead of two.

This module does not create a launch template, an AMI, or an IAM role/instance profile. All three have independent lifecycles and are supplied by dedicated modules instead.

---

# Architecture

```text
Launch-template module
        |
        v
launch_template_id / launch_template_version
        |
        v
        +-----------------------------+
        |     Auto Scaling Group      |
        |                              |
        |  mixed_instances_enabled?    |
        |    true  -> mixed_instances_policy  |
        |    false -> launch_template block    |
        +-----------------------------+
```

---

# Design Principles

* One module, one toggle (`mixed_instances_enabled`), instead of two modules maintaining the same ~90% of shared Auto Scaling Group configuration in parallel.
* The launch template is always caller-supplied (`launch_template_id` / `launch_template_version`), never created here -- see the companion `terraform-aws-launch-template` module.
* Deliberately excluded: `load_balancers` (classic ELB, legacy -- `target_group_arns` and `traffic_source` cover current load balancer types) and `launch_configuration` (deprecated by AWS in favor of launch templates).

---

# Requirements

| Name         | Version              |
| ------------ | ---------------------- |
| Terraform    | `>= 1.6.0`             |
| AWS provider | `>= 6.0.0, < 7.0.0`    |

---

# Usage

## Mixed instances (default)

```hcl
module "launch_template" {
  source = "git::https://github.com/iamwonodi/terraform-aws-launch-template.git?ref=v1.0.0"

  project_name = "myapp"
  environment  = "production"
  service_name = "worker"

  ami_id                     = module.ubuntu_ami.ami_id
  iam_instance_profile_name = module.profile.instance_profile_name
  security_group_ids         = [module.worker_sg.security_group_id]

  # instance_type left null: instance selection happens through
  # mixed_instances_policy below instead.
}

module "autoscaling" {
  source = "git::https://github.com/iamwonodi/terraform-aws-autoscaling.git?ref=v2.0.0"

  project_name = "myapp"
  environment  = "production"
  service_name = "worker"

  launch_template_id      = module.launch_template.id
  launch_template_version = module.launch_template.latest_version

  subnet_ids = module.vpc.private_subnet_ids

  instance_types = ["t3.small", "t3.medium", "t3a.small"]

  target_group_arns = [module.alb_rule.target_group_arn]
}
```

## Single instance type

```hcl
module "launch_template" {
  source = "git::https://github.com/iamwonodi/terraform-aws-launch-template.git?ref=v1.0.0"

  # ...
  instance_type = "t3.medium"  # required in this mode
}

module "autoscaling" {
  source = "git::https://github.com/iamwonodi/terraform-aws-autoscaling.git?ref=v2.0.0"

  # ...
  mixed_instances_enabled = false

  launch_template_id      = module.launch_template.id
  launch_template_version = module.launch_template.latest_version
}
```

See `examples/complete` for a fuller mixed-instances example.

---

# Launch Mode

`mixed_instances_enabled` (default `true`) is the one toggle governing which AWS block this module emits:

| Mode | Block emitted | Instance selection | Requires on the launch template |
| --- | --- | --- | --- |
| Mixed (default) | `mixed_instances_policy` | `instance_types` / `instance_type_weights`, or `instance_requirements` | `instance_type` left unset |
| Simple | `launch_template` | The template's own `instance_type` | `instance_type` set |

---

# Instance Selection (mixed mode)

```hcl
# By instance type, with optional weighting:
instance_types         = ["t3.small", "t3.medium", "t3a.small"]
instance_type_weights  = { "t3.medium" = 2 }

# Or, instead, by attribute (mutually exclusive with the above):
instance_requirements = {
  vcpu_count = { min = 2, max = 4 }
  memory_mib = { min = 4096 }
}
```

`on_demand_base_capacity`, `on_demand_percentage_above_base_capacity`, `spot_allocation_strategy`, `spot_instance_pools`, and `spot_max_price` control the On-Demand/Spot mix. `spot_instance_pools` is only usable when `spot_allocation_strategy = "lowest-price"`, matching AWS's own constraint (enforced here as a precondition).

---

# Termination and Maintenance

```hcl
termination_policies = ["OldestLaunchTemplate", "Default"]
suspended_processes  = []

max_instance_lifetime  = 0      # disabled by default; set 86400-31536000 to force periodic replacement
protect_from_scale_in  = false
```

---

# Warm Pool

```hcl
warm_pool = {
  pool_state         = "Stopped"
  min_size            = 2
  reuse_on_scale_in   = true
}
```

Keeps pre-initialized instances ready outside the group's active capacity, reducing scale-out latency.

---

# Lifecycle Hooks

```hcl
initial_lifecycle_hooks = [
  {
    name                  = "drain-connections"
    lifecycle_transition  = "autoscaling:EC2_INSTANCE_TERMINATING"
    heartbeat_timeout      = 120
  }
]
```

For hooks added after the group already exists, use a standalone `aws_autoscaling_lifecycle_hook` resource instead -- `initial_lifecycle_hooks` only applies at group creation.

---

# Instance Refresh

```hcl
instance_refresh_min_healthy_percentage = 50   # default
instance_refresh_max_healthy_percentage = 100  # default
instance_refresh_warmup                 = 300  # default
instance_refresh_auto_rollback          = true # default
```

Also exposed: `instance_refresh_checkpoint_delay`, `instance_refresh_checkpoint_percentages` (validated ascending, must end in 100), `instance_refresh_skip_matching`, `instance_refresh_scale_in_protected_instances`, `instance_refresh_standby_instances`, `instance_refresh_alarm_arns`, and `instance_refresh_triggers` for additional trigger properties beyond the always-included `launch_template`.

---

# Capacity Reservations

```hcl
capacity_reservation_preference = "capacity-reservations-first"
capacity_reservation_ids        = ["cr-0123456789abcdef0"]
```

`capacity_reservation_ids` and `capacity_reservation_resource_group_arns` are mutually exclusive; either requires `capacity_reservation_preference` to be set (both enforced as preconditions).

---

# Security Considerations

* Compute source and IAM identity are always caller-supplied (`launch_template_id`, and transitively the launch template's own `iam_instance_profile_name`) rather than created here.
* `protect_from_scale_in` and `warm_pool` are both opt-in, so a caller doesn't inherit either behavior by surprise.

---

# Inputs

See `variables.tf` -- every variable carries a `description` and, where relevant, `validation` blocks enforcing the same constraints AWS itself enforces.

# Outputs

| Name        | Description                       |
| ------------ | ------------------------------------ |
| `asg_name`  | Name of the Auto Scaling Group.    |
| `asg_arn`   | ARN of the Auto Scaling Group.     |

---

# Module Structure

```text
terraform-aws-autoscaling/
│
├── main.tf
├── variables.tf
├── locals.tf
├── outputs.tf
├── versions.tf
├── README.md
│
└── examples/
    └── complete/
        ├── main.tf
        ├── variables.tf
        └── outputs.tf
```

---

# Versioning

This module follows Semantic Versioning.

Current release:

```text
v2.0.0
```

`v2.0.0` is a **major** release relative to the previous `terraform-aws-autoscaling` (`v1.x`):

* **Breaking:** the module no longer creates a launch template, IAM role, instance profile, or AMI lookup. `launch_template_id` / `launch_template_version` are now required inputs, sourced from the companion `terraform-aws-launch-template` module (and, transitively, a profile module and an AMI-producing module).
* **Breaking:** `desired_size` renamed to `desired_capacity`, matching AWS's own argument name.
* **Breaking:** `asg_type` replaced by `service_name`, consistent with the naming convention used across the companion `profile` and `launch-template` modules.
* **New:** `mixed_instances_enabled` toggle absorbing what was previously a separate `terraform-aws-autoscaling-mixed` module -- termination policies, suspended processes, warm pools, lifecycle hooks, capacity reservations, Availability Zone distribution, and a fully expanded instance refresh configuration are now available regardless of launch mode.

`terraform-aws-autoscaling-mixed` is retired as a separate repository; its functionality now lives here behind `mixed_instances_enabled = true` (the default).

---

# License

This module is provided for reusable AWS infrastructure deployments and is intended to be consumed as a versioned Terraform module.
