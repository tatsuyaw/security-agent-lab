data "terraform_remote_state" "dns" {
  backend = "local"

  config = {
    path = var.dns_zone_state_path
  }
}

locals {
  zone_id     = data.terraform_remote_state.dns.outputs.zone_id
  zone_name   = data.terraform_remote_state.dns.outputs.zone_name
  target_fqdn = "${var.target_host}.${local.zone_name}"
  target_url  = "https://${local.target_fqdn}"

  # パブリックサブネットは AZ ごと(ALB 用)、プライベートサブネットは先頭 AZ に 1 つ(対象アプリ用)
  public_subnets = { for i, az in var.availability_zones : "public-${i}" => { cidr = cidrsubnet(var.vpc_cidr, 8, i), az = az } }
  app_subnet     = { cidr = cidrsubnet(var.vpc_cidr, 8, 10), az = var.availability_zones[0] }

  common_tags = {
    Project   = "security-agent-lab"
    ManagedBy = "terraform"
  }
}
