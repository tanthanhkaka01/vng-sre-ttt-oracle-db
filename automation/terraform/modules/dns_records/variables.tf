variable "host_records" {
  type = list(object({
    name  = string
    value = string
  }))
}

variable "scan_name" { type = string }
variable "scan_ips" { type = list(string) }
variable "service_name" { type = string }
variable "service_target" { type = string }
