# ---------------------------------------------------------------- Application ロール
# Security Agent の Web アプリケーションが、利用者の操作を API 呼び出しとして実行するためのロール
data "aws_iam_policy_document" "app_trust" {
  statement {
    effect  = "Allow"
    actions = ["sts:AssumeRole"]

    principals {
      type        = "Service"
      identifiers = ["securityagent.amazonaws.com"]
    }
  }
}

resource "aws_iam_role" "app" {
  count = var.create_app_role ? 1 : 0

  name               = "${var.name}-securityagent-app"
  description        = "Assumed by AWS Security Agent to serve the web application"
  assume_role_policy = data.aws_iam_policy_document.app_trust.json
}

resource "aws_iam_role_policy_attachment" "app_webapp_policy" {
  count = var.create_app_role ? 1 : 0

  role       = aws_iam_role.app[0].name
  policy_arn = "arn:aws:iam::aws:policy/service-role/AWSSecurityAgentWebAppPolicy"
}

# 管理ポリシー AWSSecurityAgentWebAppPolicy には logs の権限が無く、Web アプリの「ログ」タブで
# タスクログを開くと logs:GetLogEvents が拒否される(実測)。ペンテスト用ロググループに限って読み取りを許可する
data "aws_iam_policy_document" "app_logs_read" {
  statement {
    sid    = "ReadPentestLogs"
    effect = "Allow"
    actions = [
      "logs:DescribeLogStreams",
      "logs:GetLogEvents",
      "logs:FilterLogEvents",
    ]
    resources = [
      "arn:aws:logs:${var.region}:${var.account_id}:log-group:/aws/securityagent/*",
      "arn:aws:logs:${var.region}:${var.account_id}:log-group:/aws/securityagent/*:log-stream:*",
    ]
  }
}

resource "aws_iam_role_policy" "app_logs_read" {
  count = var.create_app_role ? 1 : 0

  name   = "securityagent-webapp-logs-read"
  role   = aws_iam_role.app[0].id
  policy = data.aws_iam_policy_document.app_logs_read.json
}

# ---------------------------------------------------------------- Pentest サービスロール
# 実行中の Security Agent が、利用者のアカウントの中で ENI 作成やログ出力を行うためのロール
data "aws_iam_policy_document" "service_trust" {
  statement {
    effect  = "Allow"
    actions = ["sts:AssumeRole"]

    principals {
      type        = "Service"
      identifiers = ["securityagent.amazonaws.com"]
    }

    # 混乱した代理(confused deputy)対策
    condition {
      test     = "StringEquals"
      variable = "aws:SourceAccount"
      values   = [var.account_id]
    }
  }
}

resource "aws_iam_role" "service" {
  name               = "${var.name}-securityagent-pentest"
  description        = "Penetration test service role for AWS Security Agent"
  assume_role_policy = data.aws_iam_policy_document.service_trust.json
}

data "aws_iam_policy_document" "service_permissions" {
  statement {
    sid    = "IamReadAndSimulate"
    effect = "Allow"
    actions = [
      "iam:GetRole",
      "iam:SimulatePrincipalPolicy",
    ]
    resources = ["*"]
  }

  statement {
    sid    = "CloudWatchLogs"
    effect = "Allow"
    actions = [
      "logs:CreateLogGroup",
      "logs:CreateLogStream",
      "logs:PutLogEvents",
    ]
    resources = ["*"]
  }

  # 公式: Connect agent to private VPC resources(Private VPC 方式のときだけ)
  dynamic "statement" {
    for_each = length(var.agent_subnet_arns) > 0 ? [1] : []

    content {
      sid    = "VpcNetworkInterfaces"
      effect = "Allow"
      actions = [
        "ec2:CreateNetworkInterface",
        "ec2:DescribeDhcpOptions",
        "ec2:DescribeNetworkInterfaces",
        "ec2:DescribeNetworkInterfaceAttribute",
        "ec2:DescribeSubnets",
        "ec2:DescribeSecurityGroups",
        "ec2:DescribeVpcs",
        "ec2:ModifyNetworkInterfaceAttribute",
        "ec2:DeleteNetworkInterface",
      ]
      resources = ["*"]
    }
  }

  dynamic "statement" {
    for_each = length(var.agent_subnet_arns) > 0 ? [1] : []

    content {
      sid       = "VpcNetworkInterfacePermissionOnAgentSubnets"
      effect    = "Allow"
      actions   = ["ec2:CreateNetworkInterfacePermission"]
      resources = ["arn:aws:ec2:${var.region}:${var.account_id}:network-interface/*"]

      condition {
        test     = "ArnEquals"
        variable = "ec2:Subnet"
        values   = var.agent_subnet_arns
      }
    }
  }
}

resource "aws_iam_role_policy" "service" {
  name   = "securityagent-pentest"
  role   = aws_iam_role.service.id
  policy = data.aws_iam_policy_document.service_permissions.json
}
