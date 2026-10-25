# Open Policy Agent (OPA) Policies for HCP Terraform

This directory contains enterprise **Policy-as-Code (PaC)** guardrails written in **Rego** for Open Policy Agent (OPA) integration with **HCP Terraform (Terraform Cloud)**.

When integrated into HCP Terraform, these policies evaluate every speculative and production Terraform plan prior to provisioning, enforcing cost optimization, security boundaries, and infrastructure compliance.

---

## 📋 Policy Catalog

| Policy File | Category | Severity | Description |
| :--- | :--- | :--- | :--- |
| [`allowed_instance_types.rego`](./allowed_instance_types.rego) | **Cost Control** | `Mandatory` | Restricts EC2 instances to approved economical types (`t2.micro`, `t3.micro`, `t4g.micro`, etc.) |
| [`enforce_mandatory_tags.rego`](./enforce_mandatory_tags.rego) | **Compliance** | `Mandatory` | Ensures all managed resources possess `Environment` and `Project` tags |
| [`restrict_public_ingress.rego`](./restrict_public_ingress.rego) | **Security** | `Mandatory` | Forbids `0.0.0.0/0` ingress rules on private tiers (only Bastion hosts permitted) |
| [`allowed_regions.rego`](./allowed_regions.rego) | **Governance** | `Mandatory` | Restricts AWS resource provisioning to approved region (`ap-southeast-1` Singapore) |

---

## 🛠️ Step-by-Step HCP Terraform Integration Guide

### Step 1: Navigate to Policy Sets in HCP Terraform
1. Log in to your [HCP Terraform Console](https://app.terraform.io/).
2. Select your Organization (e.g. `achn-testing`).
3. Click **Settings** in the bottom-left sidebar.
4. Under the **Policy Enforcement** section, click **Policy Sets**.
5. Click **"Create a new policy set"** in the top right.

### Step 2: Configure Policy Set Parameters
- **Policy framework**: Select **Open Policy Agent (OPA)**
- **Name**: `aws-vpc-peering-governance`
- **Description**: `Enforces EC2 cost control, security ingress boundaries, and mandatory tagging`
- **Enforcement level**:
  - `Advisory`: Violations generate warnings but do NOT block Terraform Apply *(Recommended for initial dry runs)*
  - `Mandatory`: Violations immediately block Terraform Apply until resolved *(Production standard)*

### Step 3: Connect to Version Control (VCS)
- **VCS Provider**: Select **GitHub**
- **Repository**: Choose `ACHN-dev/VPC-peering-hcp-terraform-vcs`
- **Policy path**: `policies` *(or `./policies`)*
- **OPA query**: `data.terraform.deny`

### Step 4: Define Policy Scope
Choose which workspaces to protect:
- **Option A (All Workspaces)**: Select *"Apply to all workspaces in this organization"*
- **Option B (Selected Workspaces)**: Select specific compute and security workspaces:
  - `vcs-fe-compute`
  - `vcs-be-compute`
  - `vcs-fe-security`
  - `vcs-be-security`
  - `vcs-fe-network`
  - `vcs-be-network`
  - `vcs-peering-ws`

Click **"Connect policy set"** (or **"Save policy set"**).

---

## 🧪 How It Works in VCS CI/CD

```mermaid
flowchart LR
    DEV["Developer / PR"] -->|Git Push| GH["GitHub Repository"]
    GH -->|Webhook Trigger| HCP["HCP Terraform"]
    HCP -->|Step 1| PLAN["Terraform Plan"]
    PLAN -->|Step 2| OPA["OPA Policy Evaluation<br/>(data.terraform.deny)"]
    
    OPA -->|Pass: deny == []| OK["✅ Speculative Plan Passed<br/>Ready to Apply"]
    OPA -->|Fail: deny != []| FAIL["❌ Policy Violation Blocked<br/>Plan Halted"]
```

1. **GitHub Pull Request**: Whenever a PR is opened or updated, HCP Terraform generates a **Speculative Plan**.
2. **Policy Evaluation**: HCP Terraform automatically evaluates `input.plan` against all `.rego` files in the policy set.
3. **Execution Status**:
   - If `data.terraform.deny` is empty `[]`: The check displays **Passed** ✅.
   - If any violation is found: Detailed error messages (with `[COST-001]`, `[TAG-001]`, etc.) appear directly in the GitHub PR check and HCP Terraform UI.
