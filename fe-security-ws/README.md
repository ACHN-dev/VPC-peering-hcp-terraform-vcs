# Frontend Security Workspace (`fe-security-ws`)

This workspace provisions and manages the **AWS Security Groups and Security Rules** for the Frontend VPC using Terraform and HCP Terraform (Terraform Cloud). It establishes a defense-in-depth security boundary across public and private subnets, ensuring least-privilege traffic flow for the frontend tier and cross-VPC peering communication with the backend infrastructure.

---

## 🏗 Architecture & Traffic Flow Diagram

```mermaid
flowchart TD
    subgraph External["Internet / Admin Network"]
        ADMIN["Admin / Ingress Traffic<br/>0.0.0.0/0 or Client CIDR"]
    end

    subgraph FE_VPC["Frontend VPC (10.0.0.0/16)"]
        subgraph PublicZone["Public Subnet 01"]
            SG_PUB1["fe_public_sg01<br/>frontend-public-security-group01<br/>In: Port 22 SSH, ICMP<br/>Out: All Traffic"]
        end

        subgraph PrivateZone1["Private Subnet 01"]
            SG_PRIV1["fe_private_sg01<br/>frontend-private-security-group01<br/>In: Port 22 SSH, ICMP from SG 01<br/>Out: All Traffic via NAT"]
        end

        subgraph PrivateZone2["Private Subnet 02"]
            SG_PRIV2["fe_private_sg02<br/>frontend-private-security-group02<br/>In: Port 22 SSH, ICMP from SG 01"]
        end

        subgraph PrivateZone3["Private Subnet 03"]
            SG_PRIV3["fe_private_sg03<br/>frontend-private-security-group03<br/>In: Port 22 SSH, ICMP from SG 01"]
        end
    end

    subgraph BE_VPC["Backend VPC (192.168.0.0/16)"]
        BE_SG2["be_private_sg02<br/>Backend Private Subnet 02"]
        BE_SG3["be_private_sg03<br/>Backend Private Subnet 03"]
    end

    ADMIN -->|SSH and ICMP| SG_PUB1
    SG_PUB1 -->|SSH and ICMP| SG_PRIV1
    SG_PRIV1 -->|SSH and ICMP| SG_PRIV2
    SG_PRIV1 -->|SSH and ICMP| SG_PRIV3

    SG_PRIV2 <-->|Peering SSH and ICMP| BE_SG2
    SG_PRIV3 <-->|Peering SSH and ICMP| BE_SG3
```

---

## 🛡️ Security Group Specifications

| Security Group | Resource Name | Associated Tier | Ingress Rules | Egress Rules |
| :--- | :--- | :--- | :--- | :--- |
| **`fe_public_sg01`** | `frontend-public-security-group01` | Public Subnet 01 (Bastion Host) | • **Port 22 (TCP)** from `var.frontend_public_subnet_cidr`<br/>• **ICMP (Echo Request)** from `var.frontend_public_subnet_cidr` | • **All Traffic (`-1`)** to `0.0.0.0/0` |
| **`fe_private_sg01`** | `frontend-private-security-group01` | Private Subnet 01 | • **Port 22 (TCP)** from `fe_public_sg01`<br/>• **ICMP** from `fe_public_sg01` | • **All Traffic (`-1`)** to `0.0.0.0/0` (Egress via NAT) |
| **`fe_private_sg02`** | `frontend-private-security-group02` | Private Subnet 02 (App Tier / Peered) | • **Port 22 (TCP)** from `fe_private_sg01`<br/>• **ICMP** from `fe_private_sg01` | Inter-VPC peering egress managed in `vpc-peering-intra-region-ws` |
| **`fe_private_sg03`** | `frontend-private-security-group03` | Private Subnet 03 (App Tier / Peered) | • **Port 22 (TCP)** from `fe_private_sg01`<br/>• **ICMP** from `fe_private_sg01` | Inter-VPC peering egress managed in `vpc-peering-intra-region-ws` |

> **Best Practice Note**: This workspace utilizes `aws_vpc_security_group_ingress_rule` and `aws_vpc_security_group_egress_rule` standalone resources rather than inline security group arguments. This avoids circular dependencies, state locks, and enables clean cross-workspace rule composition across VPC peering connections.

---

## 📦 Provisioned Resources

- **`aws_security_group.fe_public_sg01`**: Security group for public instances (Bastion host) attached to `frontend_vpc_id`.
  - `aws_vpc_security_group_ingress_rule.fe_public_sg01_allow_ssh`: Ingress SSH from allowed CIDR.
  - `aws_vpc_security_group_ingress_rule.fe_public_sg01_allow_icmp`: Ingress ICMP (ping) from allowed CIDR.
  - `aws_vpc_security_group_egress_rule.fe_public_sg01_allow_all_traffic`: Unrestricted outbound egress.
