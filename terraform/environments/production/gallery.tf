resource "azurerm_user_assigned_identity" "gallery_publisher" {
  name                = "id-restsim-prod-gallery"
  location            = var.location
  resource_group_name = azurerm_resource_group.rg-restsim-prod-app.name
  tags                = local.tags
}

# AzAPI lets us attach the Gallery identity, which AzureRM 4.81 cannot do.
resource "azapi_resource" "gallery" {
  type      = "Microsoft.Compute/galleries@2024-03-03"
  name      = "gal_restsim_prod"
  parent_id = azurerm_resource_group.rg-restsim-prod-app.id
  location  = var.location
  identity {
    type         = "UserAssigned"
    identity_ids = [azurerm_user_assigned_identity.gallery_publisher.id]
  }
  body = {
    properties = {
      description = "Private RestSim app packages with version numbers"
    }
  }
  tags = local.tags
}

resource "azurerm_role_assignment" "gallery_artifact_reader" {
  scope                = azurerm_storage_account.artifacts.id
  role_definition_name = "Storage Blob Data Contributor"
  principal_id         = azurerm_user_assigned_identity.gallery_publisher.principal_id
}

resource "azurerm_gallery_application" "restsim" {
  name              = "restsim"
  gallery_id        = azapi_resource.gallery.id
  location          = var.location
  supported_os_type = "Linux"
  description       = "One RestSim app package. Web and worker roles use separate settings."
  tags              = local.tags
}

# The app pipeline builds and checks the package, then publishes a Gallery version.
# Test it in staging before setting that exact version on the VMSS.
# This code creates the Gallery app, but does not upload an app package.
