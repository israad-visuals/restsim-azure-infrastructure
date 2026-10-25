# Keep this existing Terraform name so its resource address stays the same.
resource "azurerm_network_security_group" "nsg_rg-restsim-prod-network" {
  name                = "nsg-prod-app"
  location            = var.location
  resource_group_name = azurerm_resource_group.rg-restsim-prod-network.name
  tags                = local.tags
}
resource "azurerm_network_security_group" "data" {
  name                = "nsg-prod-data"
  location            = var.location
  resource_group_name = azurerm_resource_group.rg-restsim-prod-network.name
  tags                = local.tags
}
resource "azurerm_network_security_group" "private_endpoints" {
  name                = "nsg-prod-private-endpoints"
  location            = var.location
  resource_group_name = azurerm_resource_group.rg-restsim-prod-network.name
  tags                = local.tags
}
resource "azurerm_subnet_network_security_group_association" "app" {
  subnet_id                 = azurerm_subnet.app.id
  network_security_group_id = azurerm_network_security_group.nsg_rg-restsim-prod-network.id
}
resource "azurerm_subnet_network_security_group_association" "data" {
  subnet_id                 = azurerm_subnet.data.id
  network_security_group_id = azurerm_network_security_group.data.id
}
resource "azurerm_subnet_network_security_group_association" "private_endpoints" {
  subnet_id                 = azurerm_subnet.private_endpoints.id
  network_security_group_id = azurerm_network_security_group.private_endpoints.id
}

# These rules allow only the connections the application needs.
# The deny rules at the end block other traffic.

# Application subnet

resource "azurerm_network_security_rule" "app_cloudflare" {
  name                        = "app-cloudflare"
  priority                    = 110
  direction                   = "Inbound"
  access                      = "Allow"
  protocol                    = "Tcp"
  source_port_range           = "*"
  destination_port_ranges     = ["80", "443"]
  source_address_prefixes     = var.cloudflare_ipv4_cidrs
  destination_address_prefix  = "10.20.1.0/24"
  resource_group_name         = azurerm_resource_group.rg-restsim-prod-network.name
  network_security_group_name = azurerm_network_security_group.nsg_rg-restsim-prod-network.name
}

resource "azurerm_network_security_rule" "app_readiness" {
  name                        = "app-readiness"
  priority                    = 100
  direction                   = "Inbound"
  access                      = "Allow"
  protocol                    = "Tcp"
  source_port_range           = "*"
  destination_port_range      = tostring(var.readiness_port)
  source_address_prefix       = "AzureLoadBalancer"
  destination_address_prefix  = "10.20.1.0/24"
  resource_group_name         = azurerm_resource_group.rg-restsim-prod-network.name
  network_security_group_name = azurerm_network_security_group.nsg_rg-restsim-prod-network.name
}

resource "azurerm_network_security_rule" "app_postgres" {
  name                        = "app-postgres"
  priority                    = 100
  direction                   = "Outbound"
  access                      = "Allow"
  protocol                    = "Tcp"
  source_port_range           = "*"
  destination_port_range      = "5432"
  source_address_prefix       = "10.20.1.0/24"
  destination_address_prefix  = "10.20.2.0/24"
  resource_group_name         = azurerm_resource_group.rg-restsim-prod-network.name
  network_security_group_name = azurerm_network_security_group.nsg_rg-restsim-prod-network.name
}

resource "azurerm_network_security_rule" "app_private_services" {
  name                        = "app-private-services"
  priority                    = 110
  direction                   = "Outbound"
  access                      = "Allow"
  protocol                    = "Tcp"
  source_port_range           = "*"
  destination_port_ranges     = ["443", "445", "10000"]
  source_address_prefix       = "10.20.1.0/24"
  destination_address_prefix  = "10.20.3.0/24"
  resource_group_name         = azurerm_resource_group.rg-restsim-prod-network.name
  network_security_group_name = azurerm_network_security_group.nsg_rg-restsim-prod-network.name
}

