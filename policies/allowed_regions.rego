package terraform

import future.keywords.in
import input.plan as tfplan

# ==============================================================================
# POLICY: allowed_regions
# Description: Enforces data sovereignty and residency by restricting AWS
#              resource provisioning to authorized AWS regions (ap-northeast-1, ap-southeast-1).
# Severity: Mandatory
# ==============================================================================

allowed_regions := ["ap-northeast-1", "ap-southeast-1"]

# Deny any provider configuration that specifies a non-authorized AWS region
deny[msg] {
    provider_config := tfplan.configuration.provider_config[_]
    provider_config.name == "aws"
    region := object.get(provider_config.expressions.region, "constant_value", "")
    region != ""
    not region in allowed_regions

    msg := sprintf(
        "❌ [GEO-001] AWS Provider configured for disallowed region '%v'. Approved regions: %v",
        [region, allowed_regions]
    )
}
