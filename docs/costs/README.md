# Cost planning and resource choices

[Project overview](../../README.md) · [Architecture](../architecture/README.md)

I reviewed the cost of each Terraform resource to see where RestSim's availability and security requirements added ongoing expense. I kept production's redundant application and data tiers, then used a smaller development footprint to avoid paying for the same capacity twice.

**Estimated monthly cost: CAD 1,007 for production and CAD 115 for development.** Prices were checked on October 29, 2026, using Microsoft's CAD retail rates, 730 running hours and the usage volumes listed below. Totals are before tax and credits.

## Monthly estimate

| Configuration | Fixed footprint | Usage allowance | Estimated monthly total |
| --- | ---: | ---: | ---: |
| Production: two web VMs and one worker | 870.36 | 136.72 | **1,007.08** |
| Development: one VM, smaller database | 99.86 | 14.93 | **114.79** |
| Both environments | 970.22 | 151.65 | **1,121.87** |
| Production with four web VMs for the whole month | 1,097.84 | 136.72 | **1,234.56** |

The four-web-VM comparison isolates the extra compute and disks; traffic and log allowances are held constant.

## Where the production cost goes

| Cost area | CAD/month |
| --- | ---: |
| Application VMs and OS disks | 341.22 |
| PostgreSQL primary, standby, storage and backup | 368.34 |
| Redis with high availability | 33.14 |
| Networking, private endpoints, DNS and egress | 144.01 |
| Logs, alerts and secret operations | 99.16 |
| Files, release blobs, snapshots and protection | 21.21 |
| **Production total** | **1,007.08** |

Application and database compute account for **CAD 651.45/month**, about 65% of the estimate. That makes workload sizing the largest cost decision. Logs add another **CAD 97.74/month** at the assumed 30 GB ingestion volume.

## How I kept costs lower

| Decision | Cost effect | Service requirement I kept |
| --- | --- | --- |
| Give development its own smaller footprint | **CAD 892.29/month less** than duplicating the production footprint, under this model. | An isolated environment with its own database, files, secrets and monitoring. |
| Use one B2als_v2 VM and B1ms PostgreSQL in development | Development compute is **CAD 62.34/month**; it does not carry the production worker, Redis, load balancer or HA standby. | Developers can stage changes separately, while production keeps its redundant tiers. |
| Start the production web tier at two instances | The baseline avoids the **CAD 227.48/month** compute-and-disk cost of keeping four web VMs running all month. Autoscaling can still add capacity up to four. | Two web instances across zones, with load-balancer health probes. |
| Use smaller disks and LRS storage in development | One 32 GiB Standard SSD costs **CAD 3.74/month**; file capacity is billed on occupied data. | Private file access and seven-day file soft deletion. Production keeps Premium OS disks and ZRS shared files. |
| Keep development telemetry lighter | A 25% Application Insights sampling setting, warning/error syslog collection and 30-day workspace retention reduce the collection footprint. | Separate Linux and service logs, CPU/storage alerts and email notifications. |
| Use managed identities and OIDC federation | Managed identity and federation have no additional service fee in this design. | Scoped Azure access without storing long-lived deployment passwords in GitHub. |

The **CAD 892.29** comparison is estimated cost avoidance: `1,007.08 − 114.79`. Using one production footprint plus a smaller development environment comes to CAD 1,121.87/month, compared with CAD 2,014.16 for two copies of the production cost model. Production and development are sized for different capacity and availability requirements.

## Keeping the production service requirements

I kept two web instances across availability zones, a separate worker, PostgreSQL zone-redundant HA and Redis HA in the production configuration. Those resources account for much of the cost, but address the original single-server failure risk and keep background processing separate from web requests.

I also retained private database connectivity, private endpoints for shared services, Key Vault, managed identities, TLS requirements, monitoring and file backups. Cost reductions in development come mainly from smaller capacity and less redundancy. The smaller environment still keeps its network and data separate from production.

I would base further size reductions on CPU, memory, database-load and recovery measurements, keeping the production availability requirements in place.

## Deployment windows and budget control

The configured **CAD 50 subscription budget sends alerts**. It does not stop resources, and the full architecture is not sized to run continuously within that amount. I use the fixed-cost estimate to plan deployment windows and account separately for logs, traffic and retained storage.

| Scenario | Estimated cost |
| --- | ---: |
| Production fixed footprint for six hours | **CAD 7.15**, plus usage and retention |
| Production fixed footprint for 24 hours | **CAD 28.61**, plus usage and retention |
| Development compute active 176 hours/month | **CAD 67.48/month**, including full-month storage/network and the same usage allowance |

