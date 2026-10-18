output "target_fqdn" {
  description = "対象アプリのホスト名(Security Agent のターゲットドメイン)"
  value       = local.target_fqdn
}

output "target_url" {
  description = "Pentest のターゲット URL"
  value       = local.target_url
}

output "alb_dns_name" {
  description = "ALB の DNS 名"
  value       = aws_lb.app.dns_name
}

output "waf_mode" {
  description = "現在の WAF ルール順"
  value       = var.waf_mode
}

output "web_acl_arn" {
  description = "Web ACL の ARN"
  value       = aws_wafv2_web_acl.app.arn
}

output "custom_header_name" {
  description = "エージェントに付与するカスタムヘッダー名"
  value       = var.custom_header_name
}

output "custom_header_value" {
  description = "カスタムヘッダーの値(秘密)。security-agent モジュールが remote state 経由で Pentest に設定する"
  value       = random_password.pentest_header.result
  sensitive   = true
}

output "app_instance_id" {
  description = "対象アプリの EC2 インスタンス ID"
  value       = module.vulnapp.instance_id
}

output "flow_log_group_name" {
  description = "対象アプリ用サブネットのフローログのロググループ名"
  value       = var.enable_flow_logs ? module.flow_logs[0].log_group_name : null
}

output "waf_log_group_name" {
  description = "WAF ログのロググループ名"
  value       = aws_cloudwatch_log_group.waf.name
}
