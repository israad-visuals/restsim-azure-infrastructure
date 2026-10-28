resource "azurerm_linux_virtual_machine_scale_set" "web" {
  count                           = var.deploy_compute ? 1 : 0
  name                            = "vmss-restsim-prod"
  location                        = var.location
  resource_group_name             = azurerm_resource_group.rg-restsim-prod-app.name
  sku                             = var.vmss_sku
  instances                       = 2
  zones                           = ["1", "2"]
  zone_balance                    = true
  single_placement_group          = false
  overprovision                   = false
  admin_username                  = var.admin_username
  disable_password_authentication = true
  computer_name_prefix            = "rsprodweb"
  upgrade_mode                    = var.install_application ? "Rolling" : "Manual"
  health_probe_id                 = azurerm_lb_probe.readiness.id
  secure_boot_enabled             = true
  vtpm_enabled                    = true
  custom_data = base64encode(templatefile("${path.module}/templates/cloud-init.yaml.tftpl", {
    runtime_json = jsonencode(merge(local.runtime_configuration, {
      role = "web", scheduler_enabled = false
    }))
  }))
  admin_ssh_key {
    username   = var.admin_username
    public_key = var.admin_ssh_public_key
  }
  identity {
    type = "SystemAssigned"
  }
  source_image_reference {
    publisher = var.base_image.publisher
    offer     = var.base_image.offer
    sku       = var.base_image.sku
    version   = var.base_image.version
  }
  os_disk {
    caching              = "ReadWrite"
    storage_account_type = "Premium_LRS"
    disk_size_gb         = 64
  }
  boot_diagnostics {}
  network_interface {
    name    = "nic-restsim-web"
    primary = true
    ip_configuration {
      name                                   = "internal"
      primary                                = true
      subnet_id                              = azurerm_subnet.app.id
      load_balancer_backend_address_pool_ids = [azurerm_lb_backend_address_pool.web.id]
    }
  }
  dynamic "gallery_application" {
    for_each = var.install_application ? [var.approved_web_application_version_id] : []
    content {
      version_id = gallery_application.value
      order      = 1
      tag        = "restsim-web-schedulers-disabled"
    }
  }
  automatic_instance_repair {
    enabled      = var.install_application
    grace_period = "PT30M"
    action       = "Replace"
  }
  dynamic "rolling_upgrade_policy" {
    for_each = var.install_application ? [1] : []
    content {
      max_batch_instance_percent              = 50
      max_unhealthy_instance_percent          = 0
      max_unhealthy_upgraded_instance_percent = 0
      pause_time_between_batches              = "PT5M"
      cross_zone_upgrades_enabled             = false
    }
  }
  extension {
    name                       = "AzureMonitorLinuxAgent"
    publisher                  = "Microsoft.Azure.Monitor"
    type                       = "AzureMonitorLinuxAgent"
    type_handler_version       = "1.0"
    auto_upgrade_minor_version = true
    automatic_upgrade_enabled  = true
  }
  tags = local.tags
  depends_on = [
    azurerm_lb_rule.https,
    azurerm_lb_rule.http_redirect,
    azurerm_subnet_nat_gateway_association.app,
    azurerm_nat_gateway_public_ip_association.production,
    azurerm_network_security_rule.app_cloudflare,
    azurerm_network_security_rule.app_readiness,
    azurerm_network_security_rule.app_postgres,
    azurerm_network_security_rule.app_private_services,
    azurerm_network_security_rule.app_azure_control,
    azurerm_network_security_rule.app_cloudflare_jwks,
    azurerm_network_security_rule.app_dns_udp,
    azurerm_network_security_rule.app_dns_tcp,
    azurerm_network_security_rule.app_private_admin,
    azurerm_network_security_rule.app_approved_https,
    azurerm_network_security_rule.app_deny_in,
    azurerm_network_security_rule.app_deny_out,
    azurerm_network_security_rule.data_app,
    azurerm_network_security_rule.data_ha_in,
    azurerm_network_security_rule.data_ha_out,
    azurerm_network_security_rule.data_storage,
    azurerm_network_security_rule.data_entra,
    azurerm_network_security_rule.data_dns_udp,
    azurerm_network_security_rule.data_dns_tcp,
    azurerm_network_security_rule.data_private_admin,
    azurerm_network_security_rule.data_deny_in,
    azurerm_network_security_rule.data_deny_out,
    azurerm_network_security_rule.pe_app,
    azurerm_network_security_rule.pe_private_runner,
    azurerm_network_security_rule.pe_deny_in,
    azurerm_network_security_rule.pe_deny_out,
    azurerm_private_endpoint.files,
    azurerm_private_endpoint.vault,
    azurerm_private_endpoint.redis,
    azurerm_private_endpoint.artifacts
  ]
  lifecycle {
    prevent_destroy = true

    ignore_changes = [instances, gallery_application]
  }
}

