output "network_summary" {
  value = module.network_segments.network_summary
}

output "dns_summary" {
  value = module.dns_dr.planned_service_endpoint
}
