## Executive summary

RestSim runs its travel eSIM platform on one VPS, which creates limits around scalability, availability, fault tolerance and disaster recovery. I reviewed the existing infrastructure and designed an Azure architecture using Virtual Machine Scale Sets, Standard Load Balancer, private networking and central monitoring to address those risks. I deployed the infrastructure in Azure using Terraform and documented the deployment results and subscription restrictions.

[![RestSim project header with the navy-and-green wordmark and green-beanie mascot](docs/product/restsim-azure-header.jpg)](https://restsim.com)

![Project at a glance: seven architecture diagrams, seven design guides, 52 cost calculation lines, two Terraform environments and infrastructure deployed in Azure.](docs/assets/restsim-project-at-a-glance.svg)

[![Click here to view Azure and Terraform deployment screenshot evidence](docs/assets/deployment-evidence-banner.svg)](#azure-deployment)

## Business Context

[RestSim](https://restsim.com) is a travel eSIM platform that helps travelers stay connected abroad with mobile data, calls and SMS, depending on the plan. Customers can browse destinations, buy plans and manage their eSIMs through the website and mobile apps. It started with a small user base and now serves a growing number of users.

| Website | iOS app | Android app |
| :---: | :---: | :---: |
| [![Visit the RestSim website](docs/product/website-badge.svg)](https://restsim.com) | [![Download on the App Store](docs/product/app-store-link.svg)](https://apps.apple.com/app/id6786134566) | [![Get it on Google Play](docs/product/google-play-link.svg)](https://play.google.com/store/apps/details?id=com.restsim.app) |

I translated RestSim's single-server requirements into an Azure architecture, separate production and development Terraform configurations, and an itemised cost model.

**Contents:** [Business problem](#business-problem) · [My contribution](#my-contribution) · [Landing zone](#landing-zone) · [Architecture diagrams](#architecture-diagrams) · [Design guides](docs/architecture/README.md) · [Implementation](#implementation) · [Azure Deployment](#azure-deployment) · [Deployment review](#deployment-review) · [Cost review](docs/costs/README.md)

## Business problem

RestSim runs on one VPS to keep costs low, but relying on one server creates a risk of downtime and limits how the application can handle growing traffic. With customers around the world, reliable access and fast response times across regions also matter.

## My contribution

I studied RestSim's current infrastructure and researched improvements based on its application requirements. I turned those requirements into an Azure architecture and separate production and development Terraform configurations, focusing on reducing dependence on one server, protecting application data and making infrastructure changes repeatable without unnecessary cost.

- **Architecture:** I mapped the single-server risks to a web scale set, a separate worker and shared database, file and session services.
- **Infrastructure as code:** I wrote production and development Terraform configurations for networking, compute, private services, identity, monitoring and recovery.
- **Security:** I defined subnet and NSG rules, private service connections, managed identities and scoped secret access.
- **Release design:** I mapped the existing application checks into a versioned-package flow, with staging, controlled rollout and a separate worker handover.
- **Cost analysis:** I calculated 52 cost lines from Microsoft retail rates and compared the smaller development footprint with the production configuration.
- **Technical documentation:** I created seven draw.io diagrams and guides explaining the resource relationships and engineering decisions.

<details>
<summary>View the live RestSim product</summary>

[![RestSim website and mobile app store artwork](docs/product/restsim-product-preview.jpg)](https://restsim.com)

</details>

## Landing zone

I started with the landing zone to map where resources belong before writing Terraform. The design separates environments and groups resources by network, application, data and monitoring, with access controls and governance around them.

![Azure services in the architecture: Azure Virtual Network, VM Scale Sets, Key Vault and Azure Monitor](docs/assets/azure/service-overview.jpg)

[![RestSim high-level Azure landing-zone design](docs/architecture/01-landing-zone.png)](https://viewer.diagrams.net/?nav=1&title=RestSim%20Azure%20Architecture&page-id=_U4szGZBWyCFBpTj2Gg4#Uhttps%3A%2F%2Fraw.githubusercontent.com%2Fisraad-visuals%2Frestsim-azure-infrastructure%2Fmain%2Fdocs%2Farchitecture%2FRestSim-Azure-Architecture.drawio)

[Open full-size architecture](https://viewer.diagrams.net/?nav=1&title=RestSim%20Azure%20Architecture&page-id=_U4szGZBWyCFBpTj2Gg4#Uhttps%3A%2F%2Fraw.githubusercontent.com%2Fisraad-visuals%2Frestsim-azure-infrastructure%2Fmain%2Fdocs%2Farchitecture%2FRestSim-Azure-Architecture.drawio)

The production design uses multiple application instances with shared data services and a separate background worker. Development gives developers an isolated, smaller environment to test and stage application changes before a production release. Managed identities, Key Vault and central monitoring support both access control and operations.

[Read the landing-zone decisions: resource ownership, reliability, governance and cost](docs/architecture/01-landing-zone.md).

## Architecture diagrams

[View the seven-page architecture](https://viewer.diagrams.net/?nav=1&title=RestSim%20Azure%20Architecture#Uhttps%3A%2F%2Fraw.githubusercontent.com%2Fisraad-visuals%2Frestsim-azure-infrastructure%2Fmain%2Fdocs%2Farchitecture%2FRestSim-Azure-Architecture.drawio)

| Design | What it explains | Detailed page |
| --- | --- | --- |
| [Landing zone](#landing-zone) | Resource organisation, availability, governance and cost. | [Details](docs/architecture/01-landing-zone.md) |
| [Production network](#production-network) | Customer traffic, subnets and private service access. | [Details](docs/architecture/02-production-network.md) |
| [Development network](#development-network) | Isolated developer testing and staging. | [Details](docs/architecture/03-development-network.md) |
| [Application CI/CD](#application-cicd) | Versioned packages, controlled rollout and recovery. | [Details](docs/architecture/04-application-cicd.md) |
| [Terraform CI/CD](#terraform-cicd) | Infrastructure review, state and deployment identity. | [Details](docs/architecture/05-terraform-cicd.md) |
| [Production monitoring](#production-monitoring) | Telemetry, alerts and operational response. | [Details](docs/architecture/06-production-monitoring.md) |
| [Development monitoring](#development-monitoring) | Development logs, resource metrics and email alerts. | [Details](docs/architecture/07-development-monitoring.md) |

## Production network

[![RestSim production network design](docs/architecture/02-production-network.png)](https://viewer.diagrams.net/?nav=1&title=RestSim%20Azure%20Architecture&page-id=FVyJa8Ms7tz5EjTs3-nd#Uhttps%3A%2F%2Fraw.githubusercontent.com%2Fisraad-visuals%2Frestsim-azure-infrastructure%2Fmain%2Fdocs%2Farchitecture%2FRestSim-Azure-Architecture.drawio)

I kept Cloudflare in the Azure design as RestSim's public entry point and placed Standard Load Balancer in front of the VMSS to spread requests across healthy web instances. The network configuration gives the application and worker private connections to PostgreSQL, Files, Redis and Key Vault. Separate subnets and NSG rules control the permitted paths.

[Design details](docs/architecture/02-production-network.md) · [Open full-size diagram](https://viewer.diagrams.net/?nav=1&title=RestSim%20Azure%20Architecture&page-id=FVyJa8Ms7tz5EjTs3-nd#Uhttps%3A%2F%2Fraw.githubusercontent.com%2Fisraad-visuals%2Frestsim-azure-infrastructure%2Fmain%2Fdocs%2Farchitecture%2FRestSim-Azure-Architecture.drawio) · [Back to diagram table](#architecture-diagrams)

## Development network

[![RestSim development network design](docs/architecture/03-development-network.png)](https://viewer.diagrams.net/?nav=1&title=RestSim%20Azure%20Architecture&page-id=dXpRaSZKOgxavGIHGhGw#Uhttps%3A%2F%2Fraw.githubusercontent.com%2Fisraad-visuals%2Frestsim-azure-infrastructure%2Fmain%2Fdocs%2Farchitecture%2FRestSim-Azure-Architecture.drawio)

I designed development as the developers' isolated environment for testing and staging application changes before a production release. Separate networking, data and credentials keep it apart from production. The staging access design uses Microsoft Entra ID and OAuth2 Proxy, while one VM keeps the development footprint smaller.

[Design details](docs/architecture/03-development-network.md) · [Open full-size diagram](https://viewer.diagrams.net/?nav=1&title=RestSim%20Azure%20Architecture&page-id=dXpRaSZKOgxavGIHGhGw#Uhttps%3A%2F%2Fraw.githubusercontent.com%2Fisraad-visuals%2Frestsim-azure-infrastructure%2Fmain%2Fdocs%2Farchitecture%2FRestSim-Azure-Architecture.drawio) · [Back to diagram table](#architecture-diagrams)

## Application CI/CD

**Implemented — GitHub Actions**

I implemented RestSim's application CI, regression testing and post-deployment smoke checks in GitHub Actions. These workflows check application builds, APIs, database changes, security and browser behaviour.

**Application CI — September 17, 2026**

![GitHub Actions application CI run with all seven jobs passed](docs/assets/cicd/web-ci.png)

**Full regression — September 7, 2026**

![GitHub Actions full regression run with completed test and security checks](docs/assets/cicd/full-regression.png)

**Post-deployment smoke checks — August 27, 2026**

![GitHub Actions smoke run with health, page, API and admin login reachability checks passed](docs/assets/cicd/post-deployment-smoke.png)

**Planned — automated Azure releases**

Automated application releases to Azure are planned as RestSim grows. For now, I am keeping CI and validation in GitHub Actions because the existing workflows already cover those needs. GitHub Actions can also deploy to Azure, so I can extend these workflows when needed without moving to Azure DevOps.

[![RestSim application ci/cd design](docs/architecture/04-application-cicd.png)](https://viewer.diagrams.net/?nav=1&title=RestSim%20Azure%20Architecture&page-id=dJ8D57PUJrwz-ndNujR8#Uhttps%3A%2F%2Fraw.githubusercontent.com%2Fisraad-visuals%2Frestsim-azure-infrastructure%2Fmain%2Fdocs%2Farchitecture%2FRestSim-Azure-Architecture.drawio)

I designed the Azure release path around RestSim's existing CI and RQOS checks. One versioned package moves through private Blob Storage, Compute Gallery and staging before controlled VMSS rollout. Exact version pins, a separate worker handover and a recovery path keep deployment decisions traceable.

[Design details](docs/architecture/04-application-cicd.md) · [Open full-size diagram](https://viewer.diagrams.net/?nav=1&title=RestSim%20Azure%20Architecture&page-id=dJ8D57PUJrwz-ndNujR8#Uhttps%3A%2F%2Fraw.githubusercontent.com%2Fisraad-visuals%2Frestsim-azure-infrastructure%2Fmain%2Fdocs%2Farchitecture%2FRestSim-Azure-Architecture.drawio) · [Back to diagram table](#architecture-diagrams)

## Terraform CI/CD

I deployed the Azure infrastructure manually with Terraform. Automated Terraform plan and apply workflows will be implemented once the architecture grows.

[![RestSim terraform ci/cd design](docs/architecture/05-terraform-cicd.png)](https://viewer.diagrams.net/?nav=1&title=RestSim%20Azure%20Architecture&page-id=8nira5fFPzOVPsJZNsbC#Uhttps%3A%2F%2Fraw.githubusercontent.com%2Fisraad-visuals%2Frestsim-azure-infrastructure%2Fmain%2Fdocs%2Farchitecture%2FRestSim-Azure-Architecture.drawio)

I separated infrastructure changes from application releases so each follows its own review process. The infrastructure workflow design uses Terraform plans and separate environment state. I keep each state file locally beside its environment configuration; GitHub OIDC provides scoped identities for the delivery design. A saved-plan approval step ties the production change to the configuration that was reviewed.

[Design details](docs/architecture/05-terraform-cicd.md) · [Open full-size diagram](https://viewer.diagrams.net/?nav=1&title=RestSim%20Azure%20Architecture&page-id=8nira5fFPzOVPsJZNsbC#Uhttps%3A%2F%2Fraw.githubusercontent.com%2Fisraad-visuals%2Frestsim-azure-infrastructure%2Fmain%2Fdocs%2Farchitecture%2FRestSim-Azure-Architecture.drawio) · [Back to diagram table](#architecture-diagrams)

## Production monitoring

[![RestSim production monitoring design](docs/architecture/06-production-monitoring.png)](https://viewer.diagrams.net/?nav=1&title=RestSim%20Azure%20Architecture&page-id=ZR1PCFiNJjQxqDGBOhbM#Uhttps%3A%2F%2Fraw.githubusercontent.com%2Fisraad-visuals%2Frestsim-azure-infrastructure%2Fmain%2Fdocs%2Farchitecture%2FRestSim-Azure-Architecture.drawio)

I designed central monitoring to trace RestSim application failures across web instances and managed dependencies. Application Insights provides request and dependency telemetry, while Linux logs and Azure diagnostics feed Log Analytics. I defined metric and Resource Health alerts for operational notifications, with retention and ingestion limits to manage log volume and cost.

[Design details](docs/architecture/06-production-monitoring.md) · [Open full-size diagram](https://viewer.diagrams.net/?nav=1&title=RestSim%20Azure%20Architecture&page-id=ZR1PCFiNJjQxqDGBOhbM#Uhttps%3A%2F%2Fraw.githubusercontent.com%2Fisraad-visuals%2Frestsim-azure-infrastructure%2Fmain%2Fdocs%2Farchitecture%2FRestSim-Azure-Architecture.drawio) · [Back to diagram table](#architecture-diagrams)

## Development monitoring

[![RestSim development monitoring design](docs/architecture/07-development-monitoring.png)](https://viewer.diagrams.net/?nav=1&title=RestSim%20Azure%20Architecture&page-id=gxs_Zrl31glBiPyCSrfB#Uhttps%3A%2F%2Fraw.githubusercontent.com%2Fisraad-visuals%2Frestsim-azure-infrastructure%2Fmain%2Fdocs%2Farchitecture%2FRestSim-Azure-Architecture.drawio)

I gave development its own monitoring workspace and notifications so developers can investigate application changes separately from production. Linux performance data and service logs feed Log Analytics, while CPU and database-storage alerts send email through the development action group. A 30-day retention period, 0.5 GB/day ingestion cap and 25% Application Insights sampling setting keep the collection footprint smaller.

[Design details](docs/architecture/07-development-monitoring.md) · [Open full-size image](docs/architecture/07-development-monitoring.png) · [Back to diagram table](#architecture-diagrams)

## Implementation

| Area | Work completed |
| --- | --- |
| Architecture | Seven draw.io diagrams with service choices, traffic paths and environment boundaries explained in the design guides. |
| Infrastructure as code | Separate [production](terraform/environments/production/) and [development](terraform/environments/development/) configurations for networking, compute, data, identity and monitoring; production also includes shared sessions, artifact delivery and recovery resources. |
| Deployment controls | Local state, ignored environment inputs, SSH-key authentication and separate controls for infrastructure provisioning and application installation. |
| Validation and troubleshooting | Terraform checks, an Azure execution plan, subscription-policy and quota investigation, and verified resource cleanup. |

# Azure Deployment

**I successfully deployed the RestSim infrastructure to Azure using Terraform.** I verified that both VM Scale Set instances were running and that PostgreSQL high availability showed a **Healthy** status. The screenshots below show the Terraform apply result and the deployed resources in Azure.

**Azure resource groups**

![Azure portal shows the four RestSim resource groups in Mexico Central](docs/assets/deployment/azure-resource-groups.png)

**Terraform apply**

![Terraform terminal shows the final apply completed with 19 added, 0 changed and 0 destroyed](docs/assets/deployment/terraform-apply.png)

**VM Scale Set instances**

![Azure portal shows both VM instances Running with provisioning Succeeded](docs/assets/deployment/virtual-machine-scale-set.png)

### Azure resource details

**VM Scale Set overview**

![Azure scale set overview shows two running instances, zones 1 and 3, and autoscale](docs/assets/deployment/virtual-machine-scale-set-overview.png)

**PostgreSQL high availability**

![Azure PostgreSQL shows the Healthy availability status in Same zone mode](docs/assets/deployment/postgresql-high-availability.png)

**Key Vault private endpoint**

![Azure reports an Approved connection on the Key Vault private endpoint](docs/assets/deployment/key-vault-private-endpoint.png)

**PostgreSQL overview**

![PostgreSQL Flexible Server overview in Azure](docs/assets/deployment/postgresql-overview.png)

**Load balancer health probe**

![Azure Load Balancer HTTP readiness probe configuration](docs/assets/deployment/load-balancer-health-probe.png)

**Azure Files backup**

![Azure Files backup protection and status](docs/assets/deployment/azure-files-backup.png)

**Network resource group**

![Azure network resource group inventory](docs/assets/deployment/network-resource-group.png)

### Azure Portal walkthrough

**Production resource groups**

![Production resource groups in the Azure Portal](docs/assets/deployment/portal-production-resource-groups.png)

**Application resource group**

![Azure application resource group inventory](docs/assets/deployment/portal-app-resource-group.png)

**Data resource group**

![Azure data resource group overview](docs/assets/deployment/portal-data-resource-group.png)

**Data resources**

![Azure data resource group detail](docs/assets/deployment/portal-data-resource-group-detail.png)

**Monitoring resource group**

![Azure monitoring resource group inventory](docs/assets/deployment/portal-monitoring-resource-group.png)

**Network security rules**

![Azure network security group rules for the application subnet](docs/assets/deployment/portal-app-network-security-rules.png)

### Terraform plan and apply

**Saved plan**

![Terraform saved plan output](docs/assets/deployment/terraform-plan-saved.png)

**Plan summary**

![Terraform plan summary](docs/assets/deployment/terraform-plan-summary.png)

**Apply started**

![Terraform apply started](docs/assets/deployment/terraform-apply-start.png)

**Resource groups created**

![Terraform resource group creation output](docs/assets/deployment/terraform-resource-groups-created.png)

**Private endpoints and backup**

![Terraform private endpoint and backup provisioning output](docs/assets/deployment/terraform-private-endpoints-and-backup.png)

**Retry plan**

![Terraform retry plan summary](docs/assets/deployment/terraform-retry-plan-summary.png)

**PostgreSQL created**

![Terraform PostgreSQL creation output](docs/assets/deployment/terraform-postgresql-created.png)

**Final apply output**

![Terraform final apply output](docs/assets/deployment/terraform-apply-complete.png)

## Deployment review

In an earlier deployment attempt, I reviewed a production Terraform plan with **122 creates, 4 updates and no deletions**. The Azure run created private DNS zones, alerting resources, a budget and policy definitions and assignments. Regional resource creation stopped when Azure enforced the subscription's allowed-region policy.

I traced the restriction to the subscription's policy, checked VM quotas and PostgreSQL access, then completed a reviewed cleanup. Terraform removed **18 tracked entries**, and Azure checks confirmed the project resource groups, budget and custom policies were gone. Unrelated resources were preserved.

[Read the setup, troubleshooting and verified results](docs/operations/deployment-review.md).
