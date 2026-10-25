variable "subscription_id" {
  description = "ID of the production Azure subscription. Check it before using Azure."
  type        = string
  validation {
    condition     = can(regex("^[0-9a-fA-F]{8}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-[0-9a-fA-F]{12}$", var.subscription_id))
    error_message = "Enter the production subscription ID as a UUID."
  }
}
variable "tenant_id" {
  description = "Microsoft Entra tenant ID for the production subscription."
  type        = string
  validation {
    condition     = can(regex("^[0-9a-fA-F]{8}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-[0-9a-fA-F]{12}$", var.tenant_id))
    error_message = "Enter the production tenant ID as a UUID."
  }
}
variable "location" {
  description = "Azure region for production. Check that the chosen sizes and availability zones are supported."
  type        = string
  default     = "eastus"
}
variable "owner" {
  description = "Team or person responsible for these resources. Used in tags."
  type        = string
}
variable "cost_center" {
  description = "Tag used to track production costs."
  type        = string
}
variable "extra_tags" {
  description = "Extra resource tags. These cannot replace the required production tags."
  type        = map(string)
  default     = {}
}
variable "public_hostname" {
  description = "RestSim hostname already using Cloudflare. This code does not change its DNS records."
  type        = string
}
variable "admin_username" {
  description = "VM administrator username. SSH is only allowed through a private connection."
  type        = string
  default     = "restsimadmin"
}
variable "cloudflare_access_team_domain" {
  description = "Existing Cloudflare Access team domain, without https://. Used to check admin sign-in tokens."
  type        = string
  validation {
    condition     = can(regex("^[a-z0-9-]+\\.cloudflareaccess\\.com$", var.cloudflare_access_team_domain))
    error_message = "Enter the existing team domain ending in .cloudflareaccess.com."
  }
}
variable "cloudflare_access_audience" {
  description = "Audience ID of the existing admin Access application. The app must check this in each token."
  type        = string
  validation {
    condition     = length(trimspace(var.cloudflare_access_audience)) > 0
    error_message = "Enter the audience ID for the existing admin Access app."
  }
}
variable "admin_ssh_public_key" {
  description = "SSH public key for private VM access. Do not use a private key here."
  type        = string
  validation {
    condition     = can(regex("^ssh-(rsa|ed25519) ", var.admin_ssh_public_key))
    error_message = "Enter an RSA or Ed25519 SSH public key."
  }
}
variable "private_management_cidrs" {
  description = "IP ranges of an already connected private runner or admin network. This does not create the connection."
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
  description = "Extra IPv4 ranges the app can reach over HTTPS. NSGs check IP addresses, not website names."
  type        = list(string)
  default     = []
  validation {
    condition     = alltrue([for c in var.approved_outbound_https_cidrs : can(cidrnetmask(c)) && c != "0.0.0.0/0"])
    error_message = "Enter specific IPv4 destination ranges. Do not use 0.0.0.0/0."
  }
}
variable "cloudflare_ipv4_cidrs" {
  description = "Cloudflare IPv4 ranges. Check https://www.cloudflare.com/ips-v4 before deployment."
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
  description = "VM size for the web servers. Check its cost and availability in the chosen zones."
  type        = string
  default     = "Standard_D2s_v5"
}
variable "worker_sku" {
  description = "VM size for the single background worker."
  type        = string
  default     = "Standard_D2s_v5"
}
variable "vmss_max_instances" {
  description = "Largest number of web VMs autoscale can create. At least two VMs stay running."
  type        = number
  default     = 4
  validation {
    condition     = var.vmss_max_instances >= 2 && floor(var.vmss_max_instances) == var.vmss_max_instances
    error_message = "Enter a whole number of 2 or more."
  }
}
variable "base_image" {
  description = "Ubuntu image used by the VMs. Choose an exact version."
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
  description = "Full ID of the Gallery app version tested in staging."
  type        = string
  validation {
    condition     = can(regex("/galleries/[^/]+/applications/[^/]+/versions/[0-9]+\\.[0-9]+\\.[0-9]+$", var.approved_web_application_version_id))
    error_message = "Enter the full Gallery app version ID ending in a number such as 1.2.3. Do not use latest."
  }
}
variable "approved_worker_application_version_id" {
  description = "Full ID of the first worker app version. Later updates use the separate worker release step."
  type        = string
  validation {
    condition     = can(regex("/galleries/[^/]+/applications/[^/]+/versions/[0-9]+\\.[0-9]+\\.[0-9]+$", var.approved_worker_application_version_id))
    error_message = "Enter the full worker app version ID ending in a number such as 1.2.3."
  }
}
variable "deploy_compute" {
  description = "Set false for the first setup, before the app package is published. Do not use false to remove existing VMs."
  type        = bool
  default     = true
}
variable "readiness_port" {
  description = "Private HTTP port used by load balancer health checks."
  type        = number
  default     = 8081
  validation {
    condition     = floor(var.readiness_port) == var.readiness_port && var.readiness_port >= 1024 && var.readiness_port <= 65535 && !contains([443, 5432, 10000], var.readiness_port)
    error_message = "Choose a separate readiness port from 1024 to 65535. Do not use a database or Redis port."
  }
}
variable "readiness_path" {
  description = "HTTP path that returns 200 only when the app version and its required services are ready."
  type        = string
  default     = "/health/ready"
}
variable "postgres_sku" {
  description = "PostgreSQL size that supports high availability across zones."
  type        = string
  default     = "GP_Standard_D2s_v3"
  validation {
    condition     = startswith(var.postgres_sku, "GP_") || startswith(var.postgres_sku, "MO_")
    error_message = "Use a General Purpose or Memory Optimized PostgreSQL size for high availability."
  }
}
variable "postgres_version" {
  description = "PostgreSQL major version. Check that the app and database migration support it."
  type        = string
  default     = "16"
}
variable "postgres_storage_mb" {
  description = "Starting PostgreSQL storage size in MiB."
  type        = number
  default     = 32768
}
variable "postgres_admin_username" {
  description = "Database admin used during setup. The running app must use a separate login."
  type        = string
  default     = "restsimadmin"
}
variable "postgres_application_username" {
  description = "Database login for the app. Create it during migration with only the permissions the app needs."
  type        = string
  default     = "restsim_app"
}
variable "postgres_application_password" {
  description = "Password for the app database login. Use the same password during migration. Stored in state and Key Vault."
  type        = string
  sensitive   = true
  validation {
    condition     = length(var.postgres_application_password) >= 24
    error_message = "Use a strong application password of at least 24 characters."
  }
}
variable "redis_sku" {
  description = "Azure Managed Redis size. High availability stays on; check region and zone support."
  type        = string
  default     = "Balanced_B0"
}
variable "files_quota_gb" {
  description = "Azure Files share size limit in GiB. Check storage needs and cost."
  type        = number
  default     = 100
}
variable "deployment_operator_object_id" {
  description = "Entra object ID of the person or identity doing the first setup. Keep this separate from later CI jobs."
  type        = string
  validation {
    condition     = can(regex("^[0-9a-fA-F]{8}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-[0-9a-fA-F]{12}$", var.deployment_operator_object_id))
    error_message = "Enter the setup operator's Entra object ID as a UUID."
  }
}

