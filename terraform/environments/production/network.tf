resource "azurerm_virtual_network" "vnet-restsim-prod" {
  name                = "vnet-restsim-prod"
  location            = var.location
  resource_group_name = azurerm_resource_group.rg-restsim-prod-network.name
  address_space       = ["10.20.0.0/22"]
  tags                = local.tags
}

resource "azurerm_subnet" "app" {
  name                            = "snet-prod-app"
  resource_group_name             = azurerm_resource_group.rg-restsim-prod-network.name
  virtual_network_name            = azurerm_virtual_network.vnet-restsim-prod.name
  address_prefixes                = ["10.20.1.0/24"]
  default_outbound_access_enabled = false
}

resource "azurerm_subnet" "data" {
  name                 = "snet-prod-data"
  resource_group_name  = azurerm_resource_group.rg-restsim-prod-network.name
  virtual_network_name = azurerm_virtual_network.vnet-restsim-prod.name
  address_prefixes     = ["10.20.2.0/24"]
  service_endpoints    = ["Microsoft.Storage"]
  delegation {
    name = "postgresql-flexible-server"
    service_delegation {
      name    = "Microsoft.DBforPostgreSQL/flexibleServers"
      actions = ["Microsoft.Network/virtualNetworks/subnets/join/action"]
    }
  }
}

resource "azurerm_subnet" "private_endpoints" {
  name                              = "snet-prod-private-endpoints"
  resource_group_name               = azurerm_resource_group.rg-restsim-prod-network.name
  virtual_network_name              = azurerm_virtual_network.vnet-restsim-prod.name
  address_prefixes                  = ["10.20.3.0/24"]
  private_endpoint_network_policies = "NetworkSecurityGroupEnabled"
}

resource "azurerm_private_dns_zone" "postgres" {
  name                = "prod.postgres.database.azure.com"
  resource_group_name = azurerm_resource_group.rg-restsim-prod-network.name
  tags                = local.tags
}

resource "azurerm_private_dns_zone_virtual_network_link" "postgres" {
  name                  = "link-restsim-prod-postgres"
  resource_group_name   = azurerm_resource_group.rg-restsim-prod-network.name
  private_dns_zone_name = azurerm_private_dns_zone.postgres.name
  virtual_network_id    = azurerm_virtual_network.vnet-restsim-prod.id
  registration_enabled  = false
  tags                  = local.tags
}

resource "azurerm_private_dns_zone" "files" {
  name                = "privatelink.file.core.windows.net"
  resource_group_name = azurerm_resource_group.rg-restsim-prod-network.name
  tags                = local.tags
}

resource "azurerm_private_dns_zone_virtual_network_link" "files" {
  name                  = "link-restsim-prod-files"
  resource_group_name   = azurerm_resource_group.rg-restsim-prod-network.name
  private_dns_zone_name = azurerm_private_dns_zone.files.name
  virtual_network_id    = azurerm_virtual_network.vnet-restsim-prod.id
  registration_enabled  = false
  tags                  = local.tags
}

resource "azurerm_private_dns_zone" "vault" {
  name                = "privatelink.vaultcore.azure.net"
  resource_group_name = azurerm_resource_group.rg-restsim-prod-network.name
  tags                = local.tags
}

resource "azurerm_private_dns_zone_virtual_network_link" "vault" {
  name                  = "link-restsim-prod-vault"
  resource_group_name   = azurerm_resource_group.rg-restsim-prod-network.name
  private_dns_zone_name = azurerm_private_dns_zone.vault.name
  virtual_network_id    = azurerm_virtual_network.vnet-restsim-prod.id
  registration_enabled  = false
  tags                  = local.tags
}

resource "azurerm_private_dns_zone" "redis" {
  name                = "privatelink.redis.azure.net"
  resource_group_name = azurerm_resource_group.rg-restsim-prod-network.name
  tags                = local.tags
}

resource "azurerm_private_dns_zone_virtual_network_link" "redis" {
  name                  = "link-restsim-prod-redis"
  resource_group_name   = azurerm_resource_group.rg-restsim-prod-network.name
  private_dns_zone_name = azurerm_private_dns_zone.redis.name
  virtual_network_id    = azurerm_virtual_network.vnet-restsim-prod.id
  registration_enabled  = false
  tags                  = local.tags
}

