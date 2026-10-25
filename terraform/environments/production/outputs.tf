output "production_resource_group_ids" {
  description = "IDs of the four production resource groups."
  value       = local.resource_groups
}
output "vnet_id" {
  value = azurerm_virtual_network.vnet-restsim-prod.id
}
output "subnet_ids" {
  value = {
    app               = azurerm_subnet.app.id
    data              = azurerm_subnet.data.id
    private_endpoints = azurerm_subnet.private_endpoints.id
  }
}
output "origin_public_ip" {
  description = "Public IP for the Azure web servers. Test the new servers before changing the existing Cloudflare DNS record."
  value       = azurerm_public_ip.ingress.ip_address
}
output "egress_public_ip" {
  value = azurerm_public_ip.egress.ip_address
}
output "key_vault_uri" {
  value = azurerm_key_vault.production.vault_uri
}
output "private_dns_zone_ids" {
  value = {
    postgres  = azurerm_private_dns_zone.postgres.id
    files     = azurerm_private_dns_zone.files.id
    vault     = azurerm_private_dns_zone.vault.id
    redis     = azurerm_private_dns_zone.redis.id
    artifacts = azurerm_private_dns_zone.artifacts.id
  }
}
output "postgresql_fqdn" {
  value = azurerm_postgresql_flexible_server.production.fqdn
}
output "azure_files_unc_path" {
  value = "//${azurerm_storage_account.files.name}.file.core.windows.net/${azurerm_storage_share.application.name}"
}
output "redis_endpoint" {
  value = { host = azurerm_managed_redis.sessions.hostname, tls_port = 10000 }
}
output "compute_gallery_id" {
  value = azapi_resource.gallery.id
}
output "gallery_application_id" {
  value = azurerm_gallery_application.restsim.id
}
output "artifact_container_id" {
  value = azurerm_storage_container.releases.id
}
output "vmss_id" {
  value = try(azurerm_linux_virtual_machine_scale_set.web[0].id, null)
}
output "worker_vm_id" {
  value = try(azurerm_linux_virtual_machine.worker[0].id, null)
}
output "runtime_managed_identity_principals" {
  value = local.runtime_principals
}
output "github_oidc_clients" {
  value = var.enable_github_oidc ? {
    infrastructure = {
      client_id = azurerm_user_assigned_identity.github_infrastructure[0].client_id
      subject   = var.github_infrastructure_oidc_subject
    }
    publisher = {
      client_id = azurerm_user_assigned_identity.github_publisher[0].client_id
      subject   = var.github_publisher_oidc_subject
    }
    release = {
      client_id = azurerm_user_assigned_identity.github_release[0].client_id
      subject   = var.github_release_oidc_subject
    }
  } : {}
}
output "log_analytics_workspace_id" {
  value = azurerm_log_analytics_workspace.production.id
}
output "application_insights_id" {
  value = azurerm_application_insights.production.id
}
output "backup_vault_id" {
  value = azurerm_recovery_services_vault.production.id
}
