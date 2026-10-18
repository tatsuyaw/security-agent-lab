# ---------------------------------------------------------------- Application(アカウントに 1 つ)
resource "awscc_securityagent_application" "lab" {
  count = var.create_application ? 1 : 0

  role_arn = module.roles.app_role_arn
  tags     = local.awscc_tags

  depends_on = [time_sleep.iam_propagation]
}

# ---------------------------------------------------------------- Target Domain(DNS_TXT 方式)
# 登録すると TXT レコードの名前とトークンが返るので、そのまま委任ゾーンに Terraform で作る。
# その後の「検証」の実行(Verify)だけは API 操作(コンソールのボタンか CLI)で行う。
resource "awscc_securityagent_target_domain" "app" {
  target_domain_name  = local.net.target_fqdn
  verification_method = "DNS_TXT"
  tags                = local.awscc_tags
}

resource "aws_route53_record" "domain_verification" {
  zone_id = local.dns.zone_id
  name    = awscc_securityagent_target_domain.app.verification_details.dns_txt.dns_record_name
  type    = awscc_securityagent_target_domain.app.verification_details.dns_txt.dns_record_type
  ttl     = 60
  records = [awscc_securityagent_target_domain.app.verification_details.dns_txt.token]
}

# ---------------------------------------------------------------- Agent Space
resource "awscc_securityagent_agent_space" "lab" {
  name        = var.agent_space_name
  description = var.agent_space_description

  aws_resources = {
    iam_roles = [module.roles.service_role_arn]
  }

  target_domain_ids = [awscc_securityagent_target_domain.app.target_domain_id]
  tags              = local.awscc_tags

  depends_on = [awscc_securityagent_application.lab, time_sleep.iam_propagation]
}

# ---------------------------------------------------------------- Pentest
# カスタムヘッダーの値は network-app が生成したもの(WAF の許可ルールと同じ値)
resource "awscc_securityagent_pentest" "vulnapp" {
  count = var.create_pentest ? 1 : 0

  agent_space_id = awscc_securityagent_agent_space.lab.agent_space_id
  title          = var.pentest_title
  service_role   = module.roles.service_role_arn

  assets = {
    endpoints = [{ uri = local.net.target_url }]
  }

  network_traffic_config = {
    custom_headers = [{
      name  = local.net.custom_header_name
      value = local.net.custom_header_value
    }]
  }

  clean_up_strategy         = "BEST_EFFORT_DELETE"
  code_remediation_strategy = var.code_remediation_strategy
}
