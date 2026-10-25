# RestSim production infrastructure

This folder contains the Terraform for the production design. Development has its own folder. The code keeps the names and Terraform addresses of the four resource groups already in the local state.

**Local checks:** `terraform fmt -check` and `terraform validate` passed on October 23, 2026, with **0 errors and 0 warnings**. Providers were installed with the backend disabled. No plan, deployment, app installation or traffic switch was done. The checks show that Terraform accepts the configuration; they do not show that the app works on Azure.

## Where to start reading

Most resources have their own block. Start with the resource groups, then the network and its security rules.

| File | What it does |
| --- | --- |
| `versions.tf`, `providers.tf` | Set Terraform and provider versions and the Azure connection |
| `resource_groups.tf`, `locals.tf` | Define the four resource groups, tags and shared app settings |
| `network.tf`, `security.tf` | Create the network, subnets, DNS, load balancer, NAT and NSG rules |
| `key_vault.tf` | Store app secrets in Key Vault |
| `compute.tf`, `gallery.tf` | Create the web VMs, worker and Compute Gallery, and give the VMs access to their secrets |
| `database.tf`, `storage.tf`, `backups.tf` | Create PostgreSQL, Files, Redis, private endpoints and backups |
| `monitoring.tf` | Collect logs and send alerts |
| `governance.tf`, `cicd.tf` | Set policies, budget and GitHub identity permissions |
| `backend.tf`, `outputs.tf` | Configure remote state and show useful resource details |

A few loops are still used for extra secrets, access roles and the log categories supported by Azure. Some resource labels changed when loops were replaced with separate blocks. The saved state contains only the four resource groups, and their addresses were kept. Review addresses first if using this code with a different state.

## What the code creates

| Part | Production design |
| --- | --- |
| Resource groups | `rg-restsim-prod-network`, `rg-restsim-prod-app`, `rg-restsim-prod-data`, `rg-restsim-prod-monitoring` |
| VNet | `vnet-restsim-prod`, `10.20.0.0/22` |
| Subnets | App `10.20.1.0/24`, PostgreSQL `10.20.2.0/24`, private endpoints `10.20.3.0/24`. Keep `10.20.0.0/24` free. |
| Incoming traffic | Cloudflare → Standard public IP → Standard Load Balancer → Apache on the web VMs |
| Web servers | Two Linux VMSS instances in zones 1 and 2; autoscale up to four by default |
| Worker | One private VM with its own identity and one scheduler owner |
| Database | Private PostgreSQL Flexible Server with zone redundancy and 35 days of backups |
| Files and sessions | ZRS Azure Files and Azure Managed Redis with high availability, encrypted port 10000 and hourly RDB snapshots |
| Secrets | Private Key Vault with purge protection. VM access is limited to individual app secrets. |
| App packages | Private Blob Storage and a Compute Gallery VM Application, with a publishing identity |
| Monitoring | Application Insights, Log Analytics, guest logs, service logs, alerts and email notifications |
| Recovery | PostgreSQL backups and daily/weekly Azure Files snapshot backups |
| Subscription settings | Region and tag policies, budget alerts, access roles and an optional link to an existing management group |
| GitHub access | Separate OIDC identities for Terraform, package publishing and app releases |

The network also has private DNS, a Blob private endpoint for publishing, separate NSGs and StandardV2 NAT for outbound access. This code does not create a Firewall, Bastion, VPN, management groups or development resources.

## Values to fill in first

Use `terraform.tfvars.example` as a guide. Replace its placeholders with the real tenant and subscription IDs, SSH public key, private runner IP ranges, alert email, budget, certificate, app secrets and exact image/package versions. Add the existing Cloudflare Access team domain and audience ID. The example contains no working credentials.

The region is `eastus`, as in the original code. Check costs, quotas and support for the selected VM sizes, availability zones, PostgreSQL HA, Redis HA, StandardV2 NAT and ZRS storage. The example sizes are starting points. The code does not switch to a service without high availability if one of these options is unavailable. Redis uses Azure's automatic zone placement in a supported region.

Keep the Cloudflare IPv4 list up to date. The NSG only allows Cloudflare to reach ports 80 and 443. Apache must redirect port 80 to HTTPS and handle the certificate on 443. The load balancer forwards TCP traffic; it cannot redirect HTTP or handle TLS for the app.

This Terraform does not change Cloudflare DNS or SSL settings. Check the current zone configuration before connecting an Azure origin. Supply a valid certificate for the new Azure servers. A move to Full (strict) needs a separate certificate check and Cloudflare change.

