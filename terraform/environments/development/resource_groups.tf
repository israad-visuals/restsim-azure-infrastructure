locals {
  tags = {
    project     = "RestSim"
    environment = "development"
    owner       = var.owner
    managed_by  = "Terraform"
    data        = "synthetic"
  }
}

resource "random_string" "suffix" {
  length  = 6
  lower   = true
  upper   = false
  numeric = true
  special = false
}

resource "azurerm_resource_group" "network" {
  name     = "rg-restsim-dev-network"
  location = var.location
  tags     = local.tags
}

resource "azurerm_resource_group" "app" {
  name     = "rg-restsim-dev-app"
  location = var.location
  tags     = local.tags
}

resource "azurerm_resource_group" "data" {
  name     = "rg-restsim-dev-data"
  location = var.location
  tags     = local.tags
}

resource "azurerm_resource_group" "monitoring" {
  name     = "rg-restsim-dev-monitoring"
  location = var.location
  tags     = local.tags
}
