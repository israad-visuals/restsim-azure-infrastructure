locals {
  app_cloud_init = templatefile("${path.module}/templates/cloud-init.yaml.tftpl", {
    runtime_json = jsonencode({
      environment       = "development"
      integration_mode  = "mock"
      scheduler_enabled = false
      role              = "web"
      app_listen_host   = "127.0.0.1"
      postgres_host     = azurerm_postgresql_flexible_server.development.fqdn
      postgres_database = azurerm_postgresql_flexible_server_database.application.name
      postgres_sslmode  = "verify-full"
      files_host        = "${azurerm_storage_account.files.name}.file.core.windows.net"
      files_share       = azurerm_storage_share.application.name
      key_vault_uri     = azurerm_key_vault.development.vault_uri
      oidc_issuer       = "https://login.microsoftonline.com/${var.tenant_id}/v2.0"
      oidc_client_id    = var.staging_client_id
      staging_hostname  = var.staging_zone_name
    })
    developer_emails = join("\n", sort(tolist(var.staging_developer_emails)))
  })
}

resource "azurerm_network_interface" "app" {
  name                = "nic-restsim-dev-app"
  location            = var.location
  resource_group_name = azurerm_resource_group.app.name
  tags                = local.tags

  ip_configuration {
    name                          = "primary"
    subnet_id                     = azurerm_subnet.app.id
    private_ip_address_allocation = "Dynamic"
    public_ip_address_id          = azurerm_public_ip.staging.id
  }
}

resource "azurerm_linux_virtual_machine" "app" {
  name                            = "vm-restsim-dev-app"
  location                        = var.location
  resource_group_name             = azurerm_resource_group.app.name
  size                            = var.vm_size
  admin_username                  = "restsimadmin"
  disable_password_authentication = true
  network_interface_ids           = [azurerm_network_interface.app.id]
  secure_boot_enabled             = true
  vtpm_enabled                    = true
  tags                            = local.tags

  admin_ssh_key {
    username   = "restsimadmin"
    public_key = trimspace(var.admin_ssh_public_key)
  }
  identity {
    type = "SystemAssigned"
  }
  os_disk {
    name                 = "osdisk-restsim-dev-app"
    caching              = "ReadWrite"
    storage_account_type = "StandardSSD_LRS"
    disk_size_gb         = 32
  }
  source_image_reference {
    publisher = "Canonical"
    offer     = "0001-com-ubuntu-server-jammy"
    sku       = "22_04-lts-gen2"
    version   = var.ubuntu_image_version
  }

  boot_diagnostics {}

  custom_data = base64encode(local.app_cloud_init)

  depends_on = [
    azurerm_subnet_network_security_group_association.app,
    azurerm_subnet_network_security_group_association.private_endpoints,
    azurerm_network_security_rule.app_outbound,
    azurerm_network_security_rule.app_deny_other,
    azurerm_network_security_rule.vm_run_command,
    azurerm_private_endpoint.development,
    azurerm_private_dns_zone_virtual_network_link.development
  ]
}
