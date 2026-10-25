resource "azurerm_storage_account" "files" {
  name                            = "strsprodfiles${local.suffix}"
  location                        = var.location
  resource_group_name             = azurerm_resource_group.rg-restsim-prod-data.name
  account_tier                    = "Standard"
  account_kind                    = "StorageV2"
  account_replication_type        = "ZRS"
  min_tls_version                 = "TLS1_2"
  https_traffic_only_enabled      = true
  public_network_access_enabled   = false
  allow_nested_items_to_be_public = false
  # Linux reads the storage key from Key Vault to mount this share.
  shared_access_key_enabled = true
  network_rules {
    default_action = "Deny"
    bypass         = ["AzureServices"]
  }
  share_properties {
    retention_policy {
      days = 30
    }
    smb {
      versions                = ["SMB3.1.1"]
      authentication_types    = ["NTLMv2"]
      channel_encryption_type = ["AES-256-GCM"]
    }
  }
  tags = local.tags
  lifecycle {
    prevent_destroy = true
  }
}

resource "azurerm_storage_share" "application" {
  name               = "restsim-files"
  storage_account_id = azurerm_storage_account.files.id
  quota              = var.files_quota_gb
  enabled_protocol   = "SMB"
  access_tier        = "TransactionOptimized"
  lifecycle {
    prevent_destroy = true
  }
}

resource "azurerm_storage_account" "artifacts" {
  name                            = "strsprodart${local.suffix}"
  location                        = var.location
  resource_group_name             = azurerm_resource_group.rg-restsim-prod-app.name
  account_tier                    = "Standard"
  account_kind                    = "StorageV2"
  account_replication_type        = "ZRS"
  min_tls_version                 = "TLS1_2"
  https_traffic_only_enabled      = true
  public_network_access_enabled   = false
  allow_nested_items_to_be_public = false
  shared_access_key_enabled       = false
  default_to_oauth_authentication = true
  network_rules {
    default_action = "Deny"
    # Allow Compute Gallery to read packages using its Azure identity.
    bypass = ["AzureServices"]
  }
  blob_properties {
    versioning_enabled = true
    delete_retention_policy {
      days = 30
    }
    container_delete_retention_policy {
      days = 30
    }
  }
  tags = local.tags
  lifecycle {
    prevent_destroy = true
  }
}

resource "azurerm_storage_container" "releases" {
  name                  = "releases"
  storage_account_id    = azurerm_storage_account.artifacts.id
  container_access_type = "private"
}

# Use Azure Managed Redis for shared app sessions.
# EnterpriseCluster gives the app one encrypted endpoint on port 10000.
resource "azurerm_managed_redis" "sessions" {
  name                      = "redis-restsim-prod-${local.suffix}"
  location                  = var.location
  resource_group_name       = azurerm_resource_group.rg-restsim-prod-data.name
  sku_name                  = var.redis_sku
  high_availability_enabled = true
  public_network_access     = "Disabled"
  default_database {
    client_protocol                             = "Encrypted"
    clustering_policy                           = "EnterpriseCluster"
    access_keys_authentication_enabled          = true
    eviction_policy                             = "NoEviction"
    persistence_redis_database_backup_frequency = "1h"
  }
  tags = local.tags
  lifecycle {
    prevent_destroy = true
  }
}

resource "azurerm_private_endpoint" "files" {
  name                = "pe-restsim-prod-files"
  location            = var.location
  resource_group_name = azurerm_resource_group.rg-restsim-prod-network.name
  subnet_id           = azurerm_subnet.private_endpoints.id
  tags                = local.tags

  private_service_connection {
    name                           = "psc-restsim-prod-files"
    private_connection_resource_id = azurerm_storage_account.files.id
    subresource_names              = ["file"]
    is_manual_connection           = false
  }

  private_dns_zone_group {
    name                 = "default"
    private_dns_zone_ids = [azurerm_private_dns_zone.files.id]
  }

  depends_on = [azurerm_subnet_network_security_group_association.private_endpoints]
}

resource "azurerm_private_endpoint" "vault" {
  name                = "pe-restsim-prod-vault"
  location            = var.location
  resource_group_name = azurerm_resource_group.rg-restsim-prod-network.name
  subnet_id           = azurerm_subnet.private_endpoints.id
  tags                = local.tags

  private_service_connection {
    name                           = "psc-restsim-prod-vault"
    private_connection_resource_id = azurerm_key_vault.production.id
    subresource_names              = ["vault"]
    is_manual_connection           = false
  }

  private_dns_zone_group {
    name                 = "default"
    private_dns_zone_ids = [azurerm_private_dns_zone.vault.id]
  }

  depends_on = [azurerm_subnet_network_security_group_association.private_endpoints]
}

resource "azurerm_private_endpoint" "redis" {
  name                = "pe-restsim-prod-redis"
  location            = var.location
  resource_group_name = azurerm_resource_group.rg-restsim-prod-network.name
  subnet_id           = azurerm_subnet.private_endpoints.id
  tags                = local.tags

  private_service_connection {
    name                           = "psc-restsim-prod-redis"
    private_connection_resource_id = azurerm_managed_redis.sessions.id
    subresource_names              = ["redisEnterprise"]
    is_manual_connection           = false
  }

  private_dns_zone_group {
    name                 = "default"
    private_dns_zone_ids = [azurerm_private_dns_zone.redis.id]
  }

  depends_on = [azurerm_subnet_network_security_group_association.private_endpoints]
}

resource "azurerm_private_endpoint" "artifacts" {
  name                = "pe-restsim-prod-artifacts"
  location            = var.location
  resource_group_name = azurerm_resource_group.rg-restsim-prod-network.name
  subnet_id           = azurerm_subnet.private_endpoints.id
  tags                = local.tags

  private_service_connection {
    name                           = "psc-restsim-prod-artifacts"
    private_connection_resource_id = azurerm_storage_account.artifacts.id
    subresource_names              = ["blob"]
    is_manual_connection           = false
  }

  private_dns_zone_group {
    name                 = "default"
    private_dns_zone_ids = [azurerm_private_dns_zone.artifacts.id]
  }

  depends_on = [azurerm_subnet_network_security_group_association.private_endpoints]
}