resource "azurerm_monitor_autoscale_setting" "web" {
  count               = var.deploy_compute ? 1 : 0
  name                = "autoscale-restsim-prod-web"
  location            = var.location
  resource_group_name = azurerm_resource_group.rg-restsim-prod-app.name
  target_resource_id  = azurerm_linux_virtual_machine_scale_set.web[0].id
  profile {
    name = "production"
    capacity {
      default = 2
      minimum = 2
      maximum = var.vmss_max_instances
    }
    rule {
      metric_trigger {
        metric_name        = "Percentage CPU"
        metric_resource_id = azurerm_linux_virtual_machine_scale_set.web[0].id
        time_grain         = "PT1M"
        statistic          = "Average"
        time_window        = "PT10M"
        time_aggregation   = "Average"
        operator           = "GreaterThan"
        threshold          = 70
      }
      scale_action {
        direction = "Increase"
        type      = "ChangeCount"
        value     = "1"
        cooldown  = "PT10M"
      }
    }
    rule {
      metric_trigger {
        metric_name        = "Percentage CPU"
        metric_resource_id = azurerm_linux_virtual_machine_scale_set.web[0].id
        time_grain         = "PT1M"
        statistic          = "Average"
        time_window        = "PT15M"
        time_aggregation   = "Average"
        operator           = "LessThan"
        threshold          = 30
      }
      scale_action {
        direction = "Decrease"
        type      = "ChangeCount"
        value     = "1"
        cooldown  = "PT15M"
      }
    }
  }
  tags = local.tags
}

resource "azurerm_network_interface" "worker" {
  count               = var.deploy_compute ? 1 : 0
  name                = "nic-restsim-prod-worker"
  location            = var.location
  resource_group_name = azurerm_resource_group.rg-restsim-prod-app.name
  ip_configuration {
    name                          = "internal"
    subnet_id                     = azurerm_subnet.app.id
    private_ip_address_allocation = "Dynamic"
  }
  tags = local.tags
}

resource "azurerm_linux_virtual_machine" "worker" {
  count                           = var.deploy_compute ? 1 : 0
  name                            = "vm-restsim-prod-worker"
  location                        = var.location
  resource_group_name             = azurerm_resource_group.rg-restsim-prod-app.name
  size                            = var.worker_sku
  zone                            = "1"
  admin_username                  = var.admin_username
  disable_password_authentication = true
  network_interface_ids           = [azurerm_network_interface.worker[0].id]
  secure_boot_enabled             = true
  vtpm_enabled                    = true
  custom_data = base64encode(templatefile("${path.module}/templates/cloud-init.yaml.tftpl", {
    runtime_json = jsonencode(merge(local.runtime_configuration, {
      role = "worker", scheduler_enabled = true
    }))
  }))
  admin_ssh_key {
    username   = var.admin_username
    public_key = var.admin_ssh_public_key
  }
  identity {
    type = "SystemAssigned"
  }
  source_image_reference {
    publisher = var.base_image.publisher
    offer     = var.base_image.offer
    sku       = var.base_image.sku
    version   = var.base_image.version
  }
  os_disk {
    name                 = "disk-restsim-prod-worker"
    caching              = "ReadWrite"
    storage_account_type = "Premium_LRS"
    disk_size_gb         = 64
  }
  boot_diagnostics {}
  dynamic "gallery_application" {
    for_each = var.install_application ? [var.approved_worker_application_version_id] : []
    content {
      version_id                                  = gallery_application.value
      automatic_upgrade_enabled                   = false
      treat_failure_as_deployment_failure_enabled = true
      order                                       = 1
      tag                                         = "restsim-worker-separate-owner-gate"
    }
  }
  tags = local.tags
  depends_on = [
    azurerm_subnet_nat_gateway_association.app,
    azurerm_nat_gateway_public_ip_association.production,
    azurerm_network_security_rule.app_cloudflare,
    azurerm_network_security_rule.app_readiness,
    azurerm_network_security_rule.app_postgres,
    azurerm_network_security_rule.app_private_services,
    azurerm_network_security_rule.app_azure_control,
    azurerm_network_security_rule.app_cloudflare_jwks,
    azurerm_network_security_rule.app_dns_udp,
    azurerm_network_security_rule.app_dns_tcp,
    azurerm_network_security_rule.app_private_admin,
    azurerm_network_security_rule.app_approved_https,
    azurerm_network_security_rule.app_deny_in,
    azurerm_network_security_rule.app_deny_out,
    azurerm_network_security_rule.data_app,
    azurerm_network_security_rule.data_ha_in,
    azurerm_network_security_rule.data_ha_out,
    azurerm_network_security_rule.data_storage,
    azurerm_network_security_rule.data_entra,
    azurerm_network_security_rule.data_dns_udp,
    azurerm_network_security_rule.data_dns_tcp,
    azurerm_network_security_rule.data_private_admin,
    azurerm_network_security_rule.data_deny_in,
    azurerm_network_security_rule.data_deny_out,
    azurerm_network_security_rule.pe_app,
    azurerm_network_security_rule.pe_private_runner,
    azurerm_network_security_rule.pe_deny_in,
    azurerm_network_security_rule.pe_deny_out,
    azurerm_private_endpoint.files,
    azurerm_private_endpoint.vault,
    azurerm_private_endpoint.redis,
    azurerm_private_endpoint.artifacts
  ]
  lifecycle {
    prevent_destroy = true

    ignore_changes = [gallery_application]
  }
}

