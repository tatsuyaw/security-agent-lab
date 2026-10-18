variable "name" {
  description = "リソース名の接頭辞(ロググループ名にも使う)"
  type        = string
}

variable "subnet_id" {
  description = "フローログを取るサブネット"
  type        = string
}

variable "retention_days" {
  description = "CloudWatch Logs の保持日数"
  type        = number
  default     = 30
}
