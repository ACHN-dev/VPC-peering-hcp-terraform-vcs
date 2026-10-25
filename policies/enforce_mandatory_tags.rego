package terraform

import future.keywords.in
import input.plan as tfplan

# ==============================================================================
# POLICY: enforce_mandatory_tags
# Description: Enforces that all major AWS resources include required tags
#              for compliance, ownership, and environment isolation.
# Severity: Mandatory / Advisory
# ==============================================================================

mandatory_tags := ["Environment", "Project"]

taggable_resource_types := [
    "aws_instance",
    "aws_vpc",
    "aws_subnet",
    "aws_security_group",
    "aws_vpc_peering_connection",
    "aws_nat_gateway",
    "aws_internet_gateway"
]

# Identify all taggable resources that are being created or updated
taggable_resources := [res |
    res := tfplan.resource_changes[_]
    res.type in taggable_resource_types
    res.mode == "managed"
    res.change.actions[_] in ["create", "update"]
]

# Deny resources missing any required tags
deny[msg] {
    res := taggable_resources[_]
    provided_tags := object.get(res.change.after, "tags", {})

    missing_tags := [tag |
        tag := mandatory_tags[_]
        not provided_tags[tag]
    ]

    count(missing_tags) > 0

    msg := sprintf(
        "❌ [TAG-001] Resource '%v' (type: '%v') is missing mandatory tag(s): %v. Required tags: %v",
        [res.address, res.type, missing_tags, mandatory_tags]
    )
}
