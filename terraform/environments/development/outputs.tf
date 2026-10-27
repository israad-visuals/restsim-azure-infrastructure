output "resource_groups" {
  value = {
    network    = azurerm_resource_group.network.name
    app        = azurerm_resource_group.app.name
    data       = azurerm_resource_group.data.name
    monitoring = azurerm_resource_group.monitoring.name
  }
}

output "staging_ip_address" {
  value = azurerm_public_ip.staging.ip_address
}

output "staging_url" {
  value = var.staging_zone_name == null ? null : "https://${var.staging_zone_name}"
}

output "staging_dns_name_servers" {
  description = "Authoritative nameservers for delegation of the development DNS zone."
  value       = try(azurerm_dns_zone.staging[0].name_servers, [])
}

output "staging_ingress_enabled" {
  value = var.enable_staging_ingress
}

output "app_vm_id" {
  value = azurerm_linux_virtual_machine.app.id
}

output "app_managed_identity_id" {
  value = azurerm_linux_virtual_machine.app.identity[0].principal_id
}

output "postgres_host" {
  value = azurerm_postgresql_flexible_server.development.fqdn
}

output "key_vault_uri" {
  value = azurerm_key_vault.development.vault_uri
}

output "file_share_name" {
  value = azurerm_storage_share.application.name
}

output "application_insights_connection_string" {
  description = "Sensitive connection string for development application telemetry."
  value       = azurerm_application_insights.development.connection_string
  sensitive   = true
}
