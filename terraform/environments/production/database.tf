resource "random_password" "postgres_admin" {
  length           = 40
  special          = true
  override_special = "_%@-"
}

resource "azurerm_postgresql_flexible_server" "production" {
  name                          = "psql-restsim-prod-${local.suffix}"
  location                      = var.location
  resource_group_name           = azurerm_resource_group.rg-restsim-prod-data.name
  version                       = var.postgres_version
  sku_name                      = var.postgres_sku
  storage_mb                    = var.postgres_storage_mb
  auto_grow_enabled             = true
  administrator_login           = var.postgres_admin_username
  administrator_password        = random_password.postgres_admin.result
  delegated_subnet_id           = azurerm_subnet.data.id
  private_dns_zone_id           = azurerm_private_dns_zone.postgres.id
  public_network_access_enabled = false
  zone                          = "1"
  backup_retention_days         = 35
  geo_redundant_backup_enabled  = true
  high_availability {
    mode                      = "ZoneRedundant"
    standby_availability_zone = "2"
  }
  authentication {
    password_auth_enabled         = true
    active_directory_auth_enabled = false
  }
  maintenance_window {
    day_of_week  = 0
    start_hour   = 4
    start_minute = 0
  }
  tags = local.tags
  depends_on = [
    azurerm_private_dns_zone_virtual_network_link.postgres,
    azurerm_private_dns_zone_virtual_network_link.files,
    azurerm_private_dns_zone_virtual_network_link.vault,
    azurerm_private_dns_zone_virtual_network_link.redis,
    azurerm_private_dns_zone_virtual_network_link.artifacts,
    azurerm_subnet_network_security_group_association.data,
    azurerm_network_security_rule.app_cloudflare,
    azurerm_network_security_rule.app_readiness,
    azurerm_network_security_rule.app_postgres,
    azurerm_network_security_rule.app_private_services,
    azurerm_network_security_rule.app_azure_control,
    azurerm_network_security_rule.app_cloudflare_jwks,
    azurerm_network_security_rule.app_dns_udp,
    azurerm_network_security_rule.app_dns_tcp,
    azurerm_network_security_rule.app_private_admin,
    azurerm_network_security_rule.app_approved_https,
    azurerm_network_security_rule.app_deny_in,
    azurerm_network_security_rule.app_deny_out,
    azurerm_network_security_rule.data_app,
    azurerm_network_security_rule.data_ha_in,
    azurerm_network_security_rule.data_ha_out,
    azurerm_network_security_rule.data_storage,
    azurerm_network_security_rule.data_entra,
    azurerm_network_security_rule.data_dns_udp,
    azurerm_network_security_rule.data_dns_tcp,
    azurerm_network_security_rule.data_private_admin,
    azurerm_network_security_rule.data_deny_in,
    azurerm_network_security_rule.data_deny_out,
    azurerm_network_security_rule.pe_app,
    azurerm_network_security_rule.pe_private_runner,
    azurerm_network_security_rule.pe_deny_in,
    azurerm_network_security_rule.pe_deny_out
  ]
  lifecycle {
    prevent_destroy = true
    ignore_changes  = [zone, high_availability[0].standby_availability_zone]
  }
}

resource "azurerm_postgresql_flexible_server_database" "restsim" {
  name      = "restsim"
  server_id = azurerm_postgresql_flexible_server.production.id
  collation = "en_US.utf8"
  charset   = "UTF8"
  lifecycle {
    prevent_destroy = true
  }
}

resource "azurerm_postgresql_flexible_server_configuration" "require_tls" {
  name      = "require_secure_transport"
  server_id = azurerm_postgresql_flexible_server.production.id
  value     = "on"
}

# Create the app database login and tables during the database migration.
