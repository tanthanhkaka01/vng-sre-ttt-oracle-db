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

module "openstack_nodes" {
  for_each = { for node in var.openstack_nodes : node.name => node }
  source   = "../../modules/openstack_instance"

  instance_name         = each.value.name
  image_name            = each.value.image_name
  flavor_name           = each.value.flavor_name
  keypair               = each.value.keypair
  security_groups       = each.value.security_groups
  cloud_init            = each.value.cloud_init
  root_volume_size_gb   = each.value.root_volume_size_gb
  public_network_id     = each.value.public_network_id
  public_subnet_id      = each.value.public_subnet_id
  public_ip             = each.value.public_ip
  private_network_id    = each.value.private_network_id
  private_subnet_id     = each.value.private_subnet_id
  private_ip            = each.value.private_ip
  management_network_id = each.value.management_network_id
  management_subnet_id  = each.value.management_subnet_id
  management_ip         = each.value.management_ip
}
