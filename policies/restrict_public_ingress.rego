package terraform

import future.keywords.in
import input.plan as tfplan

# ==============================================================================
# POLICY: restrict_public_ingress
# Description: Prevents open public ingress (0.0.0.0/0) on private subnets and
#              internal workload security groups. Only Bastion/Public tiers
#              are permitted to receive public traffic.
# Severity: Mandatory
# ==============================================================================

# 1. Standalone Security Group Ingress Rules (aws_vpc_security_group_ingress_rule)
standalone_ingress_rules := [rule |
    rule := tfplan.resource_changes[_]
    rule.type == "aws_vpc_security_group_ingress_rule"
    rule.mode == "managed"
    rule.change.actions[_] in ["create", "update"]
]

deny[msg] {
    rule := standalone_ingress_rules[_]
    cidr := object.get(rule.change.after, "cidr_ipv4", "")
    cidr == "0.0.0.0/0"

    # Rule must explicitly belong to a bastion or public security group
    not contains(lower(rule.address), "bastion")
    not contains(lower(rule.address), "pub")

    msg := sprintf(
        "❌ [SEC-001] Ingress rule '%v' exposes 0.0.0.0/0 to private/internal resources. Public ingress (0.0.0.0/0) is only permitted for Bastion hosts.",
        [rule.address]
    )
}

# 2. Inline Security Group Ingress Blocks (aws_security_group)
security_groups := [sg |
    sg := tfplan.resource_changes[_]
    sg.type == "aws_security_group"
    sg.mode == "managed"
    sg.change.actions[_] in ["create", "update"]
]

deny[msg] {
    sg := security_groups[_]
    ingress_block := sg.change.after.ingress[_]
    ingress_block.cidr_blocks[_] == "0.0.0.0/0"

    not contains(lower(sg.address), "bastion")
    not contains(lower(sg.address), "pub")

    msg := sprintf(
        "❌ [SEC-002] Security group '%v' exposes 0.0.0.0/0 on a private resource.",
        [sg.address]
    )
}