resource "azurerm_virtual_machine_extension" "worker_monitor" {
  count                      = var.deploy_compute ? 1 : 0
  name                       = "AzureMonitorLinuxAgent"
  virtual_machine_id         = azurerm_linux_virtual_machine.worker[0].id
  publisher                  = "Microsoft.Azure.Monitor"
  type                       = "AzureMonitorLinuxAgent"
  type_handler_version       = "1.0"
  auto_upgrade_minor_version = true
  automatic_upgrade_enabled  = true
  tags                       = local.tags
}

locals {
  runtime_principals = var.deploy_compute ? {
    web    = azurerm_linux_virtual_machine_scale_set.web[0].identity[0].principal_id
    worker = azurerm_linux_virtual_machine.worker[0].identity[0].principal_id
  } : {}

}

resource "azurerm_role_assignment" "web_postgres_application_username" {
  count                = var.deploy_compute ? 1 : 0
  scope                = azurerm_key_vault_secret.postgres_application_username.resource_versionless_id
  role_definition_name = "Key Vault Secrets User"
  principal_id         = azurerm_linux_virtual_machine_scale_set.web[0].identity[0].principal_id
}

resource "azurerm_role_assignment" "web_postgres_application_password" {
  count                = var.deploy_compute ? 1 : 0
  scope                = azurerm_key_vault_secret.postgres_application_password.resource_versionless_id
  role_definition_name = "Key Vault Secrets User"
  principal_id         = azurerm_linux_virtual_machine_scale_set.web[0].identity[0].principal_id
}

resource "azurerm_role_assignment" "web_azure_files_account_key" {
  count                = var.deploy_compute ? 1 : 0
  scope                = azurerm_key_vault_secret.azure_files_account_key.resource_versionless_id
  role_definition_name = "Key Vault Secrets User"
  principal_id         = azurerm_linux_virtual_machine_scale_set.web[0].identity[0].principal_id
}

resource "azurerm_role_assignment" "web_redis_session_key" {
  count                = var.deploy_compute ? 1 : 0
  scope                = azurerm_key_vault_secret.redis_session_key.resource_versionless_id
  role_definition_name = "Key Vault Secrets User"
  principal_id         = azurerm_linux_virtual_machine_scale_set.web[0].identity[0].principal_id
}

resource "azurerm_role_assignment" "web_origin_tls_certificate" {
  count                = var.deploy_compute && var.install_application ? 1 : 0
  scope                = azurerm_key_vault_secret.origin_tls_certificate[0].resource_versionless_id
  role_definition_name = "Key Vault Secrets User"
  principal_id         = azurerm_linux_virtual_machine_scale_set.web[0].identity[0].principal_id
}

resource "azurerm_role_assignment" "web_origin_tls_private_key" {
  count                = var.deploy_compute && var.install_application ? 1 : 0
  scope                = azurerm_key_vault_secret.origin_tls_private_key[0].resource_versionless_id
  role_definition_name = "Key Vault Secrets User"
  principal_id         = azurerm_linux_virtual_machine_scale_set.web[0].identity[0].principal_id
}