resource "azurerm_network_security_rule" "app_azure_control" {
  name                        = "app-azure-control"
  priority                    = 130
  direction                   = "Outbound"
  access                      = "Allow"
  protocol                    = "Tcp"
  source_port_range           = "*"
  destination_port_range      = "443"
  source_address_prefix       = "10.20.1.0/24"
  destination_address_prefix  = "AzureCloud"
  resource_group_name         = azurerm_resource_group.rg-restsim-prod-network.name
  network_security_group_name = azurerm_network_security_group.nsg_rg-restsim-prod-network.name
}

resource "azurerm_network_security_rule" "app_cloudflare_jwks" {
  name                         = "app-cloudflare-jwks"
  priority                     = 170
  direction                    = "Outbound"
  access                       = "Allow"
  protocol                     = "Tcp"
  source_port_range            = "*"
  destination_port_range       = "443"
  source_address_prefix        = "10.20.1.0/24"
  destination_address_prefixes = var.cloudflare_ipv4_cidrs
  resource_group_name          = azurerm_resource_group.rg-restsim-prod-network.name
  network_security_group_name  = azurerm_network_security_group.nsg_rg-restsim-prod-network.name
}

resource "azurerm_network_security_rule" "app_dns_udp" {
  name                        = "app-dns-udp"
  priority                    = 140
  direction                   = "Outbound"
  access                      = "Allow"
  protocol                    = "Udp"
  source_port_range           = "*"
  destination_port_range      = "53"
  source_address_prefix       = "10.20.1.0/24"
  destination_address_prefix  = "AzurePlatformDNS"
  resource_group_name         = azurerm_resource_group.rg-restsim-prod-network.name
  network_security_group_name = azurerm_network_security_group.nsg_rg-restsim-prod-network.name
}

resource "azurerm_network_security_rule" "app_dns_tcp" {
  name                        = "app-dns-tcp"
  priority                    = 150
  direction                   = "Outbound"
  access                      = "Allow"
  protocol                    = "Tcp"
  source_port_range           = "*"
  destination_port_range      = "53"
  source_address_prefix       = "10.20.1.0/24"
  destination_address_prefix  = "AzurePlatformDNS"
  resource_group_name         = azurerm_resource_group.rg-restsim-prod-network.name
  network_security_group_name = azurerm_network_security_group.nsg_rg-restsim-prod-network.name
}

resource "azurerm_network_security_rule" "app_private_admin" {
  count                       = length(var.private_management_cidrs) > 0 ? 1 : 0
  name                        = "app-private-admin"
  priority                    = 120
  direction                   = "Inbound"
  access                      = "Allow"
  protocol                    = "Tcp"
  source_port_range           = "*"
  destination_port_range      = "22"
  source_address_prefixes     = var.private_management_cidrs
  destination_address_prefix  = "10.20.1.0/24"
  resource_group_name         = azurerm_resource_group.rg-restsim-prod-network.name
  network_security_group_name = azurerm_network_security_group.nsg_rg-restsim-prod-network.name
}

resource "azurerm_network_security_rule" "app_approved_https" {
  count                        = length(var.approved_outbound_https_cidrs) > 0 ? 1 : 0
  name                         = "app-approved-https"
  priority                     = 160
  direction                    = "Outbound"
  access                       = "Allow"
  protocol                     = "Tcp"
  source_port_range            = "*"
  destination_port_range       = "443"
  source_address_prefix        = "10.20.1.0/24"
  destination_address_prefixes = var.approved_outbound_https_cidrs
  resource_group_name          = azurerm_resource_group.rg-restsim-prod-network.name
  network_security_group_name  = azurerm_network_security_group.nsg_rg-restsim-prod-network.name
}

resource "azurerm_network_security_rule" "app_deny_in" {
  name                        = "app-deny-in"
  priority                    = 4096
  direction                   = "Inbound"
  access                      = "Deny"
  protocol                    = "*"
  source_port_range           = "*"
  destination_port_range      = "*"
  source_address_prefix       = "*"
  destination_address_prefix  = "*"
  resource_group_name         = azurerm_resource_group.rg-restsim-prod-network.name
  network_security_group_name = azurerm_network_security_group.nsg_rg-restsim-prod-network.name
}

