resource "azurerm_log_analytics_workspace" "production" {
  name                = "law-restsim-prod"
  location            = var.location
  resource_group_name = azurerm_resource_group.rg-restsim-prod-monitoring.name
  sku                 = "PerGB2018"
  retention_in_days   = 30
  daily_quota_gb      = 5
  tags                = local.tags
}

resource "azurerm_application_insights" "production" {
  name                = "appi-restsim-prod"
  location            = var.location
  resource_group_name = azurerm_resource_group.rg-restsim-prod-monitoring.name
  workspace_id        = azurerm_log_analytics_workspace.production.id
  application_type    = "web"
  retention_in_days   = 30
  sampling_percentage = 100
  tags                = local.tags
}

resource "azurerm_monitor_action_group" "operations" {
  name                = "ag-restsim-prod-ops"
  resource_group_name = azurerm_resource_group.rg-restsim-prod-monitoring.name
  short_name          = "RestSimOps"
  email_receiver {
    name                    = "operations"
    email_address           = var.alert_email
    use_common_alert_schema = true
  }
  tags = local.tags
}

resource "azurerm_monitor_data_collection_rule" "linux" {
  name                = "dcr-restsim-prod-linux"
  location            = var.location
  resource_group_name = azurerm_resource_group.rg-restsim-prod-monitoring.name
  kind                = "Linux"
  destinations {
    log_analytics {
      name                  = "production-logs"
      workspace_resource_id = azurerm_log_analytics_workspace.production.id
    }
  }
  data_sources {
    syslog {
      name           = "linux-system-events"
      facility_names = ["auth", "authpriv", "daemon", "syslog", "user"]
      log_levels     = ["Warning", "Error", "Critical", "Alert", "Emergency"]
      streams        = ["Microsoft-Syslog"]
    }
  }
  data_flow {
    streams      = ["Microsoft-Syslog"]
    destinations = ["production-logs"]
  }
  tags = local.tags
}

resource "azurerm_monitor_data_collection_rule_association" "web" {
  count                   = var.deploy_compute ? 1 : 0
  name                    = "restsim-prod-linux"
  target_resource_id      = azurerm_linux_virtual_machine_scale_set.web[0].id
  data_collection_rule_id = azurerm_monitor_data_collection_rule.linux.id
}
resource "azurerm_monitor_data_collection_rule_association" "worker" {
  count                   = var.deploy_compute ? 1 : 0
  name                    = "restsim-prod-linux"
  target_resource_id      = azurerm_linux_virtual_machine.worker[0].id
  data_collection_rule_id = azurerm_monitor_data_collection_rule.linux.id
}

locals {
  diagnostic_resources = {
    postgres  = azurerm_postgresql_flexible_server.production.id
    vault     = azurerm_key_vault.production.id
    files     = "${azurerm_storage_account.files.id}/fileServices/default"
    artifacts = "${azurerm_storage_account.artifacts.id}/blobServices/default"
    redis     = azurerm_managed_redis.sessions.id
    ingress   = azurerm_lb.production.id
  }
}

data "azurerm_monitor_diagnostic_categories" "production" {
  for_each    = local.diagnostic_resources
  resource_id = each.value
}

resource "azurerm_monitor_diagnostic_setting" "production" {
  for_each                   = local.diagnostic_resources
  name                       = "diag-restsim-prod-${each.key}"
  target_resource_id         = each.value
  log_analytics_workspace_id = azurerm_log_analytics_workspace.production.id
  dynamic "enabled_log" {
    for_each = toset(data.azurerm_monitor_diagnostic_categories.production[each.key].log_category_types)
    content {
      category = enabled_log.value
    }
  }
  dynamic "enabled_metric" {
    for_each = toset(data.azurerm_monitor_diagnostic_categories.production[each.key].metrics)
    content {
      category = enabled_metric.value
    }
  }
}

resource "azurerm_monitor_metric_alert" "postgres_cpu" {
  name                = "alert-restsim-prod-postgres-cpu"
  resource_group_name = azurerm_resource_group.rg-restsim-prod-monitoring.name
  scopes              = [azurerm_postgresql_flexible_server.production.id]
  severity            = 2
  frequency           = "PT1M"
  window_size         = "PT15M"
  description         = "Production PostgreSQL average CPU exceeds 80% over 15 minutes."
  tags                = local.tags

  criteria {
    metric_namespace = "Microsoft.DBforPostgreSQL/flexibleServers"
    metric_name      = "cpu_percent"
    aggregation      = "Average"
    operator         = "GreaterThan"
    threshold        = 80
  }

  action {
    action_group_id = azurerm_monitor_action_group.operations.id
  }
}

