resource "null_resource" "dns_placeholder" {
  triggers = {
    service_name   = var.service_name
    service_target = var.service_target
    scan_name      = var.scan_name
    scan_ips       = join(",", var.scan_ips)
    host_records   = jsonencode(var.host_records)
  }
}
