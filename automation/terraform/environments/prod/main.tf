module "network_segments" {
  source             = "../../modules/network_segments"
  public_cidr        = var.public_cidr
  private_cidr       = var.private_cidr
  management_cidr    = var.management_cidr
  public_gateway     = var.public_gateway
  management_gateway = var.management_gateway
}

module "dns_primary" {
  source         = "../../modules/dns_records"
  host_records   = var.host_records
  scan_name      = var.scan_name
  scan_ips       = var.scan_ips
  service_name   = var.service_name
  service_target = var.service_target
}

module "vmware_nodes" {
  for_each = { for node in var.vmware_nodes : node.name => node }
  source   = "../../modules/vmware_vm"

  vm_name               = each.value.name
  short_hostname        = each.value.short_hostname
  domain                = each.value.domain
  vm_folder             = each.value.vm_folder
  num_cpus              = each.value.num_cpus
  memory_mb             = each.value.memory_mb
  system_disk_gb        = each.value.system_disk_gb
  datastore_id          = each.value.datastore_id
  resource_pool_id      = each.value.resource_pool_id
  guest_id              = each.value.guest_id
  template_uuid         = each.value.template_uuid
  public_network_id     = each.value.public_network_id
  private_network_id    = each.value.private_network_id
  management_network_id = each.value.management_network_id
  public_ip             = each.value.public_ip
  public_netmask        = each.value.public_netmask
  public_gateway        = each.value.public_gateway
  dns_servers           = each.value.dns_servers
}

