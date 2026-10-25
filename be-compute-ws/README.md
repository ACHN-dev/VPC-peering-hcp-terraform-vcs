# Backend Compute Workspace (`be-compute-ws`)

This workspace provisions and manages the **EC2 Compute Instances, Elastic IPs (EIP), and SSH Key Pairs** within the Backend VPC (`192.168.0.0/16`) in the Singapore region (`ap-southeast-1`) using Terraform and HCP Terraform (Terraform Cloud).

It establishes an isolated backend compute environment featuring a Bastion host in the public subnet and secure private Ubuntu workload/database instances with intra-VPC connectivity and cross-VPC peering communication with the frontend infrastructure.

---

## 🏗 Architecture & Compute Topology

```mermaid
flowchart TD
    subgraph External["Internet / Admin"]
        ADMIN["Administrator / SSH Client"]
    end

    subgraph BE_VPC["Backend VPC (192.168.0.0/16)"]
        subgraph PublicSubnet01["Public Subnet 01 (192.168.1.0/24)"]
            BASTION["backend_public_instance01<br/>Amazon Linux 2023<br/>Attached EIP / Bastion Host"]
        end

        subgraph PrivateSubnet01["Private Subnet 01 (192.168.253.0/24)"]
            PRIV1["backend_private_instance01<br/>Ubuntu 24.04 LTS<br/>Internal App Node / NAT Egress"]
        end

        subgraph PrivateSubnet02["Private Subnet 02 (192.168.254.0/24)"]
            PRIV2["backend_private_instance02<br/>Ubuntu 24.04 LTS<br/>Peered App Node"]
        end

        subgraph PrivateSubnet03["Private Subnet 03 (192.168.255.0/24)"]
            PRIV3["backend_private_instance03<br/>Ubuntu 24.04 LTS<br/>Peered App Node"]
        end
    end

    subgraph FE_VPC["Frontend VPC (via Peering)"]
        FE_PRIV2["frontend_private_instance02<br/>Frontend Subnet 02"]
        FE_PRIV3["frontend_private_instance03<br/>Frontend Subnet 03"]
    end

    ADMIN -->|Public SSH via EIP| BASTION
    BASTION -->|Private SSH| PRIV1
    BASTION -->|Private SSH| PRIV2
    BASTION -->|Private SSH| PRIV3

    PRIV2 <-->|Peering Traffic| FE_PRIV2
    PRIV3 <-->|Peering Traffic| FE_PRIV3
```

---

## 💻 Compute Instance Specifications

| Instance Resource | Subnet | OS / AMI | Security Group | Public Access | Role & Description |
| :--- | :--- | :--- | :--- | :--- | :--- |
| **`backend_public_instance01`** | `Public Subnet 01`<br/>(`192.168.1.0/24`) | **Amazon Linux 2023**<br/>(Kernel 6.18, x86_64) | `backend_public_sg01` | **Yes**<br/>(Static Elastic IP) | **Bastion Host**: Public entry point for jump-box SSH access into backend private subnets. |
| **`backend_private_instance01`** | `Private Subnet 01`<br/>(`192.168.253.0/24`) | **Ubuntu 24.04 LTS**<br/>(Noble Numbat, amd64) | `backend_private_sg01` | **No** (Private only) | **Internal Workload Node**: Accessible via Bastion SSH; outbound internet egress via Backend NAT Gateway. |
| **`backend_private_instance02`** | `Private Subnet 02`<br/>(`192.168.254.0/24`) | **Ubuntu 24.04 LTS**<br/>(Noble Numbat, amd64) | `backend_private_sg02` | **No** (Private only) | **Peered Workload Node**: Bi-directionally connected to Frontend Private Subnet 02 via VPC peering. |
| **`backend_private_instance03`** | `Private Subnet 03`<br/>(`192.168.255.0/24`) | **Ubuntu 24.04 LTS**<br/>(Noble Numbat, amd64) | `backend_private_sg03` | **No** (Private only) | **Peered Workload Node**: Bi-directionally connected to Frontend Private Subnet 03 via VPC peering. |

---

## 🔑 SSH Key Pair Management

- **Resource**: `tls_private_key.be_keypair` creates an **ED25519** keypair.
- **AWS Key Pair**: `aws_key_pair.be_keypair` (`backend-ssh-key.pem`) deployed to all backend EC2 instances.
- **Accessing Private Key**:
  The private key is exposed as a sensitive Terraform output:
  ```bash
  terraform output -raw be_instances_private_key > be-sshkey.pem
  chmod 400 be-sshkey.pem
  ```
- **Connecting via Bastion**:
  ```bash
  # SSH to Bastion Host
  ssh -i be-sshkey.pem ec2-user@<BACKEND_PUBLIC_IP>

  # SSH to Private Instance from Bastion
  ssh -i be-sshkey.pem ubuntu@<BACKEND_PRIVATE_IP>

  # Or using SSH ProxyJump:
  ssh -i be-sshkey.pem -J ec2-user@<BACKEND_PUBLIC_IP> ubuntu@<BACKEND_PRIVATE_IP>
  ```

