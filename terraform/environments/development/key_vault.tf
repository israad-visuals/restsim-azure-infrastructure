resource "azurerm_key_vault" "development" {
  name                          = "kv-rs-dev-${random_string.suffix.result}"
  location                      = var.location
  resource_group_name           = azurerm_resource_group.app.name
  tenant_id                     = var.tenant_id
  sku_name                      = "standard"
  rbac_authorization_enabled    = true
  public_network_access_enabled = false
  purge_protection_enabled      = true
  soft_delete_retention_days    = 7
  tags                          = local.tags

  network_acls {
    default_action = "Deny"
    bypass         = "None"
  }
}

resource "azurerm_role_assignment" "app_secrets" {
  scope                = azurerm_key_vault.development.id
  role_definition_name = "Key Vault Secrets User"
  principal_id         = azurerm_linux_virtual_machine.app.identity[0].principal_id
}
