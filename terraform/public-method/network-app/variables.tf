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

variable "dns_zone_state_path" {
  description = "dns-zone モジュールのローカル state のパス"
  type        = string
  default     = "../dns-zone/terraform.tfstate"
}

variable "target_host" {
  description = "対象アプリのホスト名(委任ゾーンの配下)。ACM 証明書とターゲットドメインに使う"
  type        = string
  default     = "pentest"
}

variable "vpc_cidr" {
  description = "検証用 VPC の CIDR"
  type        = string
  default     = "10.1.0.0/16"
}

variable "availability_zones" {
  description = "ALB 用パブリックサブネットを置く AZ(ALB は 2 AZ 以上が必要)。先頭の AZ に対象アプリのプライベートサブネットも置く"
  type        = list(string)
  default     = ["ap-northeast-1a", "ap-northeast-1c"]

  validation {
    condition     = length(var.availability_zones) >= 2
    error_message = "ALB のため AZ は 2 つ以上指定する。"
  }
}

variable "instance_type" {
  description = "対象アプリの EC2 のインスタンスタイプ"
  type        = string
  default     = "t3.micro"
}

variable "wheels_dir" {
  description = "pip download で取得した wheel のディレクトリ"
  type        = string
  default     = "wheels"
}

variable "waf_mode" {
  description = <<-EOT
    WAF のルール順。どちらも Web ACL の既定動作は遮断で、ヘッダーを持たない第三者は通さない。
    agent-first  : ①ヘッダー一致を許可 → ②マネージドルール群。エージェントは WAF の検査を受けずに届く(本番で使う形。1 回目)
    managed-first: ①マネージドルール群(遮断) → ②ヘッダー一致を許可。WAF がエージェントの攻撃をどれだけ止めるかを見る(2 回目)
  EOT
  type        = string
  default     = "agent-first"

  validation {
    condition     = contains(["agent-first", "managed-first"], var.waf_mode)
    error_message = "waf_mode は agent-first か managed-first。"
  }
}

variable "managed_rule_groups" {
  description = "適用する AWS マネージドルールグループ(優先度順)。合計 WCU が 1500 を超えないこと"
  type        = list(string)
  default = [
    "AWSManagedRulesCommonRuleSet",          # 700 WCU
    "AWSManagedRulesKnownBadInputsRuleSet",  # 200 WCU
    "AWSManagedRulesSQLiRuleSet",            # 200 WCU
    "AWSManagedRulesLinuxRuleSet",           # 200 WCU
    "AWSManagedRulesAdminProtectionRuleSet", # 100 WCU
  ]
}

variable "custom_header_name" {
  description = "エージェントの全リクエストに付与し、WAF で許可の根拠にするヘッダー名"
  type        = string
  default     = "X-Pentest-Token"
}

variable "operator_cidrs" {
  description = "操作者が動作確認のためにブラウザから到達してよい送信元 CIDR。空なら操作者も遮断される(curl でヘッダーを付ければ到達できる)"
  type        = list(string)
  default     = []
}

variable "enable_flow_logs" {
  description = "対象アプリ用サブネットの VPC フローログを取るか"
  type        = bool
  default     = true
}

variable "log_retention_days" {
  description = "CloudWatch Logs の保持日数"
  type        = number
  default     = 30
}