resource "azurerm_monitor_metric_alert" "postgres_storage" {
  name                = "alert-restsim-prod-postgres-storage"
  resource_group_name = azurerm_resource_group.rg-restsim-prod-monitoring.name
  scopes              = [azurerm_postgresql_flexible_server.production.id]
  severity            = 2
  frequency           = "PT1M"
  window_size         = "PT15M"
  description         = "Production PostgreSQL average storage usage exceeds 80% over 15 minutes."
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

resource "azurerm_monitor_metric_alert" "redis_load" {
  name                = "alert-restsim-prod-redis-load"
  resource_group_name = azurerm_resource_group.rg-restsim-prod-monitoring.name
  scopes              = [azurerm_managed_redis.sessions.id]
  severity            = 2
  frequency           = "PT1M"
  window_size         = "PT15M"
  description         = "Production Redis maximum server load exceeds 80% within a 15-minute window."
  tags                = local.tags

  criteria {
    metric_namespace = "Microsoft.Cache/redisEnterprise"
    metric_name      = "serverLoad"
    aggregation      = "Maximum"
    operator         = "GreaterThan"
    threshold        = 80
  }

  action {
    action_group_id = azurerm_monitor_action_group.operations.id
  }
}

resource "azurerm_monitor_metric_alert" "application_failures" {
  name                = "alert-restsim-prod-application-failures"
  resource_group_name = azurerm_resource_group.rg-restsim-prod-monitoring.name
  scopes              = [azurerm_application_insights.production.id]
  severity            = 2
  frequency           = "PT1M"
  window_size         = "PT15M"
  description         = "More than five failed application requests are recorded within 15 minutes."
  tags                = local.tags

  criteria {
    metric_namespace = "Microsoft.Insights/components"
    metric_name      = "requests/failed"
    aggregation      = "Count"
    operator         = "GreaterThan"
    threshold        = 5
  }

  action {
    action_group_id = azurerm_monitor_action_group.operations.id
  }
}

resource "azurerm_monitor_metric_alert" "web_cpu" {
  count               = var.deploy_compute ? 1 : 0
  name                = "alert-restsim-prod-web-cpu"
  resource_group_name = azurerm_resource_group.rg-restsim-prod-monitoring.name
  scopes              = [azurerm_linux_virtual_machine_scale_set.web[0].id]
  severity            = 2
  frequency           = "PT1M"
  window_size         = "PT15M"
  description         = "Production web scale-set average CPU exceeds 85% over 15 minutes."
  tags                = local.tags

  criteria {
    metric_namespace = "Microsoft.Compute/virtualMachineScaleSets"
    metric_name      = "Percentage CPU"
    aggregation      = "Average"
    operator         = "GreaterThan"
    threshold        = 85
  }

  action {
    action_group_id = azurerm_monitor_action_group.operations.id
  }
}

resource "azurerm_monitor_metric_alert" "worker_cpu" {
  count               = var.deploy_compute ? 1 : 0
  name                = "alert-restsim-prod-worker-cpu"
  resource_group_name = azurerm_resource_group.rg-restsim-prod-monitoring.name
  scopes              = [azurerm_linux_virtual_machine.worker[0].id]
  severity            = 2
  frequency           = "PT1M"
  window_size         = "PT15M"
  description         = "Production background-worker average CPU exceeds 85% over 15 minutes."
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

resource "azurerm_monitor_metric_alert" "web_readiness" {
  count               = var.deploy_compute ? 1 : 0
  name                = "alert-restsim-prod-web-readiness"
  resource_group_name = azurerm_resource_group.rg-restsim-prod-monitoring.name
  scopes              = [azurerm_lb.production.id]
  severity            = 2
  frequency           = "PT1M"
  window_size         = "PT15M"
  description         = "Average load-balancer backend probe availability falls below 99% over 15 minutes."
  tags                = local.tags

  criteria {
    metric_namespace = "Microsoft.Network/loadBalancers"
    metric_name      = "DipAvailability"
    aggregation      = "Average"
    operator         = "LessThan"
    threshold        = 0.99
  }

  action {
    action_group_id = azurerm_monitor_action_group.operations.id
  }
}

resource "azurerm_monitor_activity_log_alert" "resource_health" {
  name                = "alert-restsim-prod-resource-health"
  location            = "global"
  resource_group_name = azurerm_resource_group.rg-restsim-prod-monitoring.name
  scopes              = values(local.resource_groups)
  description         = "An Azure production resource reports degraded, unavailable or unknown health."
  criteria {
    category = "ResourceHealth"
    resource_health {
      current = ["Degraded", "Unavailable", "Unknown"]
    }
  }
  action {
    action_group_id = azurerm_monitor_action_group.operations.id
  }
  tags = local.tags
}
