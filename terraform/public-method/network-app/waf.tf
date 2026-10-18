# エージェントだけを通すための秘密値。Pentest のカスタムヘッダーと WAF の許可ルールの両方で使う
resource "random_password" "pentest_header" {
  length  = 32
  special = false
}

# 操作者の動作確認用の送信元(任意)
resource "aws_wafv2_ip_set" "operator" {
  count = length(var.operator_cidrs) > 0 ? 1 : 0

  name               = "${var.name}-operator"
  scope              = "REGIONAL"
  ip_address_version = "IPV4"
  addresses          = var.operator_cidrs
}

locals {
  # waf_mode によってルールの優先度(評価順)だけを入れ替える
  header_rule_priority   = var.waf_mode == "agent-first" ? 0 : 50
  operator_rule_priority = var.waf_mode == "agent-first" ? 1 : 51
  managed_base_priority  = 10
}

resource "aws_wafv2_web_acl" "app" {
  name        = "${var.name}-app"
  description = "Default block; allow only the pentest agent (by header) and optionally the operator"
  scope       = "REGIONAL"

  # 既定動作は遮断。ヘッダーを持たない第三者は、どのモードでもアプリに届かない
  default_action {
    block {}
  }

  # ①/② エージェントのカスタムヘッダー一致 → 許可
  rule {
    name     = "allow-pentest-agent-header"
    priority = local.header_rule_priority

    action {
      allow {}
    }

    statement {
      byte_match_statement {
        search_string         = random_password.pentest_header.result
        positional_constraint = "EXACTLY"

        field_to_match {
          single_header {
            name = lower(var.custom_header_name)
          }
        }

        text_transformation {
          priority = 0
          type     = "NONE"
        }
      }
    }

    visibility_config {
      cloudwatch_metrics_enabled = true
      metric_name                = "allow-pentest-agent-header"
      sampled_requests_enabled   = true
    }
  }

  # 操作者の送信元 → 許可(operator_cidrs を指定したときだけ)
  dynamic "rule" {
    for_each = aws_wafv2_ip_set.operator

    content {
      name     = "allow-operator"
      priority = local.operator_rule_priority

      action {
        allow {}
      }

      statement {
        ip_set_reference_statement {
          arn = rule.value.arn
        }
      }

      visibility_config {
        cloudwatch_metrics_enabled = true
        metric_name                = "allow-operator"
        sampled_requests_enabled   = true
      }
    }
  }

  # AWS マネージドルール群(グループ内の動作に従う = 一致すれば遮断)
  dynamic "rule" {
    for_each = { for i, g in var.managed_rule_groups : g => i }

    content {
      name     = rule.key
      priority = local.managed_base_priority + rule.value

      override_action {
        none {}
      }

      statement {
        managed_rule_group_statement {
          name        = rule.key
          vendor_name = "AWS"
        }
      }

      visibility_config {
        cloudwatch_metrics_enabled = true
        metric_name                = rule.key
        sampled_requests_enabled   = true
      }
    }
  }

  visibility_config {
    cloudwatch_metrics_enabled = true
    metric_name                = "${var.name}-app"
    sampled_requests_enabled   = true
  }

  tags = { Name = "${var.name}-app" }
}

resource "aws_wafv2_web_acl_association" "alb" {
  resource_arn = aws_lb.app.arn
  web_acl_arn  = aws_wafv2_web_acl.app.arn
}

# WAF ログ(どのルールが何件遮断・許可したかを数える)。ロググループ名は aws-waf-logs- で始める必要がある
resource "aws_cloudwatch_log_group" "waf" {
  name              = "aws-waf-logs-${var.name}-app"
  retention_in_days = var.log_retention_days
}

resource "aws_wafv2_web_acl_logging_configuration" "app" {
  resource_arn            = aws_wafv2_web_acl.app.arn
  log_destination_configs = [aws_cloudwatch_log_group.waf.arn]
}
