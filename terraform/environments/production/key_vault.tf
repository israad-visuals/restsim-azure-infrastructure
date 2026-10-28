resource "azurerm_key_vault" "production" {
  name                          = "kv-restsim-prod-${local.suffix}"
  location                      = var.location
  resource_group_name           = azurerm_resource_group.rg-restsim-prod-app.name
  tenant_id                     = var.tenant_id
  sku_name                      = "standard"
  rbac_authorization_enabled    = true
  public_network_access_enabled = false
  purge_protection_enabled      = true
  soft_delete_retention_days    = 90
  network_acls {
    default_action = "Deny"
    bypass         = "None"
  }
  tags = local.tags
  lifecycle {
    prevent_destroy = true
  }
}

resource "azurerm_role_assignment" "terraform_secret_writer" {
  scope                = azurerm_key_vault.production.id
  role_definition_name = "Key Vault Secrets Officer"
  principal_id         = var.deployment_operator_object_id
}

resource "azurerm_key_vault_secret" "postgres_admin_password" {
  name         = "postgres-admin-password"
  value        = random_password.postgres_admin.result
  key_vault_id = azurerm_key_vault.production.id
  tags         = local.tags

  depends_on = [
    azurerm_role_assignment.terraform_secret_writer,
    azurerm_private_endpoint.files,
    azurerm_private_endpoint.vault,
    azurerm_private_endpoint.redis,
    azurerm_private_endpoint.artifacts,
    azurerm_private_dns_zone_virtual_network_link.postgres,
    azurerm_private_dns_zone_virtual_network_link.files,
    azurerm_private_dns_zone_virtual_network_link.vault,
    azurerm_private_dns_zone_virtual_network_link.redis,
    azurerm_private_dns_zone_virtual_network_link.artifacts
  ]
}

resource "azurerm_key_vault_secret" "postgres_application_username" {
  name         = "postgres-application-username"
  value        = var.postgres_application_username
  key_vault_id = azurerm_key_vault.production.id
  tags         = local.tags

  depends_on = [
    azurerm_role_assignment.terraform_secret_writer,
    azurerm_private_endpoint.files,
    azurerm_private_endpoint.vault,
    azurerm_private_endpoint.redis,
    azurerm_private_endpoint.artifacts,
    azurerm_private_dns_zone_virtual_network_link.postgres,
    azurerm_private_dns_zone_virtual_network_link.files,
    azurerm_private_dns_zone_virtual_network_link.vault,
    azurerm_private_dns_zone_virtual_network_link.redis,
    azurerm_private_dns_zone_virtual_network_link.artifacts
  ]
}

resource "azurerm_key_vault_secret" "postgres_application_password" {
  name         = "postgres-application-password"
  value        = var.postgres_application_password
  key_vault_id = azurerm_key_vault.production.id
  tags         = local.tags

  depends_on = [
    azurerm_role_assignment.terraform_secret_writer,
    azurerm_private_endpoint.files,
    azurerm_private_endpoint.vault,
    azurerm_private_endpoint.redis,
    azurerm_private_endpoint.artifacts,
    azurerm_private_dns_zone_virtual_network_link.postgres,
    azurerm_private_dns_zone_virtual_network_link.files,
    azurerm_private_dns_zone_virtual_network_link.vault,
    azurerm_private_dns_zone_virtual_network_link.redis,
    azurerm_private_dns_zone_virtual_network_link.artifacts
  ]
}

resource "azurerm_key_vault_secret" "azure_files_account_key" {
  name         = "azure-files-account-key"
  value        = azurerm_storage_account.files.primary_access_key
  key_vault_id = azurerm_key_vault.production.id
  tags         = local.tags

  depends_on = [
    azurerm_role_assignment.terraform_secret_writer,
    azurerm_private_endpoint.files,
    azurerm_private_endpoint.vault,
    azurerm_private_endpoint.redis,
    azurerm_private_endpoint.artifacts,
    azurerm_private_dns_zone_virtual_network_link.postgres,
    azurerm_private_dns_zone_virtual_network_link.files,
    azurerm_private_dns_zone_virtual_network_link.vault,
    azurerm_private_dns_zone_virtual_network_link.redis,
    azurerm_private_dns_zone_virtual_network_link.artifacts
  ]
}

