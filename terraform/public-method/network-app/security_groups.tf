# ALB: インターネットから 443 のみ受ける。中身の選別は WAF が行う
resource "aws_security_group" "alb" {
  name        = "${var.name}-alb"
  description = "HTTPS from the internet; WAF decides what passes"
  vpc_id      = aws_vpc.lab.id

  tags = { Name = "${var.name}-alb" }
}

resource "aws_vpc_security_group_ingress_rule" "alb_https" {
  security_group_id = aws_security_group.alb.id
  description       = "HTTPS from anywhere (filtered by WAF)"
  ip_protocol       = "tcp"
  from_port         = 443
  to_port           = 443
  cidr_ipv4         = "0.0.0.0/0"
}

resource "aws_vpc_security_group_egress_rule" "alb_to_app" {
  security_group_id            = aws_security_group.alb.id
  description                  = "HTTP to the target app"
  ip_protocol                  = "tcp"
  from_port                    = 80
  to_port                      = 80
  referenced_security_group_id = aws_security_group.app.id
}

# 対象アプリ: ALB からの 80 番だけ受ける。ALB を経由しない到達経路は存在しない
resource "aws_security_group" "app" {
  name        = "${var.name}-app"
  description = "Target app: HTTP only from the ALB"
  vpc_id      = aws_vpc.lab.id

  tags = { Name = "${var.name}-app" }
}

resource "aws_vpc_security_group_ingress_rule" "app_http_from_alb" {
  security_group_id            = aws_security_group.app.id
  description                  = "HTTP from the ALB only"
  ip_protocol                  = "tcp"
  from_port                    = 80
  to_port                      = 80
  referenced_security_group_id = aws_security_group.alb.id
}

resource "aws_vpc_security_group_egress_rule" "app_all" {
  security_group_id = aws_security_group.app.id
  description       = "Outbound to VPC endpoints (no internet route exists)"
  ip_protocol       = "-1"
  cidr_ipv4         = "0.0.0.0/0"
}