Short-window figures prorate the monthly fixed charges. Billing-hour rounding, provisioning/deletion time and DNS daily billing affect the final amount. The 176-hour example requires VM deallocation and database stop/start; that schedule is a cost option, not an implemented automation.

Stopping a VM does not remove disks, public IPs, private endpoints, DNS zones or stored backups. I include those resources in cleanup planning, along with file snapshots, soft-deleted data and retained Blob versions. PostgreSQL automatically starts again after seven stopped days.

## Calculation detail

The [calculation CSV](monthly-estimate.csv) contains **52 line items**. The [rate snapshot](retail-rates.json) contains **44 selected meters** with their currency, units, regions, effective dates and source URLs. Every line is `quantity × unit rate`; totals use unrounded amounts.

<details>
<summary>Resource sizes, rates and monthly calculations</summary>

### Pricing basis

- **730 hours per month**, Linux pay-as-you-go; no Spot pricing, reservations, savings plans, student credits or negotiated discounts deducted.
- **Production: East US**, matching the current `location` input/default. **Development: Canada Central**, matching its default. The estimate follows those region settings; changing the deployment region changes the pricing baseline.
- Rates came from Microsoft's Retail Prices API in **CAD**, without a separate currency conversion. Global/Zone 1 network and DNS meters apply where the catalog lists them that way.
- Storage and traffic volumes below are planning assumptions. They are not measured RestSim usage. The estimate includes full compute provisioning with `deploy_compute = true`; turning application installation off does not turn off the infrastructure charges.
- The StandardV2 egress IP allowance uses the Standard IPv4 meter at **CAD 0.0071/hour**, contributing CAD 5.18/month.

I saved the [52 calculation lines](monthly-estimate.csv) and [44 selected retail meters](retail-rates.json), including meter IDs, units, regions, effective dates and lookup URLs. Each CSV amount is `quantity × unit_rate_cad`; totals use unrounded line amounts.

### Production: fixed footprint

These charges continue while the corresponding resources remain provisioned, even when customer traffic is low.

| Component | Monthly calculation | CAD/month |
| --- | --- | ---: |
| Web VMSS: two D2s_v5 VMs | 2 VMs x 730 h | 198.56 |
| Worker: one D2s_v5 VM | 1 VM x 730 h | 99.28 |
| Three 64 GiB P6 OS disks | 3 disks | 43.38 |
| PostgreSQL: primary and standby | 2 servers x 2 vCores x 730 h | 353.61 |
| PostgreSQL: primary and standby storage | 2 servers x 32 GiB | 10.43 |
| Redis B0 with HA | 2 nodes x 730 h | 33.14 |
| NAT StandardV2 | 730 h; Standard and StandardV2 use same rate | 46.50 |
| Load Balancer: two rules | 730 h; first-five-rules bundle counted once | 25.84 |
| Ingress Standard public IP | 1 IP x 730 h | 5.18 |
| Egress StandardV2 public IP allowance | 1 IP x 730 h; Standard rate proxy | 5.18 |
| Four private endpoints | 4 endpoints x 730 h | 41.46 |
| Five private DNS zones | 5 zones | 3.54 |
| Files snapshot backup protected instance | 1 protected storage account <=250 GiB x 60% of base instance rate | 4.25 |
| **Fixed subtotal** | | **870.36** |

PostgreSQL is priced per vCore: `2 primary vCores + 2 standby vCores`, each at CAD 0.1211/hour. Its storage is also counted twice. Redis B0 uses two node-hours per hour with HA enabled. Neither standby is an extra Terraform resource, but both affect the bill.

The two load-balancing rules fit inside the first-five-rules hourly bundle; I counted the bundle once. There are **four** private endpoints: Files, Key Vault, Redis and release Blob Storage. PostgreSQL uses its delegated subnet and private DNS, so it does not add a fifth endpoint.

The backup policy uses **snapshot backup**, with daily retention of 30 days and weekly retention of 12 weeks. The protected storage account is below 250 GiB in this scenario, so the management fee is `60% × CAD 7.0828 = CAD 4.25/month`. File snapshots are billed separately in the source storage account. The vault's ZRS setting does not add a second copy of snapshot storage in this calculation.

### Production: usage allowance

