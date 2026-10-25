# Development network: developer testing and staging

[Project overview](../../README.md) · [Architecture pages](README.md)

I designed development as the developers' environment for testing and staging RestSim application changes before a production release. It is isolated from production, with separate networking, data, credentials and access controls. A smaller workload keeps routine development costs lower, while a protected staging URL gives the development team access to the application.

![RestSim development network topology](03-development-network.png)

## How developers reach the application

**Developer → staging hostname → HTTPS entry point → OAuth2 Proxy and Microsoft Entra ID → RestSim application**

Azure DNS provides the public staging name. OAuth2 Proxy uses Entra ID for sign-in and enforces the development-team access policy before forwarding a request to the application on loopback. The application's upstream port stays private.

Entra ID provides the identity and the proxy enforces access. The NSG has a separate role: filtering network traffic. This avoids treating a network rule as a user sign-in system.

## Why I chose this setup

| RestSim requirement | Design choice | Intended improvement |
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
| `snet-dev-app` | `10.30.1.0/24` | Web/API VM and controlled test background jobs. |
| `snet-dev-data` | `10.30.2.0/24` | Delegated PostgreSQL subnet. |
| `snet-dev-private-endpoints` | `10.30.3.0/24` | Files and Key Vault private endpoints. |

## The trade-off

One VM is suitable for routine functional testing, but it does not represent production's multi-instance availability. The design keeps that cost trade-off visible: shared-session behaviour, rolling releases and failover belong to a separate multi-instance validation scope.