AOP stays off by default. Only enable it after matching client certificates and trust settings are set up at both ends. A shared Cloudflare AOP certificate proves the request came through Cloudflare; a custom certificate for the zone can identify that zone. Test the HTTP redirect and certificate checks before switching traffic.

## Keep the existing state

The local `terraform.tfstate` already tracks four resource groups. It was left unchanged. Keep its private backup and move that state when setting up remote storage. Do not start with an empty state for the same resources.

`backend.tf` expects a separate Azure Blob state backend that already exists. Create its storage, private connection and permissions separately. This keeps the workload from deleting its own state storage. `backend.hcl.example` contains settings, not credentials.

When deployment is authorized, fill in an ignored `backend.hcl` and use Terraform's documented `init -migrate-state` process to move the local state. `-reconfigure` does not move state and is not a substitute.

The lock file selects AzureRM **4.81.0**, Random **3.9.1** and AzAPI **2.13.0**. Local initialization added AzAPI and checked its signature. The existing AzureRM and Random versions stayed the same. The production backend was not initialized or migrated.

Terraform state holds passwords, keys and other sensitive inputs. Use encrypted state storage with versioning and limited access. Keep state, saved plans, tfvars and private keys out of Git. Marking a value `sensitive` hides it from normal output but does not remove it from state.

## Private access and setup permissions

Run Terraform from a private runner that can already resolve the private DNS names and reach Key Vault on port 443. Adding `private_management_cidrs` only adds NSG rules. It does not create a VPN, peering or a route. Set up the connection and DNS forwarding separately. Public SSH and temporary public vault access are not enabled.

The subscription administrator must register the Azure resource providers first. Automatic registration is off. Required providers are `Microsoft.Compute`, `Microsoft.Network`, `Microsoft.Storage`, `Microsoft.KeyVault`, `Microsoft.DBforPostgreSQL`, `Microsoft.Cache`, `Microsoft.Insights`, `Microsoft.OperationalInsights`, `Microsoft.ManagedIdentity`, `Microsoft.RecoveryServices`, `Microsoft.Authorization` and, where needed, `Microsoft.Consumption`.

The first setup needs permission to create the resources and assign roles. Use the setup operator's stable Entra object ID for vault access. Do not replace it with whichever identity runs a later CI job. Role changes can take time to work; retry from the private runner instead of opening the vault firewall.

The Terraform GitHub identity has access to the four resource groups, vault secrets and the configured state container. New resource groups, role grants, subscription policies and budgets still need an operator with those permissions. The automation identity does not get Owner. Its current roles alone cannot apply every part of this folder.

## Order for the first deployment

1. Review the target subscription and move the existing state to the separate backend from the private runner.
2. Set `deploy_compute=false` for the first setup. Create the resources before the VMs and check private access. The version ID inputs must still have the right format, but Azure does not read them until the VMs are enabled.
3. Extend the existing RestSim release process to build one real Linux package, record its SHA256 and manifest, upload it to private Blob Storage and publish a Gallery version. Use the Gallery identity to read the package. Test it in isolated staging and complete the release approvals.
4. Use the database migration to create the app login and tables. Give this login only the permissions the app needs. Its password must match the app password in Key Vault. Keep the admin password for database setup and migration.
5. Set `deploy_compute=true` with exact web and worker package version IDs. The package must follow the requirements below. App startup must retry secret access while new identity permissions take effect.
6. Test health checks, TLS, sessions across VMs, shared files, private data access, alert emails, backup recovery, worker ownership and cost. After those tests, a separately authorized operator can change the intended Cloudflare app record. Do not bulk-change other records such as staff, careers or mail.

Do not use `deploy_compute=false` to remove VMs after they exist. `prevent_destroy` protects the VMSS, worker and stored data. Moving or renaming resources already in state needs a planned state move or import.

## What the app package must do

This Terraform does not include the RestSim installer, a database migration or a fake healthy app. The existing app pipeline must provide install, update and removal commands. The package needs to:

- Wait for `/etc/restsim/runtime.json`. Cloud-init writes endpoints, secret names, role and other settings there. It does not write secret values or app version pins.
- Install the actual web/API app and its dependencies. Disable every scheduler on web VMs. Start the worker only through its separate release step, with one verified scheduler owner or lease.
- Configure Apache's HTTP redirect and HTTPS certificate. If AOP is enabled, reject missing or untrusted client certificates.
- Serve the private readiness path, normally `/health/ready` on port 8081. Return 200 only when the expected version and required PostgreSQL, Redis and Files connections are ready. Do not expose this listener publicly or use an always-200 placeholder.
- Use the VM's managed identity to read only its allowed vault secrets. Use limited retries while permissions become available. The installer must not wait forever, and the app must not use the database admin login.
- Validate PostgreSQL's TLS certificate. Connect to Redis over encrypted port 10000, retry failed connections with a limit and give sessions expiry times. Redis HA and snapshots do not guarantee that every session survives a failure or that payments are correct.
- Mount Azure Files using SMB 3.1.1, encryption (`seal`) and a key read from Key Vault. Protect the mount credentials so only root can read them. Set **`RESTSIM_PUBLIC_UPLOADS_DIR`** to the shared uploads directory and test real files through the app. A managed identity alone does not authenticate this SMB mount.
- Load the Application Insights connection string and instrument the app. Azure Monitor Agent collects VM logs and heartbeat; it does not add app request tracking by itself.

Keep Apache's `CF-Connecting-IP` handling limited to trusted Cloudflare networks. Keep Express proxy trust set to `loopback`, rather than a guessed hop count. The package must load and enforce `ADMIN_CLOUDFLARE_ACCESS_REQUIRED=true`, `CLOUDFLARE_ACCESS_TEAM_DOMAIN` and `CLOUDFLARE_ACCESS_AUD`. Test both allowed and blocked requests on `/admin/*` and `/api/admin/*`. Settings alone do not prove that admin access or MFA works.

Keep the existing loopback routes: web/API on 5083, the exact Stripe webhook route on 5016, WebSockets on 5067 and the separate worker on 5080. The webhook and WebSocket releases have separate version pins. Keep these until a combined release has been tested. These ports are not opened publicly or across subnets, and the load balancer cannot route by URL path. The current static health response only shows that a process responds; the real readiness handler still needs to be written and tested.

Do not include secrets or customer data in a Gallery package. The package, migration, readiness code and valid certificates are still needed before deployment.

## App updates and recovery

Terraform sets the first app version on the VMSS and worker. It then ignores changes to their `gallery_application` settings. The app pipeline owns later version changes and rollback. This avoids an infrastructure apply undoing a release, and avoids AzureRM 4.81 replacing a VMSS because its Gallery version changed. Autoscale owns the live web VM count.

After a successful web release, handle the worker separately: drain it, stop the old worker, check scheduler ownership, update its exact version, then start it. Automatic Gallery updates are off for the worker. Test this process and rollback; the Terraform does not prove that releases have no downtime or that only one worker runs.

The Gallery reads private packages using its managed identity and Azure Storage's trusted-service exception. The private publishing runner uses the Blob private endpoint. Test Gallery package access and backup service access during the first deployment. Do not open storage to the public to make these work.

## Traffic rules

| From | To | Port | Allowed traffic |
| --- | --- | --- | --- |
| Cloudflare IPv4 ranges | Web VMs through the load balancer | TCP 80/443 | HTTP redirect and HTTPS |
| Azure Load Balancer | App readiness listener | TCP readiness port | Health checks |
| Connected private admin ranges | App subnet | TCP 22 | SSH, when configured |
| App subnet | PostgreSQL subnet | TCP 5432 | Database connections |
| PostgreSQL subnet | Same subnet | TCP 5432 | PostgreSQL HA traffic |
| App subnet | Private endpoints | TCP 443/445/10000 | Vault/Blob, Files and Redis |
| Connected private runner ranges | Private endpoints / PostgreSQL | TCP 443/445 / 5432 | Access when configured |
| App subnet | AzureCloud | TCP 443 | Azure APIs, Gallery and telemetry |
| App subnet | Cloudflare IPv4 ranges | TCP 443 | Access signing keys; check the team domain resolves to these ranges |
| App subnet | Extra configured IPv4 ranges | TCP 443 | External HTTPS services |
| App and database subnets | Azure DNS | UDP/TCP 53 | DNS lookups |
| PostgreSQL subnet | Storage / Entra service tags | TCP 443 | Azure service connections |
| Other sources or destinations | Protected subnets / outbound access | Any | Blocked by explicit deny rules before Azure's default rules |

NSGs filter IP addresses and ports, not website names. The AzureCloud rule is broader than a list of app hostnames. NAT supplies an outbound IP; it does not check hostnames. If that is required, design and price a separate outbound filtering service. NSG policies are enabled on the private endpoint subnet. PostgreSQL uses a delegated subnet, not a PostgreSQL private endpoint.

## Monitoring, backup and pipeline limits

