[![RestSim project header with the navy-and-green wordmark and green-beanie mascot](docs/product/restsim-project-header.jpg)](https://restsim.com)

**Terraform · Azure Networking · High Availability · Security · CI/CD · Monitoring**

[RestSim](https://restsim.com) is a travel eSIM platform that helps travelers stay connected abroad with mobile data, calls and SMS, depending on the plan. Customers can browse destinations, buy plans and manage their eSIMs through the website and mobile apps. It started with a small user base and now serves a growing number of users.

| Website | iOS app | Android app |
| :---: | :---: | :---: |
| [![Visit the RestSim website](docs/product/website-badge.svg)](https://restsim.com) | [![Download on the App Store](docs/product/app-store-link.svg)](https://apps.apple.com/app/id6786134566) | [![Get it on Google Play](docs/product/google-play-link.svg)](https://play.google.com/store/apps/details?id=com.restsim.app) |

This project uses RestSim's requirements to design and build an Azure environment with separate development and production configurations.

**Contents:** [Business problem](#business-problem) · [Landing zone](#landing-zone) · [Architecture diagrams](#architecture-diagrams) · [Design guides](docs/architecture/README.md) · [Current work](#current-work) · [Staged approach](#staged-approach)

[![RestSim website and mobile app store artwork](docs/product/restsim-product-preview.jpg)](https://restsim.com)

## Business problem

RestSim runs on one VPS to keep costs low, but relying on one server creates a risk of downtime and limits how the application can handle growing traffic. With customers around the world, reliable access and fast response times across regions also matter.

## Landing zone

I started with the landing zone to map where resources belong before writing Terraform. The design separates environments and groups resources by network, application, data and monitoring, with access controls and governance around them.

![Azure services in the target design: Azure Virtual Network, VM Scale Sets, Key Vault and Azure Monitor](docs/assets/azure/service-overview.jpg)

![RestSim high-level Azure landing-zone design](docs/architecture/01-landing-zone.png)

Production uses multiple application instances with shared data services and a separate background worker. Development gives developers an isolated, smaller environment to test and stage application changes before a production release. Managed identities, Key Vault and central monitoring support both access control and operations.

[Read the landing-zone decisions: resource ownership, reliability, governance and cost](docs/architecture/01-landing-zone.md).

## Architecture diagrams

[Open the six-page design in draw.io](https://app.diagrams.net/#Uhttps%3A%2F%2Fraw.githubusercontent.com%2Fisraad-visuals%2Frestsim-azure-infrastructure%2Fmain%2Fdocs%2Farchitecture%2FRestSim-Azure-Architecture.drawio) · [Editable draw.io file](docs/architecture/RestSim-Azure-Architecture.drawio)

| Diagram | What it shows | Design guide |
| --- | --- | --- |
| [Landing zone](#landing-zone) | Environment separation, resource groups and governance. | [Organisation and reliability](docs/architecture/01-landing-zone.md) |
| [Production network](#production-network) | Customer traffic, application instances and private services. | [Traffic, subnets and private access](docs/architecture/02-production-network.md) |
| [Development network](#development-network) | An isolated environment for developers to test and stage application changes. | [Developer access and staging](docs/architecture/03-development-network.md) |
| [Application CI/CD](#application-cicd) | Release extension using the existing GitHub Actions checks. | [Packages, rollout and recovery](docs/architecture/04-application-cicd.md) |
| [Terraform CI/CD](#terraform-cicd) | Infrastructure review, planning and deployment flow. | [Plans, state and deployment identity](docs/architecture/05-terraform-cicd.md) |
| [Production monitoring](#production-monitoring) | Log collection, metrics, alerts and notifications. | [Signals, thresholds and response](docs/architecture/06-production-monitoring.md) |

## Current work

- **Architecture:** six diagrams and supporting design guides covering the landing zone, networks, delivery and monitoring.
- **Terraform:** [production configuration](terraform/environments/production/) written for networking, compute, data, security, monitoring and recovery.

## Staged approach

The live service stays on its existing VPS. Azure testing uses synthetic data and separate credentials.

1. Deploy a small, isolated scope and check connectivity, access controls, logs and alerts.
2. Test application deployment, shared sessions and files, scaling and recovery.
3. Record results and costs before considering any future production migration.

---

## Production network

![RestSim production network topology](docs/architecture/02-production-network.png)

Customer traffic reaches Cloudflare, then Standard Load Balancer and a healthy web instance. Apache handles the origin TLS connection. The app and worker reach PostgreSQL through its delegated subnet, while Files, Redis and Key Vault use private endpoints. Separate network rules control these paths; the data services do not need public application-facing endpoints.

[Read the production network decisions and connection paths](docs/architecture/02-production-network.md).

[Back to diagram table](#architecture-diagrams)

## Development network

![RestSim development network topology](docs/architecture/03-development-network.png)

I designed development as the developers' environment for testing and staging application changes before a production release. It is isolated from production, with separate networking, data and credentials. Developers access the staging URL through OAuth2 Proxy and Microsoft Entra ID. One VM keeps the environment smaller, while the database, files and secrets use private connections.

[Read the development access, isolation and cost decisions](docs/architecture/03-development-network.md).

[Back to diagram table](#architecture-diagrams)

## Application CI/CD

![RestSim application CI/CD and release design](docs/architecture/04-application-cicd.png)

The release path starts with RestSim's existing RQOS checks and binds a Linux package to an exact source commit and version. That package passes through private storage, Compute Gallery and staging before controlled VMSS rollout. Readiness checks can stop a release, and the background worker has a separate handover to keep one scheduler owner.

[Read the application release, version-pinning and recovery decisions](docs/architecture/04-application-cicd.md).

[Back to diagram table](#architecture-diagrams)

## Terraform CI/CD

![RestSim Terraform infrastructure CI/CD design](docs/architecture/05-terraform-cicd.png)

Infrastructure changes move from pull-request checks to development validation and a separate production plan review. Production applies the saved plan that was reviewed. Azure Blob holds separate environment state, while GitHub OIDC provides scoped Azure access. Infrastructure changes and application releases have separate responsibilities.

[Read the Terraform review, remote-state and identity decisions](docs/architecture/05-terraform-cicd.md).

[Back to diagram table](#architecture-diagrams)

## Production monitoring

![RestSim production monitoring design](docs/architecture/06-production-monitoring.png)

I designed central monitoring to trace RestSim application failures across web instances and managed dependencies. Application Insights provides request and dependency telemetry, while Linux logs and Azure diagnostics feed Log Analytics. I defined metric and Resource Health alerts for operational notifications, with retention and ingestion limits to manage log volume and cost.

[Monitoring design and alert settings](docs/architecture/06-production-monitoring.md).

[Back to diagram table](#architecture-diagrams)
