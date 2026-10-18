data "aws_caller_identity" "current" {}

data "aws_region" "current" {}

data "terraform_remote_state" "network" {
  backend = "local"

  config = {
    path = var.network_state_path
  }
}

data "terraform_remote_state" "dns" {
  backend = "local"

  config = {
    path = var.dns_zone_state_path
  }
}

locals {
  net = data.terraform_remote_state.network.outputs
  dns = data.terraform_remote_state.dns.outputs

  common_tags = {
    Project   = "security-agent-lab"
    ManagedBy = "terraform"
  }
  awscc_tags = [for k, v in local.common_tags : { key = k, value = v }]
}
