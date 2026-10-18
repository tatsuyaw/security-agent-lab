output "s3_endpoint_id" {
  description = "S3 ゲートウェイエンドポイントの ID"
  value       = aws_vpc_endpoint.s3.id
}

output "ssm_endpoint_ids" {
  description = "SSM 用インターフェースエンドポイントの ID"
  value       = { for k, v in aws_vpc_endpoint.ssm : k => v.id }
}

output "all_endpoint_ids" {
  description = "全エンドポイントの ID(依存関係の表明用)"
  value       = concat([aws_vpc_endpoint.s3.id], [for v in aws_vpc_endpoint.ssm : v.id])
}