resource "azurerm_key_vault_secret" "redis_session_key" {
  name         = "redis-session-key"
  value        = azurerm_managed_redis.sessions.default_database[0].primary_access_key
  key_vault_id = azurerm_key_vault.production.id
  tags         = local.tags

  depends_on = [
    azurerm_role_assignment.terraform_secret_writer,
    azurerm_private_endpoint.files,
    azurerm_private_endpoint.vault,
    azurerm_private_endpoint.redis,
    azurerm_private_endpoint.artifacts,
    azurerm_private_dns_zone_virtual_network_link.postgres,
    azurerm_private_dns_zone_virtual_network_link.files,
    azurerm_private_dns_zone_virtual_network_link.vault,
    azurerm_private_dns_zone_virtual_network_link.redis,
    azurerm_private_dns_zone_virtual_network_link.artifacts
  ]
}

resource "azurerm_key_vault_secret" "origin_tls_certificate" {
  count        = var.install_application ? 1 : 0
  name         = "origin-tls-certificate"
  value        = var.origin_tls_certificate_pem
  key_vault_id = azurerm_key_vault.production.id
  tags         = local.tags

  depends_on = [
    azurerm_role_assignment.terraform_secret_writer,
    azurerm_private_endpoint.files,
    azurerm_private_endpoint.vault,
    azurerm_private_endpoint.redis,
    azurerm_private_endpoint.artifacts,
    azurerm_private_dns_zone_virtual_network_link.postgres,
    azurerm_private_dns_zone_virtual_network_link.files,
    azurerm_private_dns_zone_virtual_network_link.vault,
    azurerm_private_dns_zone_virtual_network_link.redis,
    azurerm_private_dns_zone_virtual_network_link.artifacts
  ]
}

resource "azurerm_key_vault_secret" "origin_tls_private_key" {
  count        = var.install_application ? 1 : 0
  name         = "origin-tls-private-key"
  value        = var.origin_tls_private_key_pem
  key_vault_id = azurerm_key_vault.production.id
  tags         = local.tags

  depends_on = [
    azurerm_role_assignment.terraform_secret_writer,
    azurerm_private_endpoint.files,
    azurerm_private_endpoint.vault,
    azurerm_private_endpoint.redis,
    azurerm_private_endpoint.artifacts,
    azurerm_private_dns_zone_virtual_network_link.postgres,
    azurerm_private_dns_zone_virtual_network_link.files,
    azurerm_private_dns_zone_virtual_network_link.vault,
    azurerm_private_dns_zone_virtual_network_link.redis,
    azurerm_private_dns_zone_virtual_network_link.artifacts
  ]
}

resource "azurerm_key_vault_secret" "cloudflare_origin_pull_ca" {
  count        = var.require_authenticated_origin_pulls ? 1 : 0
  name         = "cloudflare-origin-pull-ca"
  value        = var.cloudflare_origin_pull_ca_pem
  key_vault_id = azurerm_key_vault.production.id
  tags         = local.tags

  depends_on = [
    azurerm_role_assignment.terraform_secret_writer,
    azurerm_private_endpoint.files,
    azurerm_private_endpoint.vault,
    azurerm_private_endpoint.redis,
    azurerm_private_endpoint.artifacts,
    azurerm_private_dns_zone_virtual_network_link.postgres,
    azurerm_private_dns_zone_virtual_network_link.files,
    azurerm_private_dns_zone_virtual_network_link.vault,
    azurerm_private_dns_zone_virtual_network_link.redis,
    azurerm_private_dns_zone_virtual_network_link.artifacts
  ]
}

resource "azurerm_key_vault_secret" "application_insights_connection_string" {
  name         = "application-insights-connection-string"
  value        = azurerm_application_insights.production.connection_string
  key_vault_id = azurerm_key_vault.production.id
  tags         = local.tags

  depends_on = [
    azurerm_role_assignment.terraform_secret_writer,
    azurerm_private_endpoint.files,
    azurerm_private_endpoint.vault,
    azurerm_private_endpoint.redis,
    azurerm_private_endpoint.artifacts,
    azurerm_private_dns_zone_virtual_network_link.postgres,
    azurerm_private_dns_zone_virtual_network_link.files,
    azurerm_private_dns_zone_virtual_network_link.vault,
    azurerm_private_dns_zone_virtual_network_link.redis,
    azurerm_private_dns_zone_virtual_network_link.artifacts
  ]
}

resource "azurerm_key_vault_secret" "application" {
  for_each     = toset(nonsensitive(keys(var.application_secrets)))
  name         = each.key
  value        = var.application_secrets[each.key]
  key_vault_id = azurerm_key_vault.production.id
  tags         = local.tags
  depends_on = [
    azurerm_role_assignment.terraform_secret_writer,
    azurerm_private_endpoint.files,
    azurerm_private_endpoint.vault,
    azurerm_private_endpoint.redis,
    azurerm_private_endpoint.artifacts
  ]
}