resource "azurerm_network_security_rule" "app_deny_out" {
  name                        = "app-deny-out"
  priority                    = 4096
  direction                   = "Outbound"
  access                      = "Deny"
  protocol                    = "*"
  source_port_range           = "*"
  destination_port_range      = "*"
  source_address_prefix       = "*"
  destination_address_prefix  = "*"
  resource_group_name         = azurerm_resource_group.rg-restsim-prod-network.name
  network_security_group_name = azurerm_network_security_group.nsg_rg-restsim-prod-network.name
}

# Database subnet

resource "azurerm_network_security_rule" "data_app" {
  name                        = "data-app"
  priority                    = 100
  direction                   = "Inbound"
  access                      = "Allow"
  protocol                    = "Tcp"
  source_port_range           = "*"
  destination_port_range      = "5432"
  source_address_prefix       = "10.20.1.0/24"
  destination_address_prefix  = "10.20.2.0/24"
  resource_group_name         = azurerm_resource_group.rg-restsim-prod-network.name
  network_security_group_name = azurerm_network_security_group.data.name
}

resource "azurerm_network_security_rule" "data_ha_in" {
  name                        = "data-ha-in"
  priority                    = 110
  direction                   = "Inbound"
  access                      = "Allow"
  protocol                    = "Tcp"
  source_port_range           = "*"
  destination_port_range      = "5432"
  source_address_prefix       = "10.20.2.0/24"
  destination_address_prefix  = "10.20.2.0/24"
  resource_group_name         = azurerm_resource_group.rg-restsim-prod-network.name
  network_security_group_name = azurerm_network_security_group.data.name
}

resource "azurerm_network_security_rule" "data_ha_out" {
  name                        = "data-ha-out"
  priority                    = 100
  direction                   = "Outbound"
  access                      = "Allow"
  protocol                    = "Tcp"
  source_port_range           = "*"
  destination_port_range      = "5432"
  source_address_prefix       = "10.20.2.0/24"
  destination_address_prefix  = "10.20.2.0/24"
  resource_group_name         = azurerm_resource_group.rg-restsim-prod-network.name
  network_security_group_name = azurerm_network_security_group.data.name
}

resource "azurerm_network_security_rule" "data_storage" {
  name                        = "data-storage"
  priority                    = 110
  direction                   = "Outbound"
  access                      = "Allow"
  protocol                    = "Tcp"
  source_port_range           = "*"
  destination_port_range      = "443"
  source_address_prefix       = "10.20.2.0/24"
  destination_address_prefix  = "Storage"
  resource_group_name         = azurerm_resource_group.rg-restsim-prod-network.name
  network_security_group_name = azurerm_network_security_group.data.name
}

resource "azurerm_network_security_rule" "data_entra" {
  name                        = "data-entra"
  priority                    = 120
  direction                   = "Outbound"
  access                      = "Allow"
  protocol                    = "Tcp"
  source_port_range           = "*"
  destination_port_range      = "443"
  source_address_prefix       = "10.20.2.0/24"
  destination_address_prefix  = "AzureActiveDirectory"
  resource_group_name         = azurerm_resource_group.rg-restsim-prod-network.name
  network_security_group_name = azurerm_network_security_group.data.name
}

resource "azurerm_network_security_rule" "data_dns_udp" {
  name                        = "data-dns-udp"
  priority                    = 130
  direction                   = "Outbound"
  access                      = "Allow"
  protocol                    = "Udp"
  source_port_range           = "*"
  destination_port_range      = "53"
  source_address_prefix       = "10.20.2.0/24"
  destination_address_prefix  = "AzurePlatformDNS"
  resource_group_name         = azurerm_resource_group.rg-restsim-prod-network.name
  network_security_group_name = azurerm_network_security_group.data.name
}

resource "azurerm_network_security_rule" "data_dns_tcp" {
  name                        = "data-dns-tcp"
  priority                    = 140
  direction                   = "Outbound"
  access                      = "Allow"
  protocol                    = "Tcp"
  source_port_range           = "*"
  destination_port_range      = "53"
  source_address_prefix       = "10.20.2.0/24"
  destination_address_prefix  = "AzurePlatformDNS"
  resource_group_name         = azurerm_resource_group.rg-restsim-prod-network.name
  network_security_group_name = azurerm_network_security_group.data.name
}

