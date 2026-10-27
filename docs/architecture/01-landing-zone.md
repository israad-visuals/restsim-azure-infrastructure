# Landing zone: organising RestSim's Azure infrastructure

[Project overview](../../README.md) · [Architecture pages](README.md)

RestSim currently runs on one VPS. That kept the initial cost low, but growing usage makes availability, scaling and clearer infrastructure management more important. I designed the landing zone first to show where each part belongs and how the Azure environment supports those needs.

[![RestSim high-level Azure landing zone](01-landing-zone.png)](https://viewer.diagrams.net/?nav=1&title=RestSim%20Azure%20Architecture&page-id=_U4szGZBWyCFBpTj2Gg4#Uhttps%3A%2F%2Fraw.githubusercontent.com%2Fisraad-visuals%2Frestsim-azure-infrastructure%2Fmain%2Fdocs%2Farchitecture%2FRestSim-Azure-Architecture.drawio)

## Why I organised it this way

I separated production and development into different subscriptions in the design. Development is the developers' environment for testing and staging application changes before a production release, isolated through separate networking, data, credentials and access controls. This also separates spending and environment changes. The management-group hierarchy provides a place for common policies without mixing the two workloads.

Each environment has four resource groups:

| Resource group | What belongs here | Why it helps RestSim |
| --- | --- | --- |
| Network | VNet, subnets, NSGs, DNS, load balancing and private endpoints | Keeps connectivity and traffic controls together. |
| Application | Web compute, worker, Key Vault, Compute Gallery and release storage | Keeps the application and its deployment resources easy to find. |
| Data | PostgreSQL, Azure Files, Redis and backup resources | Separates lasting business data from replaceable servers. |
| Monitoring | Application Insights, Log Analytics, collection and alert rules | Gives operations one place to investigate the workload. |

## Why I chose these services

| RestSim requirement | Design choice | Intended improvement |
| --- | --- | --- |
| One server failure can interrupt the whole service. | VMSS with two web instances across availability zones and Standard Load Balancer. | Spreads requests across healthy instances and reduces dependence on one server. |
| Growing traffic puts more work on the same VPS. | CPU-based VMSS autoscaling. | Adds web capacity when demand grows, within a configured maximum. |
| The application already uses Linux and Apache. | Linux VMs with the existing proxy approach. | Reduces the application changes needed for the Azure move. |
| Scaling the web tier must not duplicate scheduled jobs. | A separate background worker VM. | Keeps scheduled work under one owner. |
| All web instances need the same application records. | Azure Database for PostgreSQL Flexible Server. | Keeps database storage separate from the web servers, with managed HA and backup settings. |
| Uploads must survive a web VM replacement. | Shared Azure Files storage. | Gives the web instances and worker a common durable file location. |
| A user's requests can reach different web instances. | Azure Managed Redis for shared sessions. | Keeps session state outside an individual VM. |
| More VMs need secrets without embedding them in images. | Managed identities, scoped roles and Key Vault. | Centralises secret storage and limits which workload can read each secret. |
| Multiple servers need consistent application versions. | Azure Compute Gallery VM Applications. | Provides a versioned deployment path for the VMSS and worker. |
| A distributed application needs more than server-health information. | Azure Monitor, Application Insights and Log Analytics. | Brings application failures, VM events and service signals into a shared monitoring design. |

## Recovery and cost decisions

The PostgreSQL configuration includes zone-redundant HA, 35-day backup retention and geo-redundant backups. Azure Files uses zone-redundant storage and scheduled snapshots. Availability protects against component failures; backups provide a separate recovery path for lost or incorrectly changed data.

Tags identify the project, environment, owner and cost centre. Optional region/tag policies support consistent configuration, while budget notifications help track spending. Development uses a smaller footprint so routine testing does not duplicate the full production cost.

The application design uses one Azure region with multiple availability zones.
