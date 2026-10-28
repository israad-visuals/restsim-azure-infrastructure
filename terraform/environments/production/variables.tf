variable "subscription_id" {
  description = "Azure subscription for RestSim production resources."
  type        = string
  validation {
    condition     = can(regex("^[0-9a-fA-F]{8}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-[0-9a-fA-F]{12}$", var.subscription_id))
    error_message = "Enter the production subscription ID as a UUID."
  }
}
variable "tenant_id" {
  description = "Microsoft Entra tenant for the production subscription."
  type        = string
  validation {
    condition     = can(regex("^[0-9a-fA-F]{8}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-[0-9a-fA-F]{12}$", var.tenant_id))
    error_message = "Enter the production tenant ID as a UUID."
  }
}
variable "location" {
  description = "Azure region hosting the production infrastructure."
  type        = string
  default     = "eastus"
}
variable "owner" {
  description = "Resource owner recorded in production tags."
  type        = string
}
variable "cost_center" {
  description = "Cost-centre tag for production spending."
  type        = string
}
variable "extra_tags" {
  description = "Additional tags alongside the required production tags."
  type        = map(string)
  default     = {}
}
variable "public_hostname" {
  description = "RestSim hostname managed by the existing Cloudflare DNS configuration."
  type        = string
}
variable "admin_username" {
  description = "Administrator username for private VM access."
  type        = string
  default     = "restsimadmin"
}
variable "cloudflare_access_team_domain" {
  description = "Cloudflare Access team domain for admin token validation, without https://."
  type        = string
  validation {
    condition     = can(regex("^[a-z0-9-]+\\.cloudflareaccess\\.com$", var.cloudflare_access_team_domain))
    error_message = "Enter the existing team domain ending in .cloudflareaccess.com."
  }
}
variable "cloudflare_access_audience" {
  description = "Cloudflare Access audience identifying the admin application."
  type        = string
  validation {
    condition     = length(trimspace(var.cloudflare_access_audience)) > 0
    error_message = "Enter the audience ID for the existing admin Access app."
  }
}
variable "admin_ssh_public_key" {
  description = "SSH public key for private VM administration."
  type        = string
  validation {
    condition     = can(regex("^ssh-(rsa|ed25519) ", var.admin_ssh_public_key))
    error_message = "Enter an RSA or Ed25519 SSH public key."
  }
}
variable "private_management_cidrs" {
  description = "Connected private network ranges permitted to administer production resources."
  type        = list(string)
  default     = []
  validation {
    condition = alltrue([for c in var.private_management_cidrs :
      can(cidrnetmask(c)) && !contains(["0.0.0.0/0", "::/0"], c)
    ])
    error_message = "Enter specific IPv4 ranges for private access. Do not use 0.0.0.0/0."
  }
}
variable "approved_outbound_https_cidrs" {
  description = "Additional IPv4 destinations permitted for application HTTPS traffic."
  type        = list(string)
  default     = []
  validation {
    condition     = alltrue([for c in var.approved_outbound_https_cidrs : can(cidrnetmask(c)) && c != "0.0.0.0/0"])
    error_message = "Enter specific IPv4 destination ranges. Do not use 0.0.0.0/0."
  }
}
variable "cloudflare_ipv4_cidrs" {
  description = "Cloudflare IPv4 ranges permitted to reach the production origin."
  type        = list(string)
  default = [
    "173.245.48.0/20",
    "103.21.244.0/22",
    "103.22.200.0/22",
    "103.31.4.0/22",
    "141.101.64.0/18",
    "108.162.192.0/18",
    "190.93.240.0/20",
    "188.114.96.0/20",
    "197.234.240.0/22",
    "198.41.128.0/17",
    "162.158.0.0/15",
    "104.16.0.0/13",
    "104.24.0.0/14",
    "172.64.0.0/13",
    "131.0.72.0/22"
  ]
  validation {
    condition = length(var.cloudflare_ipv4_cidrs) > 0 && alltrue([
      for c in var.cloudflare_ipv4_cidrs : can(cidrnetmask(c)) && c != "0.0.0.0/0"
    ])
    error_message = "Enter specific Cloudflare IPv4 ranges."
  }
}
variable "vmss_sku" {
  description = "VM size for production web and API instances."
  type        = string
  default     = "Standard_D2s_v5"
}
variable "worker_sku" {
  description = "VM size for the production background worker."
  type        = string
  default     = "Standard_D2s_v5"
}
variable "vmss_max_instances" {
  description = "Maximum web instance count; the scale set retains at least two instances."
  type        = number
  default     = 4
  validation {
    condition     = var.vmss_max_instances >= 2 && floor(var.vmss_max_instances) == var.vmss_max_instances
    error_message = "Enter a whole number of 2 or more."
  }
}
variable "base_image" {
  description = "Ubuntu VM image reference with an exact version."
  type = object({
    publisher = string
    offer     = string
    sku       = string
    version   = string
  })
  validation {
    condition     = can(regex("^[0-9]+\\.[0-9]+\\.[0-9]+$", var.base_image.version))
    error_message = "Enter an exact image version, such as 1.2.3."
  }
}
variable "approved_web_application_version_id" {
  description = "Exact Gallery application-version ID for the production web release."
  type        = string
  validation {
    condition     = can(regex("/galleries/[^/]+/applications/[^/]+/versions/[0-9]+\\.[0-9]+\\.[0-9]+$", var.approved_web_application_version_id))
    error_message = "Enter the full Gallery app version ID ending in a number such as 1.2.3. Do not use latest."
  }
}
variable "approved_worker_application_version_id" {
  description = "Initial worker application-version ID; later updates follow the separate worker release process."
  type        = string
  validation {
    condition     = can(regex("/galleries/[^/]+/applications/[^/]+/versions/[0-9]+\\.[0-9]+\\.[0-9]+$", var.approved_worker_application_version_id))
    error_message = "Enter the full worker app version ID ending in a number such as 1.2.3."
  }
}
variable "deploy_compute" {
  description = "Controls production VM deployment. Disabling this schedules existing VMs for removal."
  type        = bool
  default     = true
}
variable "readiness_port" {
  description = "Private HTTP port for load-balancer readiness probes."
  type        = number
  default     = 8081
  validation {
    condition = (
      floor(var.readiness_port) == var.readiness_port &&
      var.readiness_port >= 1024 &&
      var.readiness_port <= 65535 &&
      !contains([443, 5432, 10000], var.readiness_port)
    )
    error_message = "Choose a separate readiness port from 1024 to 65535. Do not use a database or Redis port."
  }
}
variable "readiness_path" {
  description = "Readiness endpoint returning HTTP 200 when the application and required dependencies are ready."
  type        = string
  default     = "/health/ready"
}
variable "postgres_sku" {
  description = "PostgreSQL compute size supporting zone-redundant high availability."
  type        = string
  default     = "GP_Standard_D2s_v3"
  validation {
    condition     = startswith(var.postgres_sku, "GP_") || startswith(var.postgres_sku, "MO_")
    error_message = "Use a General Purpose or Memory Optimized PostgreSQL size for high availability."
  }
}
variable "postgres_version" {
  description = "PostgreSQL major version for the application database."
  type        = string
  default     = "16"
}
variable "postgres_storage_mb" {
  description = "Initial PostgreSQL storage capacity in MiB."
  type        = number
  default     = 32768
}
variable "postgres_admin_username" {
  description = "Database administrator login, separate from the application login."
  type        = string
  default     = "restsimadmin"
}
variable "postgres_application_username" {
  description = "PostgreSQL application login with workload-specific permissions."
  type        = string
  default     = "restsim_app"
}
variable "postgres_application_password" {
  description = "Application database password stored in Terraform state and Key Vault."
  type        = string
  sensitive   = true
  validation {
    condition     = length(var.postgres_application_password) >= 24
    error_message = "Use a strong application password of at least 24 characters."
  }
}
variable "redis_sku" {
  description = "Azure Managed Redis size with high availability enabled."
  type        = string
  default     = "Balanced_B0"
}
variable "files_quota_gb" {
  description = "Azure Files share capacity limit in GiB."
  type        = number
  default     = 100
}
variable "deployment_operator_object_id" {
  description = "Entra object ID of the infrastructure provisioning identity, separate from CI identities."
  type        = string
  validation {
    condition     = can(regex("^[0-9a-fA-F]{8}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-[0-9a-fA-F]{12}$", var.deployment_operator_object_id))
    error_message = "Enter the setup operator's Entra object ID as a UUID."
  }
}

