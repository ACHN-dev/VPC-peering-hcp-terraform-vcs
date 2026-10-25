terraform {
  required_version = "~>1.17.0"

  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "6.69.1"
    }
  }

  cloud {

    organization = "achn-testing"

    workspaces {
      name = "vcs-peering-ws"
    }
  }
}