Budget alerts do not stop spending. Log Analytics keeps 30 days of logs and has a 5 GB/day cap. Hitting the cap can leave gaps in monitoring. App telemetry sampling is 100%; review actual log volume and cost. Test alert emails and adjust limits using real measurements.

Files backups keep daily snapshots for 30 days and weekly snapshots for 12 weeks. These are not proof of recovery in another region or an isolated backup archive. PostgreSQL has backups in another region, but recovery time has not been tested. Check that soft delete is enabled on the Recovery Services vault before protecting data; AzureRM 4.81 has no `soft_delete_enabled` setting on this resource. The worker remains a single scheduler owner.

Reuse `israad-visuals/RestSim-Web` and its existing workflows: `ci.yml` for Web CI, `nightly-full-regression.yml` for Full RQOS and `deploy-smoke.yml` for checks against a deployed URL. Full RQOS has no nightly schedule despite its filename. The smoke workflow does not deploy. The existing VPS release process uses operator-run scripts. This folder does not add a competing app pipeline or claim that Azure publishing and rollout already work.

Require fresh passing Web CI/RQOS results for the exact commit before an Azure release. Configure branch protection to require the relevant checks; old exceptions do not replace them.

Use the exact `github_*_oidc_subject` values from the selected GitHub jobs. Terraform uses the infrastructure repo; app publishing and releases extend the Web repo. Their subject formats differ: the Web repo uses its name, while the newer infrastructure repo includes owner/repository IDs. Do not guess a shared prefix.

At the time of review, neither repo had deployment environments set up. Create and check the protected environments, branch rules and approvals before enabling Azure jobs. Publishing and production release need different OIDC subjects. No OIDC token needs to be stored here. Azure identity settings alone do not prove that CI, approvals or deployment work.

## Checks completed locally

- Terraform 1.16.6 formatting and validation passed with zero errors and warnings.
- Two deprecated Blob container references now use the supported `id` property.
- Source checks cover subnet ranges, NSG rules, private access, secret permissions, VM identities and exact release versions.
- Input checks reject an unpinned image version, unrestricted extra HTTPS access and the same OIDC subject for publishing and release.
- The existing resource-group state stayed unchanged. The lock file gained AzAPI; AzureRM and Random were not upgraded. No backend migration was done.

The remaining checks need real inputs and a separately authorized plan and deployment: region support, quotas, private runner access, app installation, database migration, recovery and release behaviour.

## Official references

- [AzureRM 4.81.0 resource reference](https://github.com/hashicorp/terraform-provider-azurerm/tree/v4.81.0/website/docs/r)
- [Microsoft AzAPI resource reference](https://registry.terraform.io/providers/Azure/azapi/latest/docs/resources/resource)
- [Gallery API and managed identity](https://learn.microsoft.com/en-us/azure/templates/microsoft.compute/2024-03-03/galleries)
- [Publish VM Applications with managed identity](https://learn.microsoft.com/en-us/azure/virtual-machines/vm-applications-publish-with-managed-identity)
- [VM Applications](https://learn.microsoft.com/en-us/azure/virtual-machines/vm-applications)
- [PostgreSQL private networking](https://learn.microsoft.com/en-us/azure/postgresql/network/concepts-networking-private)
- [Azure Managed Redis architecture](https://learn.microsoft.com/en-us/azure/redis/architecture)
- [Managed Redis Private Link](https://learn.microsoft.com/en-us/azure/redis/private-link)
- [Private endpoint network policies](https://learn.microsoft.com/en-us/azure/private-link/disable-private-endpoint-network-policy)
- [Azure Storage trusted-service exceptions](https://learn.microsoft.com/en-us/azure/storage/common/storage-network-security-trusted-azure-services)
- [Azure Files security](https://learn.microsoft.com/en-us/azure/storage/files/secure-files)
- [StandardV2 NAT](https://learn.microsoft.com/en-us/azure/nat-gateway/nat-overview)
- [GitHub OIDC to Azure](https://learn.microsoft.com/en-us/azure/developer/github/connect-from-azure-openid-connect)
- [Terraform Azure backend](https://developer.hashicorp.com/terraform/language/backend/azurerm)
- [Terraform state migration](https://developer.hashicorp.com/terraform/cli/commands/init)
- [Cloudflare published ranges](https://www.cloudflare.com/ips-v4) and [origin authentication](https://developers.cloudflare.com/ssl/origin-configuration/authenticated-origin-pull/)
- [HashiCorp Terraform style guide](https://developer.hashicorp.com/terraform/language/style)
- [GitHub OIDC subject formats](https://docs.github.com/en/actions/reference/security/oidc)
