module "network_segments" {
  source             = "../../modules/network_segments"
  public_cidr        = var.public_cidr
  private_cidr       = var.private_cidr
  management_cidr    = var.management_cidr
  public_gateway     = var.public_gateway
  management_gateway = var.management_gateway
}

module "dns_dr" {
  source         = "../../modules/dns_records"
  host_records   = var.host_records
  scan_name      = var.scan_name
  scan_ips       = var.scan_ips
  service_name   = var.service_name
  service_target = var.service_target
}