resource "azurerm_role_assignment" "web_cloudflare_origin_pull_ca" {
  count                = var.deploy_compute && var.require_authenticated_origin_pulls ? 1 : 0
  scope                = azurerm_key_vault_secret.cloudflare_origin_pull_ca[0].resource_versionless_id
  role_definition_name = "Key Vault Secrets User"
  principal_id         = azurerm_linux_virtual_machine_scale_set.web[0].identity[0].principal_id
}

resource "azurerm_role_assignment" "web_application_insights_connection_string" {
  count                = var.deploy_compute ? 1 : 0
  scope                = azurerm_key_vault_secret.application_insights_connection_string.resource_versionless_id
  role_definition_name = "Key Vault Secrets User"
  principal_id         = azurerm_linux_virtual_machine_scale_set.web[0].identity[0].principal_id
}

resource "azurerm_role_assignment" "web_application_secrets" {
  for_each             = var.deploy_compute ? toset(nonsensitive(keys(var.application_secrets))) : toset([])
  scope                = azurerm_key_vault_secret.application[each.key].resource_versionless_id
  role_definition_name = "Key Vault Secrets User"
  principal_id         = azurerm_linux_virtual_machine_scale_set.web[0].identity[0].principal_id
}

resource "azurerm_role_assignment" "worker_postgres_application_username" {
  count                = var.deploy_compute ? 1 : 0
  scope                = azurerm_key_vault_secret.postgres_application_username.resource_versionless_id
  role_definition_name = "Key Vault Secrets User"
  principal_id         = azurerm_linux_virtual_machine.worker[0].identity[0].principal_id
}

resource "azurerm_role_assignment" "worker_postgres_application_password" {
  count                = var.deploy_compute ? 1 : 0
  scope                = azurerm_key_vault_secret.postgres_application_password.resource_versionless_id
  role_definition_name = "Key Vault Secrets User"
  principal_id         = azurerm_linux_virtual_machine.worker[0].identity[0].principal_id
}

resource "azurerm_role_assignment" "worker_azure_files_account_key" {
  count                = var.deploy_compute ? 1 : 0
  scope                = azurerm_key_vault_secret.azure_files_account_key.resource_versionless_id
  role_definition_name = "Key Vault Secrets User"
  principal_id         = azurerm_linux_virtual_machine.worker[0].identity[0].principal_id
}

resource "azurerm_role_assignment" "worker_redis_session_key" {
  count                = var.deploy_compute ? 1 : 0
  scope                = azurerm_key_vault_secret.redis_session_key.resource_versionless_id
  role_definition_name = "Key Vault Secrets User"
  principal_id         = azurerm_linux_virtual_machine.worker[0].identity[0].principal_id
}

resource "azurerm_role_assignment" "worker_origin_tls_certificate" {
  count                = var.deploy_compute && var.install_application ? 1 : 0
  scope                = azurerm_key_vault_secret.origin_tls_certificate[0].resource_versionless_id
  role_definition_name = "Key Vault Secrets User"
  principal_id         = azurerm_linux_virtual_machine.worker[0].identity[0].principal_id
}

resource "azurerm_role_assignment" "worker_origin_tls_private_key" {
  count                = var.deploy_compute && var.install_application ? 1 : 0
  scope                = azurerm_key_vault_secret.origin_tls_private_key[0].resource_versionless_id
  role_definition_name = "Key Vault Secrets User"
  principal_id         = azurerm_linux_virtual_machine.worker[0].identity[0].principal_id
}

resource "azurerm_role_assignment" "worker_cloudflare_origin_pull_ca" {
  count                = var.deploy_compute && var.require_authenticated_origin_pulls ? 1 : 0
  scope                = azurerm_key_vault_secret.cloudflare_origin_pull_ca[0].resource_versionless_id
  role_definition_name = "Key Vault Secrets User"
  principal_id         = azurerm_linux_virtual_machine.worker[0].identity[0].principal_id
}

resource "azurerm_role_assignment" "worker_application_insights_connection_string" {
  count                = var.deploy_compute ? 1 : 0
  scope                = azurerm_key_vault_secret.application_insights_connection_string.resource_versionless_id
  role_definition_name = "Key Vault Secrets User"
  principal_id         = azurerm_linux_virtual_machine.worker[0].identity[0].principal_id
}

resource "azurerm_role_assignment" "worker_application_secrets" {
  for_each             = var.deploy_compute ? toset(nonsensitive(keys(var.application_secrets))) : toset([])
  scope                = azurerm_key_vault_secret.application[each.key].resource_versionless_id
  role_definition_name = "Key Vault Secrets User"
  principal_id         = azurerm_linux_virtual_machine.worker[0].identity[0].principal_id
}