| Item | Assumed monthly usage | CAD/month |
| --- | --- | ---: |
| Live Azure Files data | 100 GiB × 0.1062 | 10.62 |
| Incremental retained file snapshots | 50 GiB × 0.1062 | 5.31 |
| Hot ZRS release Blob Storage | 10 GiB × 0.0368 | 0.37 |
| PostgreSQL geo-redundant backup excess | 32 GiB × 0.1346 | 4.31 |
| Log Analytics, including application telemetry | 30 GB × 3.2581 | 97.74 |
| Load Balancer processed traffic | 100 GB × 0.0071 | 0.71 |
| NAT processed traffic | 20 GB × 0.0637 | 1.27 |
| Private endpoint processed traffic | 100 GB × 0.0142 | 1.42 |
| Private DNS queries | 1 million × 0.5666 | 0.57 |
| Key Vault secret operations | 100,000 ÷ 10,000 × 0.0425 | 0.43 |
| Seven metric alert time series | 7 × 0.1417 | 0.99 |
| File and Blob transactions | Read, write, list and protocol volumes in the CSV | 0.66 |
| Internet egress allowance | 100 GB × 0.1232 | 12.32 |
| **Usage subtotal** | Calculated before rounding | **136.72** |

The **100 GiB file-share quota is a limit**, not a reservation billed in full. I assumed the share is full for this example. A share holding 10 GiB costs less for capacity. Snapshots store differential data, so 30 daily backups do not automatically mean 30 full copies. The 50 GiB snapshot allowance represents retained changed data in this cost scenario.

For PostgreSQL, I assumed a 32 GiB local backup set. Geo-redundancy doubles that footprint, with a 32 GiB primary-storage allowance: `max(2 × 32 − 32, 0) × 0.1346 = CAD 4.31`. Retention is 35 days; actual backup volume depends on database size and write activity, not retention alone.

### Development

I kept development smaller: one burstable VM, one burstable PostgreSQL server, LRS file storage and two private endpoints. It has no separate worker VM, Redis, load balancer, NAT Gateway, production backup vault or release-storage account.

| Component | Monthly calculation | CAD/month |
| --- | --- | ---: |
| One B2als_v2 VM | 1 VM x 730 h | 43.22 |
| One 32 GiB E4 OS disk | 1 disk | 3.74 |
| PostgreSQL B1ms; no standby | 1 server x 730 h | 19.13 |
| PostgreSQL storage | 32 GiB | 5.73 |
| Staging Standard public IP | 1 IP x 730 h | 5.18 |
| Two private endpoints | 2 endpoints x 730 h | 20.73 |
| Three private DNS zones | 3 zones | 2.12 |
| **Fixed subtotal** | | **99.86** |
| Logs | 3 GB × 3.9097 | 11.73 |
| Live files and retained deleted data | 10 GiB + 2 GiB at 0.0935/GiB | 1.12 |
| Network traffic, DNS, secrets, alerts and transactions | Detailed quantities in the CSV | 2.08 |
| **Total** | Calculated before rounding | **114.79** |

The development backup assumption is 16 GiB, within its 32 GiB included allowance; excess storage would cost CAD 0.1487/GiB-month. Seven-day file soft deletion is included through the retained-data allowance. It does not create the production snapshot-backup policy.

Optional Azure-hosted staging DNS is disabled by default. Enabling one public zone adds **CAD 0.7083/month**, plus CAD 0.5666 per million queries. The public IP is allocated in the current code even when staging ingress is closed, so its charge is already included.

### Monitoring and traffic

I counted Application Insights telemetry, Linux logs and service diagnostics inside each environment's total ingestion allowance. I did not charge for Application Insights ingestion a second time. Thirty-day workspace retention is inside the included Analytics retention period.

The model conservatively does **not** subtract shared free allowances: 5 GB/month of Analytics ingestion at billing-account scope, ten metric-alert time series, or the first 100 GB/month of eligible Internet egress. Other workloads can consume them. Email notifications are assumed to remain within the included 1,000/month. Production has seven metric rules and development has two; Resource Health uses a separately free Activity Log alert.

Production's 5 GB/day workspace cap is much higher than the 30 GB/month assumption. At 5 GB/day for a 30-day month, 150 GB would cost **CAD 488.72** in ingestion before free allowances. Development's 0.5 GB/day at the same duration gives 15 GB, or **CAD 58.65**. A daily cap is a safeguard and can overshoot; it is not a guaranteed bill ceiling. Application sampling and selected diagnostic categories determine the collected volume.

Traffic quantities are separate meter counters, not distinct customer downloads. One transfer can incur both a network service's processing fee and Internet egress. NAT includes outbound traffic and its replies; Load Balancer includes both directions; Private Link includes traffic across its endpoints. Cloudflare caching can reduce origin traffic, but traffic sent from Azure to Cloudflare can still incur Azure egress. No caching savings are assumed here.

### Other services and costs outside the total

