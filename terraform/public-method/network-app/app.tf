module "vulnapp" {
  source = "../../modules/vulnapp"

  name                 = var.name
  account_id           = var.account_id
  subnet_id            = aws_subnet.app.id
  security_group_ids   = [aws_security_group.app.id]
  app_py_path          = "${path.module}/../../../app/app.py"
  wheels_dir           = "${path.module}/${var.wheels_dir}"
  requirements_path    = "${path.module}/../../../app/requirements.txt"
  instance_type        = var.instance_type
  depends_on_endpoints = module.endpoints.all_endpoint_ids
}

module "flow_logs" {
  count  = var.enable_flow_logs ? 1 : 0
  source = "../../modules/subnet-flow-logs"

  name           = "${var.name}-app"
  subnet_id      = aws_subnet.app.id
  retention_days = var.log_retention_days
}
