output "vm_name" {
  value = vsphere_virtual_machine.this.name
}

output "vm_uuid" {
  value = vsphere_virtual_machine.this.id
}
