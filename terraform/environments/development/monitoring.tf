resource "azurerm_log_analytics_workspace" "development" {
  name                = "law-restsim-dev"
  location            = var.location
  resource_group_name = azurerm_resource_group.monitoring.name
  sku                 = "PerGB2018"
  retention_in_days   = 30
  daily_quota_gb      = 0.5
  tags                = local.tags
}

resource "azurerm_application_insights" "development" {
  name                = "appi-restsim-dev"
  location            = var.location
  resource_group_name = azurerm_resource_group.monitoring.name
  workspace_id        = azurerm_log_analytics_workspace.development.id
  application_type    = "web"
  sampling_percentage = 25
  tags                = local.tags
}

resource "azurerm_monitor_data_collection_rule" "linux" {
  name                = "dcr-restsim-dev-linux"
  location            = var.location
  resource_group_name = azurerm_resource_group.monitoring.name
  kind                = "Linux"
  tags                = local.tags

  destinations {
    log_analytics {
      name                  = "workspace"
      workspace_resource_id = azurerm_log_analytics_workspace.development.id
    }
  }
  data_sources {
    syslog {
      name           = "warnings-and-errors"
      facility_names = ["auth", "authpriv", "daemon", "syslog", "user"]
      log_levels     = ["Warning", "Error", "Critical", "Alert", "Emergency"]
      streams        = ["Microsoft-Syslog"]
    }
    performance_counter {
      name                          = "linux-performance"
      streams                       = ["Microsoft-Perf"]
      sampling_frequency_in_seconds = 60
      counter_specifiers            = ["Processor(*)\\% Processor Time", "Memory(*)\\% Used Memory", "Logical Disk(*)\\% Used Space"]
    }
  }
  data_flow {
    streams      = ["Microsoft-Syslog", "Microsoft-Perf"]
    destinations = ["workspace"]
  }
}

resource "azurerm_virtual_machine_extension" "monitor" {
  name                       = "AzureMonitorLinuxAgent"
  virtual_machine_id         = azurerm_linux_virtual_machine.app.id
  publisher                  = "Microsoft.Azure.Monitor"
  type                       = "AzureMonitorLinuxAgent"
  type_handler_version       = "1.0"
  auto_upgrade_minor_version = true
  automatic_upgrade_enabled  = true
  tags                       = local.tags
}

resource "azurerm_monitor_data_collection_rule_association" "app" {
  name                    = "restsim-dev-linux"
  target_resource_id      = azurerm_linux_virtual_machine.app.id
  data_collection_rule_id = azurerm_monitor_data_collection_rule.linux.id
  depends_on              = [azurerm_virtual_machine_extension.monitor]
}

resource "azurerm_monitor_action_group" "operations" {
  name                = "ag-restsim-dev-operations"
  resource_group_name = azurerm_resource_group.monitoring.name
  short_name          = "rs-dev-ops"
  tags                = local.tags

  email_receiver {
    name                    = "development-operations"
    email_address           = var.alert_email
    use_common_alert_schema = true
  }
}

resource "azurerm_monitor_metric_alert" "cpu" {
  name                = "alert-restsim-dev-cpu"
  resource_group_name = azurerm_resource_group.monitoring.name
  scopes              = [azurerm_linux_virtual_machine.app.id]
  description         = "Development VM average CPU exceeds 85% over 15 minutes."
  severity            = 3
  frequency           = "PT5M"
  window_size         = "PT15M"
  tags                = local.tags

  criteria {
    metric_namespace = "Microsoft.Compute/virtualMachines"
    metric_name      = "Percentage CPU"
    aggregation      = "Average"
    operator         = "GreaterThan"
    threshold        = 85
  }
  action {
    action_group_id = azurerm_monitor_action_group.operations.id
  }
}

resource "azurerm_monitor_metric_alert" "database_storage" {
  name                = "alert-restsim-dev-database-storage"
  resource_group_name = azurerm_resource_group.monitoring.name
  scopes              = [azurerm_postgresql_flexible_server.development.id]
  description         = "Development PostgreSQL average storage usage exceeds 80% over 15 minutes."
  severity            = 2
  frequency           = "PT5M"
  window_size         = "PT15M"
  tags                = local.tags

  criteria {
    metric_namespace = "Microsoft.DBforPostgreSQL/flexibleServers"
    metric_name      = "storage_percent"
    aggregation      = "Average"
    operator         = "GreaterThan"
    threshold        = 80
  }
  action {
    action_group_id = azurerm_monitor_action_group.operations.id
  }
}

locals {
  diagnostic_targets = {
    postgres = azurerm_postgresql_flexible_server.development.id
    vault    = azurerm_key_vault.development.id
    files    = "${azurerm_storage_account.files.id}/fileServices/default"
  }
}

resource "azurerm_monitor_diagnostic_setting" "services" {
  for_each                   = local.diagnostic_targets
  name                       = "diag-restsim-dev-${each.key}"
  target_resource_id         = each.value
  log_analytics_workspace_id = azurerm_log_analytics_workspace.development.id

  enabled_log {
    category_group = "allLogs"
  }
}
