variable "subscription_id" {
  description = "Development subscription ID, separate from production."
  type        = string
  validation {
    condition = (
      can(regex("^[0-9a-fA-F]{8}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-[0-9a-fA-F]{12}$", var.subscription_id)) &&
      lower(var.subscription_id) != lower(var.production_subscription_id)
    )
    error_message = "Use the development subscription UUID, different from production."
  }
}

variable "production_subscription_id" {
  description = "Production subscription ID used by the environment-isolation guard."
  type        = string
  validation {
    condition     = can(regex("^[0-9a-fA-F]{8}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-[0-9a-fA-F]{12}$", var.production_subscription_id))
    error_message = "Enter the production subscription UUID for the isolation check."
  }
}

variable "tenant_id" {
  description = "Microsoft Entra tenant for development resources and sign-in."
  type        = string
  validation {
    condition     = can(regex("^[0-9a-fA-F]{8}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-[0-9a-fA-F]{12}$", var.tenant_id))
    error_message = "Enter a tenant UUID."
  }
}

variable "location" {
  description = "Azure region hosting the development infrastructure."
  type        = string
  default     = "canadacentral"
}

variable "owner" {
  description = "Resource owner recorded in development tags."
  type        = string
  validation {
    condition     = length(trimspace(var.owner)) > 0
    error_message = "Set an owner for cost and resource tracking."
  }
}

variable "admin_ssh_public_key" {
  description = "VM administrator public key; inbound SSH remains blocked."
  type        = string
  validation {
    condition     = can(regex("^ssh-(ed25519|rsa) [A-Za-z0-9+/=]+", trimspace(var.admin_ssh_public_key)))
    error_message = "Use an OpenSSH public key, never a private key."
  }
}

variable "vm_size" {
  description = "Development VM size; default capacity is 2 vCPUs and 4 GiB RAM."
  type        = string
  default     = "Standard_B2als_v2"
}

variable "ubuntu_image_version" {
  description = "Ubuntu 22.04 Gen2 image version for the development VM."
  type        = string
  default     = "latest"
}

variable "postgres_admin_password" {
  description = "Sensitive development database administrator password, separate from application credentials."
  type        = string
  sensitive   = true
  ephemeral   = true
  validation {
    condition = (
      length(var.postgres_admin_password) >= 20 &&
      length(var.postgres_admin_password) <= 128 &&
      can(regex("[A-Z]", var.postgres_admin_password)) &&
      can(regex("[a-z]", var.postgres_admin_password)) &&
      can(regex("[0-9]", var.postgres_admin_password)) &&
      can(regex("[^A-Za-z0-9]", var.postgres_admin_password))
    )
    error_message = "Use a unique 20-128 character password with upper/lowercase letters, numbers and symbols."
  }
}

variable "postgres_password_version" {
  description = "Password rotation counter for the write-only database administrator credential."
  type        = number
  default     = 1
  validation {
    condition     = var.postgres_password_version >= 1 && floor(var.postgres_password_version) == var.postgres_password_version
    error_message = "Use a positive whole-number password version."
  }
}

variable "staging_zone_name" {
  description = "Development-only public DNS zone; null omits zone creation."
  type        = string
  default     = null
  validation {
    condition     = var.staging_zone_name == null ? true : can(regex("^[a-z0-9][a-z0-9.-]+\\.[a-z]{2,}$", var.staging_zone_name))
    error_message = "Use a lowercase DNS zone name without a protocol or path."
  }
}

variable "enable_staging_ingress" {
  description = "Controls HTTPS access to the identity-protected staging application."
  type        = bool
  default     = false
}

variable "staging_authentication_verified" {
  description = "Release-readiness confirmation for staging TLS, Entra sign-in, developer access and upstream isolation."
  type        = bool
  default     = false
}

variable "staging_client_id" {
  description = "Client ID of the single-tenant development Entra application."
  type        = string
  default     = null
  validation {
    condition     = var.staging_client_id == null ? true : can(regex("^[0-9a-fA-F]{8}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-[0-9a-fA-F]{12}$", var.staging_client_id))
    error_message = "Use the development Entra app registration client UUID."
  }
}

variable "staging_developer_emails" {
  description = "Exact developer accounts permitted through the staging sign-in proxy."
  type        = set(string)
  default     = []
  validation {
    condition     = alltrue([for email in var.staging_developer_emails : can(regex("^[^ *@]+@[^ *@]+\\.[^ *@]+$", email))])
    error_message = "Provide exact email addresses, without wildcards or spaces."
  }
}

variable "staging_access_cidrs" {
  description = "IPv4 client networks permitted to reach staging HTTPS."
  type        = list(string)
  default     = []
  validation {
    condition = (
      alltrue([for cidr in var.staging_access_cidrs : try(cidrhost(cidr, 0) == split("/", cidr)[0] &&
      can(cidrnetmask(cidr)), false)])
    )
    error_message = "Each staging access entry must be an IPv4 network CIDR, for example 203.0.113.0/24."
  }
}

variable "extra_https_egress_cidrs" {
  description = "Additional IPv4 destinations for package and update downloads over HTTPS."
  type        = list(string)
  default     = []
  validation {
    condition = (
      alltrue([for cidr in var.extra_https_egress_cidrs : try(cidrhost(cidr, 0) == split("/", cidr)[0] &&
      !contains(["0.0.0.0", "128.0.0.0"], cidrnetmask(cidr)), false)])
    )
    error_message = "Use IPv4 network CIDRs with the network address, not host bits, IPv6 or a /0-/1 Internet rule."
  }
}

variable "alert_email" {
  description = "Operations email receiving development infrastructure alerts."
  type        = string
  validation {
    condition     = can(regex("^[^ @]+@[^ @]+\\.[^ @]+$", var.alert_email))
    error_message = "Enter a valid notification email."
  }
}

variable "enable_vm_run_command" {
  description = "Enables the VM agent HTTPS response path for administration without public SSH."
  type        = bool
  default     = true
}
