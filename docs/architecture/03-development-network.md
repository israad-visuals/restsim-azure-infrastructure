# Development network: developer testing and staging

[Project overview](../../README.md) · [Architecture pages](README.md)

I designed development as the developers' environment for testing and staging RestSim application changes before a production release. It is isolated from production, with separate networking, data, credentials and access controls. A smaller workload keeps routine development costs lower, while a protected staging URL gives the development team access to the application.

[![RestSim development network topology](03-development-network.png)](https://viewer.diagrams.net/?nav=1&title=RestSim%20Azure%20Architecture&page-id=dXpRaSZKOgxavGIHGhGw#Uhttps%3A%2F%2Fraw.githubusercontent.com%2Fisraad-visuals%2Frestsim-azure-infrastructure%2Fmain%2Fdocs%2Farchitecture%2FRestSim-Azure-Architecture.drawio)

## How developers reach the application

**Developer → staging hostname → HTTPS entry point → OAuth2 Proxy and Microsoft Entra ID → RestSim application**

I placed the identity check in front of the application's loopback upstream. The staging access design uses OAuth2 Proxy with Microsoft Entra ID and a development-team access policy. Azure DNS hosting for the staging name is optional in Terraform; the NSG ingress stays closed until the staging-access inputs are enabled.

Entra ID provides the identity and the proxy enforces access. The NSG has a separate role: filtering network traffic. This avoids treating a network rule as a user sign-in system.

## Why I chose this setup

| RestSim requirement | Design choice | Why this fits RestSim |
| --- | --- | --- |
| Developers need to test and stage changes without touching production. | Separate development subscription, VNet and service configuration. | Isolates development changes, data and credentials from production. |
| Developers need a staging URL, with access limited to permitted people. | Public staging DNS with Entra ID and OAuth2 Proxy. | Provides browser-based access with an identity check. |
| Development does not need the full production footprint. | One application VM and no development load balancer. | Reduces routine compute cost and makes troubleshooting simpler. |
| Network behaviour should remain familiar between environments. | The same application, delegated database and private-endpoint subnet pattern. | Makes differences easier to understand when a change moves toward production. |
| Test services should not expose data or secrets publicly. | Private PostgreSQL connectivity and private endpoints for Files and Key Vault. | Keeps application dependencies behind private connections. |
| Test activity must not create real transactions. | Synthetic accounts, separate secrets and mocked provider/payment integrations. | Supports realistic application journeys without using customer records or production credentials. |

## Address layout

| Network | Address range | Contents |
| --- | --- | --- |
| `vnet-restsim-dev` | `10.30.0.0/22` | Development address space. |
| Reserved block | `10.30.0.0/24` | Room for later requirements. |
| `snet-dev-app` | `10.30.1.0/24` | Web/API VM; scheduled provider jobs are disabled in its runtime configuration. |
| `snet-dev-data` | `10.30.2.0/24` | Delegated PostgreSQL subnet. |
| `snet-dev-private-endpoints` | `10.30.3.0/24` | Files and Key Vault private endpoints. |

## The trade-off

I used one VM for developer staging to keep its footprint smaller. Production keeps the multi-instance web tier, shared sessions and rolling-release design because its availability requirements are different.
