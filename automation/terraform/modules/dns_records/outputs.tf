output "planned_service_endpoint" {
  value = {
    name   = var.service_name
    target = var.service_target
  }
}