- **`aws_security_group.fe_private_sg01`**: Security group for private tier 01 instances.
  - `aws_vpc_security_group_ingress_rule.fe_private_sg01_allow_ssh`: Ingress SSH strictly from `fe_public_sg01`.
  - `aws_vpc_security_group_ingress_rule.fe_private_sg01_allow_icmp`: Ingress ICMP strictly from `fe_public_sg01`.
  - `aws_vpc_security_group_egress_rule.fe_private_sg01_allow_all_traffic`: Unrestricted egress for package downloads via NAT Gateway.
- **`aws_security_group.fe_private_sg02`**: Security group for private tier 02 instances.
  - `aws_vpc_security_group_ingress_rule.fe_private_sg02_allow_ssh_from_fe_private_sg01`: Ingress SSH from `fe_private_sg01`.
  - `aws_vpc_security_group_ingress_rule.fe_private_sg02_allow_icmp_from_fe_private_sg01`: Ingress ICMP from `fe_private_sg01`.
- **`aws_security_group.fe_private_sg03`**: Security group for private tier 03 instances.
  - `aws_vpc_security_group_ingress_rule.fe_private_sg03_allow_ssh_from_fe_private_sg01`: Ingress SSH from `fe_private_sg01`.
  - `aws_vpc_security_group_ingress_rule.fe_private_sg03_allow_icmp_from_fe_private_sg01`: Ingress ICMP from `fe_private_sg01`.

---

## 🔗 Workspace Dependencies

```mermaid
flowchart LR
    FE_NET["fe-network-ws<br/>Frontend VPC"] -->|frontend_vpc_id| FE_SEC["fe-security-ws<br/>Security Groups"]
    FE_SEC -->|Security Group IDs| FE_COMP["fe-compute-ws<br/>EC2 Instances"]
    FE_SEC -->|Peering SG IDs| VPC_PEER["vpc-peering-intra-region-ws<br/>Peering Security Rules"]
```

1. **Upstream**: Reads `frontend_vpc_id` from `fe-network-ws` using `tfe_outputs`.
2. **Downstream**:
   - `fe-compute-ws`: Attaches the security groups to EC2 instances in each respective subnet.
   - `vpc-peering-intra-region-ws`: Attaches inter-VPC ingress and egress rules linking Frontend and Backend private security groups.

---

## ⚙️ HCP Terraform Configuration

When configuring this workspace in HCP Terraform:

- **Workspace Name**: `fe-security-ws` (or `vcs-fe-security`)
- **Terraform Working Directory**: `fe-security-ws`
- **VCS Branch**: `main`
- **Automatic run triggering**: `Only trigger runs when files in specified paths change`
  - **Pattern**: `fe-security-ws/**/*`
- **Remote State Sharing**:
  - Navigate to **Settings** -> **Remote state sharing**.
  - Enable **"Share with all workspaces in this organization"** (or selectively share with `fe-compute-ws` and `vpc-peering-intra-region-ws`).

---

## 📥 Inputs (Variables)

| Variable Name | Type | Default | Description |
| :--- | :--- | :--- | :--- |
| `region` | `string` | `"ap-southeast-1"` | AWS Region to deploy security resources |
| `frontend_prefix` | `string` | `"frontend"` | Prefix used for security group naming and tags |
| `frontend_environment` | `string` | `"dev"` | Environment name (e.g. `dev`, `prod`) |
| `organization_name` | `string` | `"ky-vcs-org"` | HCP Terraform organization hosting the upstream workspace |
| `fe_network_workspace_name` | `string` | `"fe-network-ws"` | Name of the upstream network workspace to fetch `frontend_vpc_id` |
| `frontend_public_subnet_cidr` | `string` | `"0.0.0.0/0"` | CIDR block permitted for public SSH / ICMP ingress to Bastion Host |

---

## 📤 Outputs

These outputs are consumed downstream via `data.tfe_outputs.fe_security_source_workspace`:

| Output Name | Description | Consumed By |
| :--- | :--- | :--- |
| `frontend_public_sg01_id` | ID of `fe_public_sg01` (Public Bastion SG) | `fe-compute-ws` (Public Bastion EC2) |
| `frontend_private_sg01_id` | ID of `fe_private_sg01` (Private Tier 01 SG) | `fe-compute-ws` (Private Subnet 01 EC2) |
| `frontend_private_sg02_id` | ID of `fe_private_sg02` (Private Tier 02 SG) | `fe-compute-ws`, `vpc-peering-intra-region-ws` |
| `frontend_private_sg03_id` | ID of `fe_private_sg03` (Private Tier 03 SG) | `fe-compute-ws`, `vpc-peering-intra-region-ws` |

---

## 🚀 Deployment Instructions

### Option 1: Via HCP Terraform (Recommended)

1. Commit and push your changes to `main`:
   ```bash
   git add fe-security-ws/
   git commit -m "feat: add fe-security documentation"
   git push origin main
   ```
2. HCP Terraform automatically triggers a Plan and Apply based on the VCS trigger pattern `fe-security-ws/**/*`.

### Option 2: Via Local CLI

```bash
cd fe-security-ws
terraform init
terraform plan
terraform apply
```