---

## 📦 Provisioned Resources

- **`tls_private_key.be_keypair`**: Generates high-security ED25519 SSH private key.
- **`aws_key_pair.be_keypair`**: Registers public key on AWS as `${var.backend_prefix}-ssh-key.pem`.
- **`aws_eip.backend_public_instance_eip`**: Allocates Elastic IP for the Backend Bastion instance.
- **`aws_eip_association.be_public_instance_eip_assoc`**: Associates the Elastic IP with `backend_public_instance01`.
- **`aws_instance.backend_public_instance01`**: Amazon Linux 2023 EC2 instance deployed in Public Subnet 01.
- **`aws_instance.backend_private_instance01`**: Ubuntu 24.04 LTS instance deployed in Private Subnet 01.
- **`aws_instance.backend_private_instance02`**: Ubuntu 24.04 LTS instance deployed in Private Subnet 02 (peering target).
- **`aws_instance.backend_private_instance03`**: Ubuntu 24.04 LTS instance deployed in Private Subnet 03 (peering target).

---

## 🔗 Workspace Dependencies

```mermaid
flowchart LR
    BE_NET["be-network-ws<br/>Subnet IDs"] -->|Subnet IDs| BE_COMP["be-compute-ws<br/>EC2 Instances"]
    BE_SEC["be-security-ws<br/>Security Group IDs"] -->|Security Group IDs| BE_COMP
```

This workspace queries outputs from two upstream workspaces:

1. **`be-network-ws`** (via `data.tfe_outputs.be_network_source_workspace`):
   - `backend_public_subnet01_id`
   - `backend_private_subnet01_id`
   - `backend_private_subnet02_id`
   - `backend_private_subnet03_id`
2. **`be-security-ws`** (via `data.tfe_outputs.be_security_source_workspace`):
   - `backend_public_sg01_id`
   - `backend_private_sg01_id`
   - `backend_private_sg02_id`
   - `backend_private_sg03_id`

---

## ⚙️ HCP Terraform Configuration

When configuring this workspace in HCP Terraform:

- **Workspace Name**: `be-compute-ws` (or `vcs-be-compute`)
- **Terraform Working Directory**: `be-compute-ws`
- **VCS Branch**: `main`
- **Automatic run triggering**: `Only trigger runs when files in specified paths change`
  - **Pattern**: `be-compute-ws/**/*`
- **Upstream Workspace Permissions**:
  - Ensure `be-network-ws` and `be-security-ws` have **Remote State Sharing** enabled with this workspace.

---

## 📥 Inputs (Variables)

| Variable Name | Type | Default | Description |
| :--- | :--- | :--- | :--- |
| `region` | `string` | `"ap-southeast-1"` | AWS Region to deploy compute instances |
| `backend_prefix` | `string` | `"backend"` | Prefix for naming and tagging resources |
| `backend_environment` | `string` | `"dev"` | Environment name (e.g. `dev`, `prod`) |
| `be_instance_type` | `string` | `"t3.micro"` | AWS EC2 instance type |
| `organization_name` | `string` | `"achn-testing"` | HCP Terraform organization hosting upstream workspaces |
| `be_network_workspace_name` | `string` | `"vcs-be-network"` | Name of the backend network workspace to query |
| `be_security_workspace_name` | `string` | `"vcs-be-security"` | Name of the backend security workspace to query |
| `be_placeholder` | `string` | `"placedog.net"` | Image placeholder service URL for web template |
| `placeholder_id` | `string` | `"2"` | Placeholder image ID |
| `width` | `string` | `"600"` | Placeholder image width in pixels |
| `height` | `string` | `"400"` | Placeholder image height in pixels |

---

## 📤 Outputs

| Output Name | Description | Sensitive |
| :--- | :--- | :--- |
| `be_instances_private_key` | Private key for SSH access (ED25519) | **Yes** |
| `backend_public_instance_public_ip` | Elastic IP assigned to Bastion instance | No |
| `backend_public_instance_public_dns` | Public DNS hostname of Bastion instance | No |
| `backend_private_instance01_private_ip` | Private IPv4 of Private Instance 01 | No |
| `backend_private_instance02_private_ip` | Private IPv4 of Private Instance 02 | No |
| `backend_private_instance03_private_ip` | Private IPv4 of Private Instance 03 | No |

---

## 🚀 Deployment Instructions

### Deployment Prerequisite

Ensure the following upstream workspaces have been applied in order:
1. `be-network-ws`
2. `be-security-ws`
3. `vpc-peering-intra-region-ws` (recommended before starting workloads)

### Option 1: Via HCP Terraform (Recommended)

1. Commit and push your changes to `main`:
   ```bash
   git add be-compute-ws/
   git commit -m "feat: add be-compute documentation"
   git push origin main
   ```
2. HCP Terraform automatically triggers a Plan and Apply based on the VCS trigger pattern `be-compute-ws/**/*`.

### Option 2: Via Local CLI

```bash
cd be-compute-ws
terraform init
terraform plan
terraform apply
```
