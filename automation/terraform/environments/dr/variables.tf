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

variable "openstack_auth_url" { type = string }
variable "openstack_tenant_name" { type = string }
variable "openstack_user_name" { type = string }
variable "openstack_password" {
  type      = string
  sensitive = true
}
variable "openstack_region" { type = string }
variable "openstack_domain_name" {
  type    = string
  default = "Default"
}

variable "openstack_nodes" {
  type = list(object({
    name                  = string
    image_name            = string
    flavor_name           = string
    keypair               = string
    security_groups       = list(string)
    cloud_init            = string
    public_network_id     = string
    public_subnet_id      = string
    public_ip             = string
    private_network_id    = string
    private_subnet_id     = string
    private_ip            = string
    management_network_id = string
    management_subnet_id  = string
    management_ip         = string
  }))
  default = []
}

