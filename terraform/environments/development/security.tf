resource "azurerm_network_security_group" "app" {
  name                = "nsg-restsim-dev-app"
  location            = var.location
  resource_group_name = azurerm_resource_group.network.name
  tags                = local.tags
}

resource "azurerm_network_security_rule" "staging_https" {
  count                       = var.enable_staging_ingress ? 1 : 0
  name                        = "Allow-Staging-HTTPS"
  priority                    = 100
  direction                   = "Inbound"
  access                      = "Allow"
  protocol                    = "Tcp"
  source_port_range           = "*"
  destination_port_range      = "443"
  source_address_prefixes     = var.staging_access_cidrs
  destination_address_prefix  = "10.30.1.0/24"
  resource_group_name         = azurerm_resource_group.network.name
  network_security_group_name = azurerm_network_security_group.app.name

  lifecycle {
    precondition {
      condition = (
        var.staging_authentication_verified &&
        var.staging_zone_name != null &&
        var.staging_client_id != null &&
        length(var.staging_developer_emails) > 0 &&
        length(var.staging_access_cidrs) > 0
      )
      error_message = "Before opening staging, configure its DNS, Entra client and developer allowlist, and verify TLS/proxy access controls on the VM."
    }
  }
}

locals {
  app_outbound_rules = {
    database         = { priority = 100, destination = "10.30.2.0/24", ports = ["5432"], protocol = "Tcp" }
    private_services = { priority = 110, destination = "10.30.3.0/24", ports = ["443", "445"], protocol = "Tcp" }
    entra            = { priority = 120, destination = "AzureActiveDirectory", ports = ["443"], protocol = "Tcp" }
    monitoring       = { priority = 130, destination = "AzureMonitor", ports = ["443"], protocol = "Tcp" }
    agent_packages   = { priority = 140, destination = "Storage", ports = ["443"], protocol = "Tcp" }
    dns              = { priority = 150, destination = "AzurePlatformDNS", ports = ["53"], protocol = "*" }
    metadata         = { priority = 160, destination = "169.254.169.254", ports = ["80"], protocol = "Tcp" }
    resource_manager = { priority = 170, destination = "AzureResourceManager", ports = ["443"], protocol = "Tcp" }
  }
}

resource "azurerm_network_security_rule" "app_outbound" {
  for_each                    = local.app_outbound_rules
  name                        = "Allow-${each.key}"
  priority                    = each.value.priority
  direction                   = "Outbound"
  access                      = "Allow"
  protocol                    = each.value.protocol
  source_port_range           = "*"
  destination_port_ranges     = each.value.ports
  source_address_prefix       = "10.30.1.0/24"
  destination_address_prefix  = each.value.destination
  resource_group_name         = azurerm_resource_group.network.name
  network_security_group_name = azurerm_network_security_group.app.name
}

resource "azurerm_network_security_rule" "extra_https" {
  count                        = length(var.extra_https_egress_cidrs) > 0 ? 1 : 0
  name                         = "Allow-Update-And-Artifact-HTTPS"
  priority                     = 200
  direction                    = "Outbound"
  access                       = "Allow"
  protocol                     = "Tcp"
  source_port_range            = "*"
  destination_port_range       = "443"
  source_address_prefix        = "10.30.1.0/24"
  destination_address_prefixes = var.extra_https_egress_cidrs
  resource_group_name          = azurerm_resource_group.network.name
  network_security_group_name  = azurerm_network_security_group.app.name
}

