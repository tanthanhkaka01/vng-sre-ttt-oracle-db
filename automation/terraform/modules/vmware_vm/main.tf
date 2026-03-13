resource "vsphere_virtual_machine" "this" {
  name             = var.vm_name
  folder           = var.vm_folder
  num_cpus         = var.num_cpus
  memory           = var.memory_mb
  datastore_id     = var.datastore_id
  resource_pool_id = var.resource_pool_id
  guest_id         = var.guest_id

  network_interface {
    network_id   = var.public_network_id
    adapter_type = "vmxnet3"
  }

  network_interface {
    network_id   = var.private_network_id
    adapter_type = "vmxnet3"
  }

  network_interface {
    network_id   = var.management_network_id
    adapter_type = "vmxnet3"
  }

  disk {
    label            = "system-disk"
    size             = var.system_disk_gb
    thin_provisioned = true
  }

  clone {
    template_uuid = var.template_uuid

    customize {
      linux_options {
        host_name = var.short_hostname
        domain    = var.domain
      }

      network_interface {
        ipv4_address = var.public_ip
        ipv4_netmask = var.public_netmask
      }

      ipv4_gateway = var.public_gateway
      dns_server_list = var.dns_servers
    }
  }

  lifecycle {
    ignore_changes = [
      annotation,
    ]
  }
}
