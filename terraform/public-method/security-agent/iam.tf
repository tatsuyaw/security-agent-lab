# Application ロールと Pentest サービスロール(公開方式なので ENI の権限は付けない)
module "roles" {
  source = "../../modules/security-agent-roles"

  name            = var.name
  account_id      = data.aws_caller_identity.current.account_id
  region          = data.aws_region.current.region
  create_app_role = var.create_application
}

resource "time_sleep" "iam_propagation" {
  create_duration = "15s"

  triggers = { policies = join(",", module.roles.policy_attachment_ids) }
}
