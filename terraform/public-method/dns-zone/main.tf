provider "aws" {
  region              = var.region
  profile             = var.profile
  allowed_account_ids = [var.account_id]

  default_tags {
    tags = { Project = "security-agent-lab", ManagedBy = "terraform" }
  }
}

# 保有ドメインから委任されるサブドメインのパブリックホストゾーン。
# apply 後に出力される 4 つのネームサーバーを、レジストラ側で NS レコードとして登録する(手作業は 1 回だけ)。
# 以降のレコード(ACM の検証、Security Agent の TXT、ALB 向けの A)はすべて Terraform が作る。
resource "aws_route53_zone" "lab" {
  name    = var.zone_name
  comment = "Delegated zone for the AWS Security Agent public lab"
}

variable "account_id" {
  description = "apply 先の AWS アカウント ID(12 桁)"
  type        = string

  validation {
    condition     = can(regex("^[0-9]{12}$", var.account_id))
    error_message = "account_id は 12 桁の数字で指定する。"
  }
}

variable "profile" {
  description = "使用する AWS CLI プロファイル名"
  type        = string
  default     = null
}

variable "region" {
  description = "リージョン(Route 53 はグローバルだが、プロバイダ設定に必要)"
  type        = string
  default     = "ap-northeast-1"
}

variable "zone_name" {
  description = "委任するサブドメイン名(例: lab.example.com)。保有ドメインの配下にする"
  type        = string
}

output "zone_id" {
  description = "ホストゾーン ID"
  value       = aws_route53_zone.lab.zone_id
}

output "zone_name" {
  description = "ホストゾーン名"
  value       = aws_route53_zone.lab.name
}

output "name_servers" {
  description = "レジストラ側に NS レコードとして登録するネームサーバー"
  value       = aws_route53_zone.lab.name_servers
}
