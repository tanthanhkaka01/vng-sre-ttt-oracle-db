variable "public_cidr" { type = string }
variable "private_cidr" { type = string }
variable "management_cidr" { type = string }
variable "public_gateway" { type = string }
variable "management_gateway" { type = string }

variable "service_name" { type = string }
variable "service_target" { type = string }
variable "scan_name" { type = string }
variable "scan_ips" { type = list(string) }
variable "host_records" {
  type = list(object({
    name  = string
    value = string
  }))
}

variable "vcenter_server" { type = string }
variable "vcenter_user" { type = string }
variable "vcenter_password" {
  type      = string
  sensitive = true
}
variable "vcenter_allow_unverified_ssl" {
  type    = bool
  default = true
}

variable "vmware_nodes" {
  type = list(object({
    name                  = string
    short_hostname        = string
    domain                = string
    vm_folder             = string
    num_cpus              = number
    memory_mb             = number
    system_disk_gb        = number
    datastore_id          = string
    resource_pool_id      = string
    guest_id              = string
    template_uuid         = string
    public_network_id     = string
    private_network_id    = string
    management_network_id = string
    public_ip             = string
    public_netmask        = number
    public_gateway        = string
    dns_servers           = list(string)
  }))
  default = []
}

