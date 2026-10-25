# These settings apply to production only.
# The management groups and development subscription already sit outside this code.
resource "azurerm_management_group_subscription_association" "production" {
  count               = var.management_group_id == null ? 0 : 1
  management_group_id = var.management_group_id
  subscription_id     = "/subscriptions/${var.subscription_id}"
}

resource "azurerm_role_assignment" "production_access" {
  for_each             = var.production_role_assignments
  scope                = "/subscriptions/${var.subscription_id}"
  role_definition_name = each.value.role_definition_name
  principal_id         = each.value.principal_id
}

resource "azurerm_policy_definition" "allowed_regions" {
  count        = var.enable_subscription_governance ? 1 : 0
  name         = "restsim-prod-approved-regions"
  policy_type  = "Custom"
  mode         = "Indexed"
  display_name = "RestSim production region restriction"
  policy_rule = jsonencode({
    if = { allOf = [
      { field = "location", notIn = [var.location, "global"] },
      { field = "type", notEquals = "Microsoft.AzureActiveDirectory/b2cDirectories" }
    ] }
    then = { effect = "deny" }
  })
}

resource "azurerm_subscription_policy_assignment" "allowed_regions" {
  count                = var.enable_subscription_governance ? 1 : 0
  name                 = "restsim-prod-regions"
  display_name         = "RestSim production region restriction"
  subscription_id      = "/subscriptions/${var.subscription_id}"
  policy_definition_id = azurerm_policy_definition.allowed_regions[0].id
}

resource "azurerm_policy_definition" "required_tags" {
  count        = var.enable_subscription_governance ? 1 : 0
  name         = "restsim-prod-required-tags"
  policy_type  = "Custom"
  mode         = "Indexed"
  display_name = "RestSim production ownership and cost tags"
  policy_rule = jsonencode({
    if = {
      anyOf = [
        { field = "tags[project]", exists = "false" },
        { field = "tags[environment]", exists = "false" },
        { field = "tags[owner]", exists = "false" },
        { field = "tags[cost_center]", exists = "false" }
      ]
    }
    then = { effect = "deny" }
  })
}

resource "azurerm_subscription_policy_assignment" "required_tags" {
  count                = var.enable_subscription_governance ? 1 : 0
  name                 = "restsim-prod-tags"
  display_name         = "RestSim production required tags"
  subscription_id      = "/subscriptions/${var.subscription_id}"
  policy_definition_id = azurerm_policy_definition.required_tags[0].id
}

resource "azurerm_consumption_budget_subscription" "production" {
  count           = var.enable_subscription_governance ? 1 : 0
  name            = "budget-restsim-production"
  subscription_id = "/subscriptions/${var.subscription_id}"
  amount          = var.monthly_budget_amount
  time_grain      = "Monthly"
  time_period {
    start_date = var.budget_start_date
  }
  notification {
    enabled        = true
    operator       = "GreaterThanOrEqualTo"
    threshold      = 80
    threshold_type = "Actual"
    contact_emails = [var.alert_email]
    contact_groups = [azurerm_monitor_action_group.operations.id]
  }
  notification {
    enabled        = true
    operator       = "GreaterThanOrEqualTo"
    threshold      = 100
    threshold_type = "Forecasted"
    contact_emails = [var.alert_email]
    contact_groups = [azurerm_monitor_action_group.operations.id]
  }
}
