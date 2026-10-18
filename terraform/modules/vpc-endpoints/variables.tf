variable "name" {
  description = "リソース名の接頭辞"
  type        = string
}

variable "vpc_id" {
  description = "VPC ID"
  type        = string
}

variable "vpc_cidr" {
  description = "インターフェースエンドポイントへの HTTPS を許可する範囲"
  type        = string
}

variable "region" {
  description = "リージョン(サービス名に使う)"
  type        = string
}

variable "route_table_ids" {
  description = "S3 ゲートウェイエンドポイントを関連付けるルートテーブル"
  type        = list(string)
}

variable "subnet_ids" {
  description = "SSM 用インターフェースエンドポイントを置くサブネット"
  type        = list(string)
}
