locals {
  environment = "Production"
  prefix      = "restsim-prod"
  suffix      = random_string.resource_suffix.result
  tags = merge(var.extra_tags, {
    project     = "RestSim"
    environment = local.environment
    owner       = var.owner
    cost_center = var.cost_center
    managed_by  = "Terraform"
  })
  resource_groups = {
    network    = azurerm_resource_group.rg-restsim-prod-network.id
    app        = azurerm_resource_group.rg-restsim-prod-app.id
    data       = azurerm_resource_group.rg-restsim-prod-data.id
    monitoring = azurerm_resource_group.rg-restsim-prod-monitoring.id
  }
  runtime_configuration = {
    environment                   = local.environment
    public_hostname               = var.public_hostname
    http_redirect_port            = 80
    trusted_cloudflare_ipv4_cidrs = var.cloudflare_ipv4_cidrs
    client_ip_header              = "CF-Connecting-IP"
    express_trust_proxy           = "loopback"
    cloudflare_access_environment = {
      ADMIN_CLOUDFLARE_ACCESS_REQUIRED = "true"
      CLOUDFLARE_ACCESS_TEAM_DOMAIN    = var.cloudflare_access_team_domain
      CLOUDFLARE_ACCESS_AUD            = var.cloudflare_access_audience
    }

    apache_loopback_upstreams          = { web_api = 5083, stripe_webhook = 5016, websocket = 5067 }
    worker_loopback_port               = 5080
    vault_uri                          = azurerm_key_vault.production.vault_uri
    postgres_host                      = azurerm_postgresql_flexible_server.production.fqdn
    postgres_database                  = azurerm_postgresql_flexible_server_database.restsim.name
    postgres_username_secret           = "postgres-application-username"
    postgres_password_secret           = "postgres-application-password"
    files_account                      = azurerm_storage_account.files.name
    files_share                        = azurerm_storage_share.application.name
    files_key_secret                   = "azure-files-account-key"
    redis_host                         = azurerm_managed_redis.sessions.hostname
    redis_port                         = 10000
    redis_key_secret                   = "redis-session-key"
    origin_certificate_secret          = "origin-tls-certificate"
    origin_private_key_secret          = "origin-tls-private-key"
    require_authenticated_origin_pulls = var.require_authenticated_origin_pulls
    origin_pull_ca_secret              = var.require_authenticated_origin_pulls ? "cloudflare-origin-pull-ca" : null
    application_insights_secret        = "application-insights-connection-string"
    readiness_port                     = var.readiness_port
    readiness_path                     = var.readiness_path
  }
}

resource "random_string" "resource_suffix" {
  length  = 6
  upper   = false
  special = false
}
