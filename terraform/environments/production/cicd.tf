# Reuse the existing RestSim pipeline. These are Azure identities, not new workflows.
# Copy each exact OIDC subject from the correct GitHub job settings.

resource "azurerm_user_assigned_identity" "github_infrastructure" {
  count               = var.enable_github_oidc ? 1 : 0
  name                = "id-restsim-prod-infrastructure"
  location            = var.location
  resource_group_name = azurerm_resource_group.rg-restsim-prod-app.name
  tags                = local.tags
}

resource "azurerm_federated_identity_credential" "github_infrastructure" {
  count                     = var.enable_github_oidc ? 1 : 0
  name                      = "github-infrastructure"
  user_assigned_identity_id = azurerm_user_assigned_identity.github_infrastructure[0].id
  audience                  = ["api://AzureADTokenExchange"]
  issuer                    = "https://token.actions.githubusercontent.com"
  subject                   = var.github_infrastructure_oidc_subject
}

resource "azurerm_user_assigned_identity" "github_publisher" {
  count               = var.enable_github_oidc ? 1 : 0
  name                = "id-restsim-prod-publisher"
  location            = var.location
  resource_group_name = azurerm_resource_group.rg-restsim-prod-app.name
  tags                = local.tags
}

resource "azurerm_federated_identity_credential" "github_publisher" {
  count                     = var.enable_github_oidc ? 1 : 0
  name                      = "github-publisher"
  user_assigned_identity_id = azurerm_user_assigned_identity.github_publisher[0].id
  audience                  = ["api://AzureADTokenExchange"]
  issuer                    = "https://token.actions.githubusercontent.com"
  subject                   = var.github_publisher_oidc_subject
}

resource "azurerm_user_assigned_identity" "github_release" {
  count               = var.enable_github_oidc ? 1 : 0
  name                = "id-restsim-prod-release"
  location            = var.location
  resource_group_name = azurerm_resource_group.rg-restsim-prod-app.name
  tags                = local.tags
}

resource "azurerm_federated_identity_credential" "github_release" {
  count                     = var.enable_github_oidc ? 1 : 0
  name                      = "github-release"
  user_assigned_identity_id = azurerm_user_assigned_identity.github_release[0].id
  audience                  = ["api://AzureADTokenExchange"]
  issuer                    = "https://token.actions.githubusercontent.com"
  subject                   = var.github_release_oidc_subject
}

# Contributor can manage resources, but cannot grant roles or change policies.

resource "azurerm_role_assignment" "github_infrastructure_network" {
  count                = var.enable_github_oidc ? 1 : 0
  scope                = azurerm_resource_group.rg-restsim-prod-network.id
  role_definition_name = "Contributor"
  principal_id         = azurerm_user_assigned_identity.github_infrastructure[0].principal_id
}

resource "azurerm_role_assignment" "github_infrastructure_app" {
  count                = var.enable_github_oidc ? 1 : 0
  scope                = azurerm_resource_group.rg-restsim-prod-app.id
  role_definition_name = "Contributor"
  principal_id         = azurerm_user_assigned_identity.github_infrastructure[0].principal_id
}

resource "azurerm_role_assignment" "github_infrastructure_data" {
  count                = var.enable_github_oidc ? 1 : 0
  scope                = azurerm_resource_group.rg-restsim-prod-data.id
  role_definition_name = "Contributor"
  principal_id         = azurerm_user_assigned_identity.github_infrastructure[0].principal_id
}

resource "azurerm_role_assignment" "github_infrastructure_monitoring" {
  count                = var.enable_github_oidc ? 1 : 0
  scope                = azurerm_resource_group.rg-restsim-prod-monitoring.id
  role_definition_name = "Contributor"
  principal_id         = azurerm_user_assigned_identity.github_infrastructure[0].principal_id
}

resource "azurerm_role_assignment" "github_state" {
  count                = var.enable_github_oidc && var.terraform_state_container_id != null ? 1 : 0
  scope                = var.terraform_state_container_id
  role_definition_name = "Storage Blob Data Contributor"
  principal_id         = azurerm_user_assigned_identity.github_infrastructure[0].principal_id
}

# Contributor alone cannot read or write Key Vault secrets.
resource "azurerm_role_assignment" "github_infrastructure_secrets" {
  count                = var.enable_github_oidc ? 1 : 0
  scope                = azurerm_key_vault.production.id
  role_definition_name = "Key Vault Secrets Officer"
  principal_id         = azurerm_user_assigned_identity.github_infrastructure[0].principal_id
}

resource "azurerm_role_assignment" "github_publisher_blob" {
  count                = var.enable_github_oidc ? 1 : 0
  scope                = azurerm_storage_container.releases.id
  role_definition_name = "Storage Blob Data Contributor"
  principal_id         = azurerm_user_assigned_identity.github_publisher[0].principal_id
}

resource "azurerm_role_assignment" "github_publisher_gallery" {
  count                = var.enable_github_oidc ? 1 : 0
  scope                = azapi_resource.gallery.id
  role_definition_name = "Contributor"
  principal_id         = azurerm_user_assigned_identity.github_publisher[0].principal_id
}

resource "azurerm_role_assignment" "github_web_release" {
  count                = var.enable_github_oidc && var.deploy_compute ? 1 : 0
  scope                = azurerm_linux_virtual_machine_scale_set.web[0].id
  role_definition_name = "Virtual Machine Contributor"
  principal_id         = azurerm_user_assigned_identity.github_release[0].principal_id
}

resource "azurerm_role_assignment" "github_worker_release" {
  count                = var.enable_github_oidc && var.deploy_compute ? 1 : 0
  scope                = azurerm_linux_virtual_machine.worker[0].id
  role_definition_name = "Virtual Machine Contributor"
  principal_id         = azurerm_user_assigned_identity.github_release[0].principal_id
}

resource "azurerm_role_assignment" "github_release_gallery_reader" {
  count                = var.enable_github_oidc ? 1 : 0
  scope                = azapi_resource.gallery.id
  role_definition_name = "Reader"
  principal_id         = azurerm_user_assigned_identity.github_release[0].principal_id
}
