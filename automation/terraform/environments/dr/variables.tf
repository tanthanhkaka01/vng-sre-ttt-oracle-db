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
