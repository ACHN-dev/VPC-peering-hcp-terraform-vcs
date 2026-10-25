package terraform

import future.keywords.in
import input.plan as tfplan

# ==============================================================================
# POLICY: allowed_instance_types
# Description: Restricts EC2 instances to approved budget-friendly instance types.
# Severity: Mandatory / Hard-Mandatory
# ==============================================================================

allowed_instance_types := [
    "t2.nano", "t2.micro", "t2.small",
    "t3.nano", "t3.micro", "t3.small",
    "t4g.nano", "t4g.micro", "t4g.small"
]

# Identify all created or updated EC2 instances
ec2_instances := [res |
    res := tfplan.resource_changes[_]
    res.type == "aws_instance"
    res.mode == "managed"
    res.change.actions[_] in ["create", "update"]
]

# Deny instances that use unapproved instance types
deny[msg] {
    instance := ec2_instances[_]
    instance_type := instance.change.after.instance_type
    not instance_type in allowed_instance_types

    msg := sprintf(
        "❌ [COST-001] Disallowed EC2 instance type '%v' configured on '%v'. Allowed types are: %v",
        [instance_type, instance.address, allowed_instance_types]
    )
}
