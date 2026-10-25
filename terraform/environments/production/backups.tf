# PostgreSQL keeps 35 days of backups and a copy in another region. See database.tf.
# File backups stay separate from VM replacements and Redis sessions.
resource "azurerm_recovery_services_vault" "production" {
  name                = "rsv-restsim-prod"
  location            = var.location
  resource_group_name = azurerm_resource_group.rg-restsim-prod-data.name
  sku                 = "Standard"
  storage_mode_type   = "ZoneRedundant"
  # AzureRM 4.81 does not expose a soft_delete_enabled argument here.
  # Check that Azure has soft delete enabled before adding data to the backup.
  tags = local.tags
  lifecycle {
    prevent_destroy = true
  }
}

resource "azurerm_backup_policy_file_share" "application" {
  name                = "backup-restsim-prod-files"
  resource_group_name = azurerm_resource_group.rg-restsim-prod-data.name
  recovery_vault_name = azurerm_recovery_services_vault.production.name
  timezone            = "UTC"
  backup_tier         = "snapshot"
  backup {
    frequency = "Daily"
    time      = "03:00"
  }
  retention_daily {
    count = 30
  }
  retention_weekly {
    count    = 12
    weekdays = ["Sunday"]
  }
}

resource "azurerm_backup_container_storage_account" "files" {
  resource_group_name = azurerm_resource_group.rg-restsim-prod-data.name
  recovery_vault_name = azurerm_recovery_services_vault.production.name
  storage_account_id  = azurerm_storage_account.files.id
}

resource "azurerm_backup_protected_file_share" "application" {
  resource_group_name       = azurerm_resource_group.rg-restsim-prod-data.name
  recovery_vault_name       = azurerm_recovery_services_vault.production.name
  source_storage_account_id = azurerm_storage_account.files.id
  source_file_share_name    = azurerm_storage_share.application.name
  backup_policy_id          = azurerm_backup_policy_file_share.application.id
  depends_on                = [azurerm_backup_container_storage_account.files]
  lifecycle {
    prevent_destroy = true
  }
}
