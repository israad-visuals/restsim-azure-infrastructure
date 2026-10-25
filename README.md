[![RestSim project header with the navy-and-green wordmark and green-beanie mascot](docs/product/restsim-azure-header.jpg)](https://restsim.com)

![Project progress: architecture complete; production Terraform validated locally; Azure deployment next; operational checks upcoming.](docs/assets/project-status.svg)

**Terraform · Azure Networking · High Availability · Security · CI/CD · Monitoring**

[RestSim](https://restsim.com) is a travel eSIM platform that helps travelers stay connected abroad with mobile data, calls and SMS, depending on the plan. Customers can browse destinations, buy plans and manage their eSIMs through the website and mobile apps. It started with a small user base and now serves a growing number of users.

| Website | iOS app | Android app |
| :---: | :---: | :---: |
| [![Visit the RestSim website](docs/product/website-badge.svg)](https://restsim.com) | [![Download on the App Store](docs/product/app-store-link.svg)](https://apps.apple.com/app/id6786134566) | [![Get it on Google Play](docs/product/google-play-link.svg)](https://play.google.com/store/apps/details?id=com.restsim.app) |

This project uses RestSim's requirements to design and build an Azure environment with separate development and production configurations.

**Contents:** [Business problem](#business-problem) · [My contribution](#my-contribution) · [Landing zone](#landing-zone) · [Architecture diagrams](#architecture-diagrams) · [Design guides](docs/architecture/README.md) · [Current work](#current-work) · [Staged approach](#staged-approach)

[![RestSim website and mobile app store artwork](docs/product/restsim-product-preview.jpg)](https://restsim.com)

## Business problem

RestSim runs on one VPS to keep costs low, but relying on one server creates a risk of downtime and limits how the application can handle growing traffic. With customers around the world, reliable access and fast response times across regions also matter.

## My contribution

I worked on the Azure architecture and infrastructure-as-code implementation, using RestSim's existing application and single-VPS setup to guide the decisions.

- **Architecture:** I defined the landing zone, resource groups and environment separation, then selected services for availability, scaling and shared data.
- **Networking and security:** I mapped customer traffic and private service connections, including subnets, NSG rules, private DNS, managed identities and Key Vault access.
- **Infrastructure as code:** I translated the design into production Terraform covering networking, compute, data services, security, monitoring and backups.
- **Delivery and operations:** I designed the Azure release path around RestSim's existing CI checks, with versioned packages, staging, controlled rollout and recovery.
- **Design documentation:** I created six draw.io diagrams and explained the requirements, service choices and trade-offs behind each design.

## Landing zone

I started with the landing zone to map where resources belong before writing Terraform. The design separates environments and groups resources by network, application, data and monitoring, with access controls and governance around them.

![Azure services in the target design: Azure Virtual Network, VM Scale Sets, Key Vault and Azure Monitor](docs/assets/azure/service-overview.jpg)

[![RestSim high-level Azure landing-zone design](docs/architecture/01-landing-zone.png)](https://viewer.diagrams.net/?nav=1&title=RestSim%20Azure%20Architecture&page-id=_U4szGZBWyCFBpTj2Gg4#Uhttps%3A%2F%2Fraw.githubusercontent.com%2Fisraad-visuals%2Frestsim-azure-infrastructure%2Fmain%2Fdocs%2Farchitecture%2FRestSim-Azure-Architecture.drawio)

[Open full-size architecture](https://viewer.diagrams.net/?nav=1&title=RestSim%20Azure%20Architecture&page-id=_U4szGZBWyCFBpTj2Gg4#Uhttps%3A%2F%2Fraw.githubusercontent.com%2Fisraad-visuals%2Frestsim-azure-infrastructure%2Fmain%2Fdocs%2Farchitecture%2FRestSim-Azure-Architecture.drawio)

Production uses multiple application instances with shared data services and a separate background worker. Development gives developers an isolated, smaller environment to test and stage application changes before a production release. Managed identities, Key Vault and central monitoring support both access control and operations.

[Read the landing-zone decisions: resource ownership, reliability, governance and cost](docs/architecture/01-landing-zone.md).

## Architecture diagrams

[View the six-page architecture](https://viewer.diagrams.net/?nav=1&title=RestSim%20Azure%20Architecture#Uhttps%3A%2F%2Fraw.githubusercontent.com%2Fisraad-visuals%2Frestsim-azure-infrastructure%2Fmain%2Fdocs%2Farchitecture%2FRestSim-Azure-Architecture.drawio)

| Design | What it explains |
| --- | --- |
| [Landing zone](docs/architecture/01-landing-zone.md) | Resource organisation, availability, governance and cost. |
| [Production network](docs/architecture/02-production-network.md) | Customer traffic, subnets and private service access. |
| [Development network](docs/architecture/03-development-network.md) | Isolated developer testing and staging. |
| [Application CI/CD](docs/architecture/04-application-cicd.md) | Versioned packages, controlled rollout and recovery. |
| [Terraform CI/CD](docs/architecture/05-terraform-cicd.md) | Infrastructure review, state and deployment identity. |
| [Production monitoring](docs/architecture/06-production-monitoring.md) | Telemetry, alerts and operational response. |

## Current work

- **Architecture:** six diagrams and supporting design guides covering the landing zone, networks, delivery and monitoring.
- **Terraform:** [production configuration](terraform/environments/production/) written for networking, compute, data, security, monitoring and recovery.

## Staged approach

The live service stays on its existing VPS. Azure testing uses synthetic data and separate credentials.

1. Deploy a small, isolated scope and check connectivity, access controls, logs and alerts.
2. Test application deployment, shared sessions and files, scaling and recovery.
3. Record results and costs before considering any future production migration.
