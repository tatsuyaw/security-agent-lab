output "app_role_arn" {
  description = "Application ロールの ARN(作らない場合は null)"
  value       = var.create_app_role ? aws_iam_role.app[0].arn : null
}

output "service_role_arn" {
  description = "Pentest サービスロールの ARN"
  value       = aws_iam_role.service.arn
}

output "service_role_name" {
  description = "Pentest サービスロールの名前"
  value       = aws_iam_role.service.name
}

output "policy_attachment_ids" {
  description = "IAM の反映待ちの依存に使う ID"
  value       = concat([aws_iam_role_policy.service.id], var.create_app_role ? [aws_iam_role_policy_attachment.app_webapp_policy[0].id] : [])
}
