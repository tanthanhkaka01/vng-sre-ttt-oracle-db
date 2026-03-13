output "network_summary" {
  value = module.network_segments.network_summary
}

output "dns_summary" {
  value = module.dns_primary.planned_service_endpoint
}
