output "instance_id" {
  description = "対象アプリの EC2 インスタンス ID"
  value       = aws_instance.app.id
}

output "private_ip" {
  description = "対象アプリの EC2 のプライベート IP"
  value       = aws_instance.app.private_ip
}

output "artifacts_bucket" {
  description = "wheel を置いた S3 バケット名"
  value       = aws_s3_bucket.artifacts.bucket
}

output "instance_role_name" {
  description = "EC2 のロール名"
  value       = aws_iam_role.instance.name
}
