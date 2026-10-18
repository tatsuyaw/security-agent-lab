# ---------------------------------------------------------------- 必須
variable "name" {
  description = "リソース名の接頭辞"
  type        = string
}

variable "account_id" {
  description = "S3 バケット名を一意にするためのアカウント ID"
  type        = string
}

variable "subnet_id" {
  description = "対象アプリの EC2 を置くプライベートサブネット"
  type        = string
}

variable "security_group_ids" {
  description = "EC2 に付けるセキュリティグループ"
  type        = list(string)
}

variable "app_py_path" {
  description = "対象アプリ(app.py)のパス。user_data に埋め込む"
  type        = string
}

variable "wheels_dir" {
  description = "pip download で取得した wheel のディレクトリ。S3 にアップロードし、EC2 はオフラインで導入する"
  type        = string
}

# ---------------------------------------------------------------- オプション
variable "instance_type" {
  description = "インスタンスタイプ。無料利用枠対象であることを precondition で確認する"
  type        = string
  default     = "t3.micro"
}

variable "verify_token" {
  description = "HTTP ルート検証を試す場合のトークン(通常は空)"
  type        = string
  default     = ""
  sensitive   = true
}

variable "depends_on_endpoints" {
  description = "user_data が S3 と dnf を叩く前に揃っているべきリソース(VPC エンドポイントなど)の ID。依存関係の表明にだけ使う"
  type        = list(string)
  default     = []
}
