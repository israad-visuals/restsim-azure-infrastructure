resource "azurerm_storage_account" "files" {
  name                            = "strsdevfiles${random_string.suffix.result}"
  location                        = var.location
  resource_group_name             = azurerm_resource_group.data.name
  account_tier                    = "Standard"
  account_kind                    = "StorageV2"
  account_replication_type        = "LRS"
  min_tls_version                 = "TLS1_2"
  https_traffic_only_enabled      = true
  public_network_access_enabled   = false
  allow_nested_items_to_be_public = false
  shared_access_key_enabled       = true
  tags                            = local.tags

  network_rules {
    default_action = "Deny"
    bypass         = ["None"]
  }
  share_properties {
    retention_policy {
      days = 7
    }
    smb {
      versions                = ["SMB3.1.1"]
      authentication_types    = ["NTLMv2"]
      channel_encryption_type = ["AES-256-GCM"]
    }
  }
}

resource "azurerm_storage_share" "application" {
  name               = "restsim-dev-files"
  storage_account_id = azurerm_storage_account.files.id
  quota              = 10
  enabled_protocol   = "SMB"
  access_tier        = "TransactionOptimized"
}

locals {
  private_services = {
    files = { id = azurerm_storage_account.files.id, subresource = "file" }
    vault = { id = azurerm_key_vault.development.id, subresource = "vault" }
  }
}

resource "azurerm_private_endpoint" "development" {
  for_each            = local.private_services
  name                = "pe-restsim-dev-${each.key}"
  location            = var.location
  resource_group_name = azurerm_resource_group.network.name
  subnet_id           = azurerm_subnet.private_endpoints.id
  tags                = local.tags

  private_service_connection {
    name                           = "psc-restsim-dev-${each.key}"
    private_connection_resource_id = each.value.id
    subresource_names              = [each.value.subresource]
    is_manual_connection           = false
  }
  private_dns_zone_group {
    name                 = "default"
    private_dns_zone_ids = [azurerm_private_dns_zone.development[each.key].id]
  }
  depends_on = [azurerm_subnet_network_security_group_association.private_endpoints]
}
