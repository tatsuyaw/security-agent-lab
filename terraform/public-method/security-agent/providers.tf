provider "aws" {
  region              = var.region
  profile             = var.profile
  allowed_account_ids = [var.account_id]

  default_tags {
    tags = local.common_tags
  }
}

provider "awscc" {
  region  = var.region
  profile = var.profile
}
