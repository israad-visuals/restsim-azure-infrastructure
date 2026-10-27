resource "azurerm_postgresql_flexible_server" "development" {
  name                              = "psql-restsim-dev-${random_string.suffix.result}"
  location                          = var.location
  resource_group_name               = azurerm_resource_group.data.name
  version                           = "16"
  sku_name                          = "B_Standard_B1ms"
  storage_mb                        = 32768
  backup_retention_days             = 7
  geo_redundant_backup_enabled      = false
  public_network_access_enabled     = false
  delegated_subnet_id               = azurerm_subnet.data.id
  private_dns_zone_id               = azurerm_private_dns_zone.development["postgres"].id
  administrator_login               = "restsimdevadmin"
  administrator_password_wo         = var.postgres_admin_password
  administrator_password_wo_version = var.postgres_password_version
  tags                              = local.tags

  authentication {
    password_auth_enabled         = true
    active_directory_auth_enabled = false
  }

  depends_on = [
    azurerm_subnet_network_security_group_association.data,
    azurerm_private_dns_zone_virtual_network_link.development
  ]
}

resource "azurerm_postgresql_flexible_server_database" "application" {
  name      = "restsim_dev"
  server_id = azurerm_postgresql_flexible_server.development.id
  charset   = "UTF8"
  collation = "en_US.utf8"
}

resource "azurerm_postgresql_flexible_server_configuration" "require_tls" {
  name      = "require_secure_transport"
  server_id = azurerm_postgresql_flexible_server.development.id
  value     = "on"
}
