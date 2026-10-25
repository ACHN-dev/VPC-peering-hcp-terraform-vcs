####### aws region variable
variable "region" {
  description = "The region where the resources are created."
  default     = "ap-southeast-1"
}


####### data reference to other workspaces in the same organization
variable "be_network_workspace_name" {
  description = "Name of the network workspace to query."
  type        = string
  default     = "vcs-be-network"
}

variable "be_security_workspace_name" {
  description = "Name of the security workspace to query."
  type        = string
  default     = "vcs-be-security"
}

variable "fe_network_workspace_name" {
  description = "Name of the network workspace to query."
  type        = string
  default     = "vcs-fe-network"
}

variable "fe_security_workspace_name" {
  description = "Name of the security workspace to query."
  type        = string
  default     = "vcs-fe-security"
}

variable "organization_name" {
  description = "Name of the HCP Terraform organization with the source workspace"
  type        = string
  default     = "achn-testing"
}