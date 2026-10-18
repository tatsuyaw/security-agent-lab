locals {
  wheel_files = fileset(var.wheels_dir, "*.whl")
}

# ---------------------------------------------------------------- wheel 置き場
resource "aws_s3_bucket" "artifacts" {
  bucket        = "${var.name}-artifacts-${var.account_id}"
  force_destroy = true

  tags = { Name = "${var.name}-artifacts" }
}

resource "aws_s3_bucket_public_access_block" "artifacts" {
  bucket = aws_s3_bucket.artifacts.id

  block_public_acls       = true
  block_public_policy     = true
  ignore_public_acls      = true
  restrict_public_buckets = true
}

resource "aws_s3_bucket_server_side_encryption_configuration" "artifacts" {
  bucket = aws_s3_bucket.artifacts.id

  rule {
    apply_server_side_encryption_by_default {
      sse_algorithm = "AES256"
    }
  }
}

resource "aws_s3_object" "wheel" {
  for_each = local.wheel_files

  bucket = aws_s3_bucket.artifacts.id
  key    = "wheels/${each.value}"
  source = "${var.wheels_dir}/${each.value}"
  etag   = filemd5("${var.wheels_dir}/${each.value}")
}

# ハッシュ固定の requirements.txt。EC2 側の pip がこれと一致する wheel だけを受け付ける
resource "aws_s3_object" "requirements" {
  bucket = aws_s3_bucket.artifacts.id
  key    = "wheels/requirements.txt"
  source = var.requirements_path
  etag   = filemd5(var.requirements_path)
}

# ---------------------------------------------------------------- EC2 のロール(SSM 接続 + wheel 読み取りのみ)
data "aws_iam_policy_document" "ec2_trust" {
  statement {
    effect  = "Allow"
    actions = ["sts:AssumeRole"]

    principals {
      type        = "Service"
      identifiers = ["ec2.amazonaws.com"]
    }
  }
}

resource "aws_iam_role" "instance" {
  name               = "${var.name}-app-instance"
  assume_role_policy = data.aws_iam_policy_document.ec2_trust.json
}

resource "aws_iam_role_policy_attachment" "ssm" {
  role       = aws_iam_role.instance.name
  policy_arn = "arn:aws:iam::aws:policy/AmazonSSMManagedInstanceCore"
}

data "aws_iam_policy_document" "read_wheels" {
  statement {
    sid       = "ListWheels"
    effect    = "Allow"
    actions   = ["s3:ListBucket"]
    resources = [aws_s3_bucket.artifacts.arn]
  }

  statement {
    sid       = "GetWheels"
    effect    = "Allow"
    actions   = ["s3:GetObject"]
    resources = ["${aws_s3_bucket.artifacts.arn}/wheels/*"]
  }
}

resource "aws_iam_role_policy" "read_wheels" {
  name   = "read-wheels"
  role   = aws_iam_role.instance.id
  policy = data.aws_iam_policy_document.read_wheels.json
}

resource "aws_iam_instance_profile" "instance" {
  name = "${var.name}-app"
  role = aws_iam_role.instance.name
}

# ---------------------------------------------------------------- EC2
data "aws_ssm_parameter" "al2023" {
  name = "/aws/service/ami-amazon-linux-latest/al2023-ami-kernel-default-x86_64"
}

data "aws_ec2_instance_type" "this" {
  instance_type = var.instance_type
}

resource "aws_instance" "app" {
  ami                         = data.aws_ssm_parameter.al2023.value
  instance_type               = var.instance_type
  subnet_id                   = var.subnet_id
  vpc_security_group_ids      = var.security_group_ids
  iam_instance_profile        = aws_iam_instance_profile.instance.name
  associate_public_ip_address = false

  # IMDSv2 必須。メタデータ経由の認証情報窃取を構造的に塞ぐ
  metadata_options {
    http_tokens                 = "required"
    http_put_response_hop_limit = 1
  }

  root_block_device {
    volume_type = "gp3"
    volume_size = 8
    encrypted   = true
  }

  user_data = templatefile("${path.module}/user_data.sh.tftpl", {
    app_py           = file(var.app_py_path)
    verify_token     = var.verify_token
    artifacts_bucket = aws_s3_bucket.artifacts.bucket
    depends_marker   = join(",", var.depends_on_endpoints)
  })
  user_data_replace_on_change = true

  lifecycle {
    precondition {
      condition     = data.aws_ec2_instance_type.this.free_tier_eligible
      error_message = "${var.instance_type} は無料利用枠の対象外。t3.micro などを指定する。"
    }
    precondition {
      condition     = length(local.wheel_files) > 0
      error_message = "wheels_dir に wheel がない。手順書の「wheel の取得」を先に実行する。"
    }
  }

  depends_on = [aws_s3_object.wheel, aws_s3_object.requirements, aws_iam_role_policy.read_wheels]

  tags = { Name = "${var.name}-app" }
}
