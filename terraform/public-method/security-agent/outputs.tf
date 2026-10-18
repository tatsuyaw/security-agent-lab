output "application_id" {
  description = "Security Agent Application の ID"
  value       = var.create_application ? awscc_securityagent_application.lab[0].application_id : null
}

output "application_domain" {
  description = "Security Agent Web アプリケーションのドメイン"
  value       = var.create_application ? awscc_securityagent_application.lab[0].domain : null
}

output "agent_space_id" {
  description = "Agent Space の ID(as-...)"
  value       = awscc_securityagent_agent_space.lab.agent_space_id
}

output "target_domain_id" {
  description = "ターゲットドメインの ID(td-...)"
  value       = awscc_securityagent_target_domain.app.target_domain_id
}

output "target_domain_verification_status" {
  description = "ターゲットドメインの検証状態(Verify 実行前は PENDING)"
  value       = awscc_securityagent_target_domain.app.verification_status
}

output "domain_verification_record" {
  description = "Terraform が作った検証用 TXT レコードの名前"
  value       = aws_route53_record.domain_verification.fqdn
}

output "pentest_id" {
  description = "Pentest の ID(pt-...)"
  value       = var.create_pentest ? awscc_securityagent_pentest.vulnapp[0].pentest_id : null
}

output "service_role_arn" {
  description = "Pentest サービスロールの ARN"
  value       = module.roles.service_role_arn
}
