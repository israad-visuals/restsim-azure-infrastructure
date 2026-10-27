resource "azurerm_virtual_network" "development" {
  name                = "vnet-restsim-dev"
  location            = var.location
  resource_group_name = azurerm_resource_group.network.name
  address_space       = ["10.30.0.0/22"]
  tags                = local.tags
}

resource "azurerm_subnet" "app" {
  name                            = "snet-dev-app"
  resource_group_name             = azurerm_resource_group.network.name
  virtual_network_name            = azurerm_virtual_network.development.name
  address_prefixes                = ["10.30.1.0/24"]
  default_outbound_access_enabled = false
}

resource "azurerm_subnet" "data" {
  name                            = "snet-dev-data"
  resource_group_name             = azurerm_resource_group.network.name
  virtual_network_name            = azurerm_virtual_network.development.name
  address_prefixes                = ["10.30.2.0/24"]
  default_outbound_access_enabled = false
  service_endpoints               = ["Microsoft.Storage"]

  delegation {
    name = "postgresql"
    service_delegation {
      name    = "Microsoft.DBforPostgreSQL/flexibleServers"
      actions = ["Microsoft.Network/virtualNetworks/subnets/join/action"]
    }
  }
}

resource "azurerm_subnet" "private_endpoints" {
  name                              = "snet-dev-private-endpoints"
  resource_group_name               = azurerm_resource_group.network.name
  virtual_network_name              = azurerm_virtual_network.development.name
  address_prefixes                  = ["10.30.3.0/24"]
  default_outbound_access_enabled   = false
  private_endpoint_network_policies = "NetworkSecurityGroupEnabled"
}

locals {
  private_dns_zones = {
    postgres = "dev.postgres.database.azure.com"
    files    = "privatelink.file.core.windows.net"
    vault    = "privatelink.vaultcore.azure.net"
  }
}

resource "azurerm_private_dns_zone" "development" {
  for_each            = local.private_dns_zones
  name                = each.value
  resource_group_name = azurerm_resource_group.network.name
  tags                = local.tags
}

resource "azurerm_private_dns_zone_virtual_network_link" "development" {
  for_each              = local.private_dns_zones
  name                  = "link-restsim-dev-${each.key}"
  resource_group_name   = azurerm_resource_group.network.name
  private_dns_zone_name = azurerm_private_dns_zone.development[each.key].name
  virtual_network_id    = azurerm_virtual_network.development.id
  registration_enabled  = false
  tags                  = local.tags
}

resource "azurerm_public_ip" "staging" {
  name                = "pip-restsim-dev-staging"
  location            = var.location
  resource_group_name = azurerm_resource_group.network.name
  allocation_method   = "Static"
  sku                 = "Standard"
  tags                = local.tags
}

resource "azurerm_dns_zone" "staging" {
  count               = var.staging_zone_name == null ? 0 : 1
  name                = var.staging_zone_name
  resource_group_name = azurerm_resource_group.network.name
  tags                = local.tags
}

resource "azurerm_dns_a_record" "staging" {
  count               = var.staging_zone_name == null ? 0 : 1
  name                = "@"
  zone_name           = azurerm_dns_zone.staging[0].name
  resource_group_name = azurerm_resource_group.network.name
  ttl                 = 300
  records             = [azurerm_public_ip.staging.ip_address]
}