resource "azurerm_private_dns_zone" "artifacts" {
  name                = "privatelink.blob.core.windows.net"
  resource_group_name = azurerm_resource_group.rg-restsim-prod-network.name
  tags                = local.tags
}

resource "azurerm_private_dns_zone_virtual_network_link" "artifacts" {
  name                  = "link-restsim-prod-artifacts"
  resource_group_name   = azurerm_resource_group.rg-restsim-prod-network.name
  private_dns_zone_name = azurerm_private_dns_zone.artifacts.name
  virtual_network_id    = azurerm_virtual_network.vnet-restsim-prod.id
  registration_enabled  = false
  tags                  = local.tags
}

resource "azurerm_public_ip" "ingress" {
  name                = "pip-restsim-prod-ingress"
  location            = var.location
  resource_group_name = azurerm_resource_group.rg-restsim-prod-network.name
  allocation_method   = "Static"
  sku                 = "Standard"
  zones               = ["1", "2", "3"]
  tags                = local.tags
}

resource "azurerm_lb" "production" {
  name                = "lb-restsim-prod"
  location            = var.location
  resource_group_name = azurerm_resource_group.rg-restsim-prod-network.name
  sku                 = "Standard"
  frontend_ip_configuration {
    name                 = "https"
    public_ip_address_id = azurerm_public_ip.ingress.id
  }
  tags = local.tags
}

resource "azurerm_lb_backend_address_pool" "web" {
  name            = "restsim-web"
  loadbalancer_id = azurerm_lb.production.id
}

resource "azurerm_lb_probe" "readiness" {
  name                = "restsim-readiness"
  loadbalancer_id     = azurerm_lb.production.id
  protocol            = "Http"
  port                = var.readiness_port
  request_path        = var.readiness_path
  interval_in_seconds = 15
  number_of_probes    = 2
}

resource "azurerm_lb_rule" "https" {
  name                           = "https-tls-pass-through"
  loadbalancer_id                = azurerm_lb.production.id
  frontend_ip_configuration_name = "https"
  protocol                       = "Tcp"
  frontend_port                  = 443
  backend_port                   = 443
  backend_address_pool_ids       = [azurerm_lb_backend_address_pool.web.id]
  probe_id                       = azurerm_lb_probe.readiness.id
  disable_outbound_snat          = true
  tcp_reset_enabled              = true
  idle_timeout_in_minutes        = 15
  load_distribution              = "Default"
}

resource "azurerm_lb_rule" "http_redirect" {
  name                           = "http-to-apache-redirect"
  loadbalancer_id                = azurerm_lb.production.id
  frontend_ip_configuration_name = "https"
  protocol                       = "Tcp"
  frontend_port                  = 80
  backend_port                   = 80
  backend_address_pool_ids       = [azurerm_lb_backend_address_pool.web.id]
  probe_id                       = azurerm_lb_probe.readiness.id
  disable_outbound_snat          = true
  tcp_reset_enabled              = true
  idle_timeout_in_minutes        = 4
}

resource "azurerm_public_ip" "egress" {
  name                = "pip-restsim-prod-egress"
  location            = var.location
  resource_group_name = azurerm_resource_group.rg-restsim-prod-network.name
  allocation_method   = "Static"
  sku                 = "StandardV2"
  tags                = local.tags
}

resource "azurerm_nat_gateway" "production" {
  name                    = "nat-restsim-prod"
  location                = var.location
  resource_group_name     = azurerm_resource_group.rg-restsim-prod-network.name
  sku_name                = "StandardV2"
  idle_timeout_in_minutes = 10
  tags                    = local.tags
}

resource "azurerm_nat_gateway_public_ip_association" "production" {
  nat_gateway_id       = azurerm_nat_gateway.production.id
  public_ip_address_id = azurerm_public_ip.egress.id
}

resource "azurerm_subnet_nat_gateway_association" "app" {
  subnet_id      = azurerm_subnet.app.id
  nat_gateway_id = azurerm_nat_gateway.production.id
}