variable "origin_tls_certificate_pem" {
  description = "TLS certificate for the Azure web servers, in PEM format. Use Cloudflare Origin CA or another certificate trusted by Full (strict)."
  type        = string
  sensitive   = true
}
variable "origin_tls_private_key_pem" {
  description = "PEM private key for that certificate. Keep it out of Git."
  type        = string
  sensitive   = true
}
variable "cloudflare_origin_pull_ca_pem" {
  description = "CA certificate used to check Cloudflare AOP client certificates. Leave null when AOP is off. This is separate from the server certificate."
  type        = string
  default     = null
  validation {
    condition     = !var.require_authenticated_origin_pulls || try(strcontains(var.cloudflare_origin_pull_ca_pem, "BEGIN CERTIFICATE"), false)
    error_message = "Add the matching client CA certificate in PEM format before turning on AOP."
  }
}
variable "require_authenticated_origin_pulls" {
  description = "Require Cloudflare client certificates only after AOP is set up and checked. This code does not change Cloudflare."
  type        = bool
  default     = false
}
variable "application_secrets" {
  description = "Extra app secrets, using Key Vault secret names as keys. Do not put real secrets in the example file."
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
  description = "Email address for monitoring and budget alerts."
  type        = string
}
variable "monthly_budget_amount" {
  description = "Monthly budget in the subscription billing currency. Alerts do not stop spending."
  type        = number
  validation {
    condition     = var.monthly_budget_amount > 0
    error_message = "Enter a positive monthly budget amount."
  }
}
variable "budget_start_date" {
  description = "First day of the budget month, for example 2026-11-01T00:00:00Z."
  type        = string
  validation {
    condition     = can(regex("^[0-9]{4}-[0-9]{2}-01T00:00:00Z$", var.budget_start_date))
    error_message = "Use the first day of the budget month, such as 2026-11-01T00:00:00Z."
  }
}
variable "enable_subscription_governance" {
  description = "Create region and tag policies and a monthly budget. This needs subscription permissions."
  type        = bool
  default     = true
}
variable "management_group_id" {
  description = "ID of an existing RestSim management group. Leave null to skip linking the subscription."
  type        = string
  default     = null
}
variable "production_role_assignments" {
  description = "Production subscription access roles, listed by purpose."
  type = map(object({
    principal_id         = string
    role_definition_name = string
  }))
  default = {}
}
variable "enable_github_oidc" {
  description = "Create separate Azure identities for Terraform, package publishing and app releases. Reuse the existing RestSim pipeline."
  type        = bool
  default     = true
}
variable "github_infrastructure_oidc_subject" {
  description = "Exact OIDC subject for the Terraform job in a protected GitHub environment. Check the repository prefix; it may include IDs."
  type        = string
  default     = null
  validation {
    condition     = !var.enable_github_oidc || can(regex("^repo:.+:environment:.+$", var.github_infrastructure_oidc_subject))
    error_message = "Enter the exact OIDC subject for the protected GitHub environment. Check the repository prefix first."
  }
}
variable "github_publisher_oidc_subject" {
  description = "Exact OIDC subject for the publishing job in the existing Web pipeline. Use a protected GitHub environment."
  type        = string
  default     = null
  validation {
    condition     = !var.enable_github_oidc || can(regex("^repo:.+:environment:.+$", var.github_publisher_oidc_subject))
    error_message = "Enter the exact OIDC subject for the protected GitHub environment. Check the repository prefix first."
  }
}
variable "github_release_oidc_subject" {
  description = "Exact OIDC subject for the release job in the existing Web pipeline. Use a separate protected GitHub environment."
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
variable "terraform_state_container_id" {
  description = "Full Azure resource ID of the existing state container. Used to give the Terraform identity Blob Data Contributor access. Leave null to set this up separately."
  type        = string
  default     = null
}
