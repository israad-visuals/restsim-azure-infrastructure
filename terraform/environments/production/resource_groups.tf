resource "azurerm_resource_group" "rg-restsim-prod-network" {
  name     = "rg-restsim-prod-network"
  location = var.location
  tags     = local.tags
  lifecycle {
    prevent_destroy = true
  }
}

resource "azurerm_resource_group" "rg-restsim-prod-app" {
  name     = "rg-restsim-prod-app"
  location = var.location
  tags     = local.tags
  lifecycle {
    prevent_destroy = true
  }
}

resource "azurerm_resource_group" "rg-restsim-prod-monitoring" {
  name     = "rg-restsim-prod-monitoring"
  location = var.location
  tags     = local.tags
  lifecycle {
    prevent_destroy = true
  }
}

resource "azurerm_resource_group" "rg-restsim-prod-data" {
  name     = "rg-restsim-prod-data"
  location = var.location
  tags     = local.tags
  lifecycle {
    prevent_destroy = true
  }
}
