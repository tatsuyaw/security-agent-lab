variable "name" {
  description = "リソース名の接頭辞"
  type        = string
}

variable "account_id" {
  description = "サービスロールの信頼ポリシーで aws:SourceAccount に使うアカウント ID"
  type        = string
}

variable "region" {
  description = "ENI 権限のリソース ARN に使うリージョン"
  type        = string
}

variable "create_app_role" {
  description = "Application ロールを作るか(Application はアカウントに 1 つなので、2 つ目の構成では false)"
  type        = bool
  default     = true
}

variable "agent_subnet_arns" {
  description = "Private VPC 方式でエージェントの ENI を置くサブネットの ARN。空なら ENI 関連の権限を付けない(公開方式)"
  type        = list(string)
  default     = []
}