resource "azurerm_network_security_rule" "data_private_admin" {
  count                       = length(var.private_management_cidrs) > 0 ? 1 : 0
  name                        = "data-private-admin"
  priority                    = 120
  direction                   = "Inbound"
  access                      = "Allow"
  protocol                    = "Tcp"
  source_port_range           = "*"
  destination_port_range      = "5432"
  source_address_prefixes     = var.private_management_cidrs
  destination_address_prefix  = "10.20.2.0/24"
  resource_group_name         = azurerm_resource_group.rg-restsim-prod-network.name
  network_security_group_name = azurerm_network_security_group.data.name
}

resource "azurerm_network_security_rule" "data_deny_in" {
  name                        = "data-deny-in"
  priority                    = 4096
  direction                   = "Inbound"
  access                      = "Deny"
  protocol                    = "*"
  source_port_range           = "*"
  destination_port_range      = "*"
  source_address_prefix       = "*"
  destination_address_prefix  = "*"
  resource_group_name         = azurerm_resource_group.rg-restsim-prod-network.name
  network_security_group_name = azurerm_network_security_group.data.name
}

resource "azurerm_network_security_rule" "data_deny_out" {
  name                        = "data-deny-out"
  priority                    = 4096
  direction                   = "Outbound"
  access                      = "Deny"
  protocol                    = "*"
  source_port_range           = "*"
  destination_port_range      = "*"
  source_address_prefix       = "*"
  destination_address_prefix  = "*"
  resource_group_name         = azurerm_resource_group.rg-restsim-prod-network.name
  network_security_group_name = azurerm_network_security_group.data.name
}

# Private endpoint subnet

resource "azurerm_network_security_rule" "pe_app" {
  name                        = "pe-app"
  priority                    = 100
  direction                   = "Inbound"
  access                      = "Allow"
  protocol                    = "Tcp"
  source_port_range           = "*"
  destination_port_ranges     = ["443", "445", "10000"]
  source_address_prefix       = "10.20.1.0/24"
  destination_address_prefix  = "10.20.3.0/24"
  resource_group_name         = azurerm_resource_group.rg-restsim-prod-network.name
  network_security_group_name = azurerm_network_security_group.private_endpoints.name
}

resource "azurerm_network_security_rule" "pe_private_runner" {
  count                       = length(var.private_management_cidrs) > 0 ? 1 : 0
  name                        = "pe-private-runner"
  priority                    = 110
  direction                   = "Inbound"
  access                      = "Allow"
  protocol                    = "Tcp"
  source_port_range           = "*"
  destination_port_ranges     = ["443", "445"]
  source_address_prefixes     = var.private_management_cidrs
  destination_address_prefix  = "10.20.3.0/24"
  resource_group_name         = azurerm_resource_group.rg-restsim-prod-network.name
  network_security_group_name = azurerm_network_security_group.private_endpoints.name
}

resource "azurerm_network_security_rule" "pe_deny_in" {
  name                        = "pe-deny-in"
  priority                    = 4096
  direction                   = "Inbound"
  access                      = "Deny"
  protocol                    = "*"
  source_port_range           = "*"
  destination_port_range      = "*"
  source_address_prefix       = "*"
  destination_address_prefix  = "*"
  resource_group_name         = azurerm_resource_group.rg-restsim-prod-network.name
  network_security_group_name = azurerm_network_security_group.private_endpoints.name
}

resource "azurerm_network_security_rule" "pe_deny_out" {
  name                        = "pe-deny-out"
  priority                    = 4096
  direction                   = "Outbound"
  access                      = "Deny"
  protocol                    = "*"
  source_port_range           = "*"
  destination_port_range      = "*"
  source_address_prefix       = "*"
  destination_address_prefix  = "*"
  resource_group_name         = azurerm_resource_group.rg-restsim-prod-network.name
  network_security_group_name = azurerm_network_security_group.private_endpoints.name
}