| Component | Treatment |
| --- | --- |
| Resource groups, VNets, subnets, NICs and NSG rules | No separate hourly charge for these basic resources; chargeable IPs, private endpoints and network services are listed above. |
| Managed identities, RBAC and OIDC federation | No extra managed-identity charge; no Entra Premium licences purchased by this Terraform. Conditional Access or PIM licensing would be additional if introduced. |
| Tags, resource policies and subscription budget | No separate resource fee in this model. Guest Configuration and paid security plans are not configured. |
| Azure Monitor Agent and collection rules | No VM-agent licence fee added; resulting ingestion is included above. |
| Managed boot diagnostics | Managed boot-diagnostic blobs currently have no charge; no separate diagnostics storage account is configured. |
| Compute Gallery | Gallery and application definitions have no service fee. Terraform does not create application versions. Future version replicas, their storage and cross-region replication must be priced from actual package sizes; source blobs alone do not cover replica storage. |
| Terraform CLI and local state | No Azure state-storage account or hosted Terraform subscription included. Local backup of state remains necessary. |
| GitHub Actions | Standard hosted-runner minutes for this public repository are free. Private application CI, larger runners, artifact/cache overages and a private-network runner need a separate estimate; this Terraform does not provision a runner. |
| Cloudflare DNS/CDN and Access | The existing Cloudflare subscription, Access seats and add-ons sit outside this Azure estimate. Terraform does not purchase a Cloudflare plan. Published free tiers are subject to their user and feature limits. |
| RestSim business services | Existing VPS, domains, telecom-provider API purchases, payments, email/SMS services, app-store fees, support plans, tax and engineering time are outside this Azure infrastructure estimate. |

</details>

<details>
<summary>Pricing sources and calculation evidence</summary>

The resource counts and settings come from the repository's [production](../../terraform/environments/production/) and [development](../../terraform/environments/development/) configurations. The calculation files contain no subscription identifiers, credentials, state or customer data.

- [Monthly calculation CSV](monthly-estimate.csv) — quantities, unit prices, formulas and line amounts.
- [Selected retail-rate snapshot](retail-rates.json) — official API query URLs and exact meter metadata; CAD Consumption rates retrieved October 29, 2026.
- [Microsoft Retail Prices API](https://learn.microsoft.com/en-us/rest/api/cost-management/retail-prices/azure-retail-prices) — pricing fields, currency and pagination.
- [PostgreSQL pricing](https://azure.microsoft.com/en-us/pricing/details/postgresql/flexible-server/) and [backup billing](https://learn.microsoft.com/en-us/azure/postgresql/backup-restore/concepts-backup-restore) — primary/standby billing and geo-backup allowance.
- [Managed Redis pricing](https://azure.microsoft.com/en-us/pricing/details/managed-redis/) — one-node versus HA pricing.
- [NAT pricing](https://azure.microsoft.com/en-us/pricing/details/azure-nat-gateway/) and [NAT FAQ](https://learn.microsoft.com/en-us/azure/nat-gateway/faq) — matching Standard/StandardV2 rates and processed traffic.
- [Load Balancer](https://azure.microsoft.com/en-us/pricing/details/load-balancer/), [Private Link](https://azure.microsoft.com/en-us/pricing/details/private-link/), [IP addresses](https://azure.microsoft.com/en-us/pricing/details/ip-addresses/), [DNS](https://azure.microsoft.com/en-us/pricing/details/dns/) and [bandwidth](https://azure.microsoft.com/en-us/pricing/details/bandwidth/) — fixed and usage billing.
- [Managed disks](https://azure.microsoft.com/en-us/pricing/details/managed-disks/) and [Files billing](https://learn.microsoft.com/en-us/azure/storage/files/understanding-billing) — disk tiers, used capacity and differential snapshots.
- [Azure Backup pricing](https://azure.microsoft.com/en-us/pricing/details/backup/) — snapshot protection fee and the below-250-GB band.
- [Azure Monitor pricing](https://azure.microsoft.com/en-us/pricing/details/monitor/) and [daily-cap behaviour](https://learn.microsoft.com/en-us/azure/azure-monitor/logs/daily-cap) — ingestion, included allowances, retention and alerts.
- [Budget behaviour](https://learn.microsoft.com/en-us/azure/cost-management-billing/costs/tutorial-acm-create-budgets) and [PostgreSQL stop/start](https://learn.microsoft.com/en-us/azure/postgresql/overview) — alerts do not stop resources; stopped database compute and automatic restart.
- [Managed identities](https://learn.microsoft.com/en-us/entra/identity/managed-identities-azure-resources/overview), [boot diagnostics](https://learn.microsoft.com/en-us/azure/virtual-machines/boot-diagnostics), [Compute Gallery](https://learn.microsoft.com/en-us/azure/virtual-machines/azure-compute-gallery), [GitHub Actions billing](https://docs.github.com/en/billing/concepts/product-billing/github-actions) and [Cloudflare plans](https://www.cloudflare.com/plans/) — included capabilities and separate charges.

Rates are dated so later cost reviews can compare the same configuration and usage quantities.

</details>
