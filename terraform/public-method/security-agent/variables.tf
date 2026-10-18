# ---------------------------------------------------------------- 必須
variable "account_id" {
  description = "apply 先の AWS アカウント ID(12 桁)"
  type        = string

  validation {
    condition     = can(regex("^[0-9]{12}$", var.account_id))
    error_message = "account_id は 12 桁の数字で指定する。"
  }
}

# ---------------------------------------------------------------- オプション
variable "profile" {
  description = "使用する AWS CLI プロファイル名"
  type        = string
  default     = null
}

variable "region" {
  description = "リージョン"
  type        = string
  default     = "ap-northeast-1"
}

variable "name" {
  description = "リソース名の接頭辞"
  type        = string
  default     = "sa-pub"
}

variable "network_state_path" {
  description = "public/network-app のローカル state のパス"
  type        = string
  default     = "../network-app/terraform.tfstate"
}

variable "dns_zone_state_path" {
  description = "public/dns-zone のローカル state のパス"
  type        = string
  default     = "../dns-zone/terraform.tfstate"
}

variable "create_application" {
  description = "Security Agent の Application(アカウントに 1 つ)と Application ロールを作るか。公開版を先に作るので既定 true"
  type        = bool
  default     = true
}

variable "agent_space_name" {
  description = "Agent Space の名前"
  type        = string
  default     = "sa-pub-vulnapp"
}

variable "agent_space_description" {
  description = "Agent Space の説明"
  type        = string
  default     = "Public pentest lab behind ALB + WAF against an intentionally vulnerable Flask app"
}

variable "pentest_title" {
  description = "Pentest のタイトル(英数字・ハイフン・アンダースコア、100 文字以内)"
  type        = string
  default     = "vulnapp-public-waf"

  validation {
    condition     = can(regex("^[A-Za-z0-9_-]{1,100}$", var.pentest_title))
    error_message = "pentest_title は英数字・ハイフン・アンダースコアで 100 文字以内。"
  }
}

variable "create_pentest" {
  description = "Pentest を Terraform で作るか(Cloud Control 経由の作成がタイムアウトする報告があるため、false で Web アプリ作成に逃げられる)"
  type        = bool
  default     = true
}

variable "code_remediation_strategy" {
  description = "コード修正 PR の自動作成(AUTOMATIC / DISABLED)"
  type        = string
  default     = "DISABLED"

  validation {
    condition     = contains(["AUTOMATIC", "DISABLED"], var.code_remediation_strategy)
    error_message = "AUTOMATIC か DISABLED。"
  }
}