variable "origin_tls_certificate_pem" {
  description = "PEM server certificate for the Azure origin, trusted by Cloudflare Full (strict)."
  type        = string
  sensitive   = true
}
variable "origin_tls_private_key_pem" {
  description = "Sensitive PEM private key for the origin TLS certificate."
  type        = string
  sensitive   = true
}
variable "cloudflare_origin_pull_ca_pem" {
  description = "CA certificate for Cloudflare client-certificate validation; null when AOP is disabled."
  type        = string
  default     = null
  validation {
    condition     = !var.require_authenticated_origin_pulls || try(strcontains(var.cloudflare_origin_pull_ca_pem, "BEGIN CERTIFICATE"), false)
    error_message = "Add the matching client CA certificate in PEM format before turning on AOP."
  }
}
variable "require_authenticated_origin_pulls" {
  description = "Enables origin client-certificate enforcement for the configured Cloudflare AOP connection."
  type        = bool
  default     = false
}
variable "application_secrets" {
  description = "Application secrets indexed by Key Vault secret name."
  type        = map(string)
  sensitive   = true
  default     = {}
  validation {
    condition = alltrue([for k in keys(var.application_secrets) :
      can(regex("^[0-9A-Za-z-]{1,127}$", k)) && !contains([
        "postgres-admin-password", "postgres-application-username", "postgres-application-password",
        "azure-files-account-key", "redis-session-key", "origin-tls-certificate",
        "origin-tls-private-key", "cloudflare-origin-pull-ca", "application-insights-connection-string"
      ], k)
    ])
    error_message = "Use valid Key Vault secret names that are not already used by this code."
  }
}
variable "alert_email" {
  description = "Operations email receiving monitoring alerts and budget notifications."
  type        = string
}
variable "monthly_budget_amount" {
  description = "Monthly budget in the subscription billing currency; notifications do not cap spending."
  type        = number
  validation {
    condition     = var.monthly_budget_amount > 0
    error_message = "Enter a positive monthly budget amount."
  }
}
variable "budget_start_date" {
  description = "Budget period start, using the first day of the month in UTC."
  type        = string
  validation {
    condition     = can(regex("^[0-9]{4}-[0-9]{2}-01T00:00:00Z$", var.budget_start_date))
    error_message = "Use the first day of the budget month, such as 2026-11-01T00:00:00Z."
  }
}
variable "enable_subscription_governance" {
  description = "Enables region policies, required tags and a subscription budget."
  type        = bool
  default     = true
}
variable "management_group_id" {
  description = "Existing RestSim management-group ID for the production subscription association."
  type        = string
  default     = null
}
variable "production_role_assignments" {
  description = "Production subscription role assignments grouped by operational purpose."
  type = map(object({
    principal_id         = string
    role_definition_name = string
  }))
  default = {}
}
variable "enable_github_oidc" {
  description = "Enables separate OIDC identities for infrastructure, artifact publishing and application releases."
  type        = bool
  default     = true
}
variable "github_infrastructure_oidc_subject" {
  description = "Exact OIDC subject for the protected GitHub infrastructure job."
  type        = string
  default     = null
  validation {
    condition     = !var.enable_github_oidc || can(regex("^repo:.+:environment:.+$", var.github_infrastructure_oidc_subject))
    error_message = "Enter the exact OIDC subject for the protected GitHub environment. Check the repository prefix first."
  }
}
variable "github_publisher_oidc_subject" {
  description = "Exact OIDC subject for the protected application-package publishing job."
  type        = string
  default     = null
  validation {
    condition     = !var.enable_github_oidc || can(regex("^repo:.+:environment:.+$", var.github_publisher_oidc_subject))
    error_message = "Enter the exact OIDC subject for the protected GitHub environment. Check the repository prefix first."
  }
}
variable "github_release_oidc_subject" {
  description = "Exact OIDC subject for the protected application-release job."
  type        = string
  default     = null
  validation {
    condition     = !var.enable_github_oidc || can(regex("^repo:.+:environment:.+$", var.github_release_oidc_subject))
    error_message = "Enter the exact OIDC subject for the protected GitHub environment. Check the repository prefix first."
  }
  validation {
    condition     = !var.enable_github_oidc || var.github_release_oidc_subject != var.github_publisher_oidc_subject
    error_message = "Use different protected OIDC subjects for publishing and production releases."
  }
}