resource "azurerm_network_security_group" "data" {
  name                = "nsg-restsim-dev-data"
  location            = var.location
  resource_group_name = azurerm_resource_group.network.name
  tags                = local.tags

  security_rule {
    name                       = "Allow-App-PostgreSQL"
    priority                   = 100
    direction                  = "Inbound"
    access                     = "Allow"
    protocol                   = "Tcp"
    source_port_range          = "*"
    destination_port_range     = "5432"
    source_address_prefix      = "10.30.1.0/24"
    destination_address_prefix = "10.30.2.0/24"
  }
  security_rule {
    name                       = "Allow-PostgreSQL-Internal-In"
    priority                   = 110
    direction                  = "Inbound"
    access                     = "Allow"
    protocol                   = "Tcp"
    source_port_range          = "*"
    destination_port_range     = "5432"
    source_address_prefix      = "10.30.2.0/24"
    destination_address_prefix = "10.30.2.0/24"
  }
  security_rule {
    name                       = "Allow-PostgreSQL-Internal-Out"
    priority                   = 100
    direction                  = "Outbound"
    access                     = "Allow"
    protocol                   = "Tcp"
    source_port_range          = "*"
    destination_port_range     = "5432"
    source_address_prefix      = "10.30.2.0/24"
    destination_address_prefix = "10.30.2.0/24"
  }
  security_rule {
    name                       = "Allow-PostgreSQL-Storage"
    priority                   = 110
    direction                  = "Outbound"
    access                     = "Allow"
    protocol                   = "Tcp"
    source_port_range          = "*"
    destination_port_range     = "443"
    source_address_prefix      = "10.30.2.0/24"
    destination_address_prefix = "Storage"
  }
  security_rule {
    name                       = "Allow-DNS"
    priority                   = 120
    direction                  = "Outbound"
    access                     = "Allow"
    protocol                   = "*"
    source_port_range          = "*"
    destination_port_range     = "53"
    source_address_prefix      = "10.30.2.0/24"
    destination_address_prefix = "AzurePlatformDNS"
  }
  security_rule {
    name                       = "Deny-Other-Inbound"
    priority                   = 4096
    direction                  = "Inbound"
    access                     = "Deny"
    protocol                   = "*"
    source_port_range          = "*"
    destination_port_range     = "*"
    source_address_prefix      = "*"
    destination_address_prefix = "*"
  }

  security_rule {
    name                       = "Deny-Other-Outbound"
    priority                   = 4096
    direction                  = "Outbound"
    access                     = "Deny"
    protocol                   = "*"
    source_port_range          = "*"
    destination_port_range     = "*"
    source_address_prefix      = "*"
    destination_address_prefix = "*"
  }
}

resource "azurerm_network_security_group" "private_endpoints" {
  name                = "nsg-restsim-dev-private-endpoints"
  location            = var.location
  resource_group_name = azurerm_resource_group.network.name
  tags                = local.tags

  security_rule {
    name                       = "Allow-App-Private-Services"
    priority                   = 100
    direction                  = "Inbound"
    access                     = "Allow"
    protocol                   = "Tcp"
    source_port_range          = "*"
    destination_port_ranges    = ["443", "445"]
    source_address_prefix      = "10.30.1.0/24"
    destination_address_prefix = "10.30.3.0/24"
  }
  security_rule {
    name                       = "Deny-Other-Inbound"
    priority                   = 4096
    direction                  = "Inbound"
    access                     = "Deny"
    protocol                   = "*"
    source_port_range          = "*"
    destination_port_range     = "*"
    source_address_prefix      = "*"
    destination_address_prefix = "*"
  }

  security_rule {
    name                       = "Deny-Other-Outbound"
    priority                   = 4096
    direction                  = "Outbound"
    access                     = "Deny"
    protocol                   = "*"
    source_port_range          = "*"
    destination_port_range     = "*"
    source_address_prefix      = "*"
    destination_address_prefix = "*"
  }
}

resource "azurerm_network_security_rule" "app_deny_other" {
  for_each                    = toset(["Inbound", "Outbound"])
  name                        = "Deny-Other-${each.value}"
  priority                    = 4096
  direction                   = each.value
  access                      = "Deny"
  protocol                    = "*"
  source_port_range           = "*"
  destination_port_range      = "*"
  source_address_prefix       = "*"
  destination_address_prefix  = "*"
  resource_group_name         = azurerm_resource_group.network.name
  network_security_group_name = azurerm_network_security_group.app.name
}

resource "azurerm_subnet_network_security_group_association" "app" {
  subnet_id                 = azurerm_subnet.app.id
  network_security_group_id = azurerm_network_security_group.app.id
}

resource "azurerm_subnet_network_security_group_association" "data" {
  subnet_id                 = azurerm_subnet.data.id
  network_security_group_id = azurerm_network_security_group.data.id
}

resource "azurerm_subnet_network_security_group_association" "private_endpoints" {
  subnet_id                 = azurerm_subnet.private_endpoints.id
  network_security_group_id = azurerm_network_security_group.private_endpoints.id
}

resource "azurerm_network_security_rule" "vm_run_command" {
  count                       = var.enable_vm_run_command ? 1 : 0
  name                        = "Allow-VM-Run-Command-HTTPS"
  priority                    = 180
  direction                   = "Outbound"
  access                      = "Allow"
  protocol                    = "Tcp"
  source_port_range           = "*"
  destination_port_range      = "443"
  source_address_prefix       = "10.30.1.0/24"
  destination_address_prefix  = "AzureCloud"
  resource_group_name         = azurerm_resource_group.network.name
  network_security_group_name = azurerm_network_security_group.app.name
}
