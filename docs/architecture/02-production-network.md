# Production network: connecting customers to private services

[Project overview](../../README.md) · [Architecture pages](README.md)

RestSim needs to grow beyond a single application server without exposing its database, files or secrets to customers. I separated the public entry point, application compute and private dependencies so each connection has a clear purpose.

[![RestSim production network topology](02-production-network.png)](https://viewer.diagrams.net/?nav=1&title=RestSim%20Azure%20Architecture&page-id=FVyJa8Ms7tz5EjTs3-nd#Uhttps%3A%2F%2Fraw.githubusercontent.com%2Fisraad-visuals%2Frestsim-azure-infrastructure%2Fmain%2Fdocs%2Farchitecture%2FRestSim-Azure-Architecture.drawio)

## How a customer request moves through the design

**Web or mobile user → Cloudflare → Standard Load Balancer → healthy RestSim web instance**

Cloudflare remains the customer entry point because RestSim already uses it for DNS and proxying. Standard Load Balancer distributes TCP connections across the VMSS backends. Apache on each instance handles the origin HTTPS connection.

From there, the application reaches PostgreSQL for records, Azure Files for shared uploads, Redis for sessions and Key Vault for permitted secrets. The worker uses its own identity for the dependencies it needs.

## Why I chose each network component

| RestSim requirement | Design choice | Intended improvement |
| --- | --- | --- |
| Keep the existing customer-facing entry point. | Cloudflare in front of the Azure origin. | Avoids changing the public access approach while adding Azure compute behind it. |
| Share requests across several web servers. | Standard Load Balancer with a readiness probe. | Routes new connections to healthy backends instead of relying on one VPS. |
| Different services need different access rules. | Separate application, database and private-endpoint subnets with NSGs. | Makes permitted paths explicit and limits unnecessary connections. |
| The database should be reachable by the application privately. | PostgreSQL VNet integration in a dedicated delegated subnet. | Provides database access without a public PostgreSQL endpoint. |
| Files, sessions, secrets and release storage need private access. | Private endpoints for Files, Redis, Key Vault and artifact Blob Storage. | Gives these services private addresses inside the network. |
| Private services still need stable names. | Private DNS zones linked to the VNet. | Lets the application use service hostnames rather than hard-coded private IPs. |
| Private VMs need outbound access for required services. | NAT Gateway and explicit outbound NSG rules. | Provides a defined outbound address without public IPs on individual VMs. |
| Administration should not require public SSH. | SSH rules limited to configured private management ranges. | Keeps the management path separate from customer traffic. |

## Address layout

| Network | Address range | Contents |
| --- | --- | --- |
| `vnet-restsim-prod` | `10.20.0.0/22` | Production address space. |
| Reserved block | `10.20.0.0/24` | Room for later requirements. |
| `snet-prod-app` | `10.20.1.0/24` | VMSS instance NICs and the worker NIC. |
| `snet-prod-data` | `10.20.2.0/24` | Delegated PostgreSQL subnet. |
| `snet-prod-private-endpoints` | `10.20.3.0/24` | Files, Redis, Key Vault and artifact-storage endpoints. |

I used a `/22` VNet to contain the three clearly numbered `/24` subnets and one reserved block. This makes the layout easier to follow without committing to a large number of running servers.

## Traffic controls

The configuration allows customer-facing TCP 80/443 from the configured Cloudflare IPv4 ranges. Database traffic uses TCP 5432; private service paths use HTTPS 443, SMB 445 and encrypted Redis 10000. The load balancer has a separate readiness listener on HTTP 8081.

NSGs control addresses and ports. NAT supplies outbound connectivity, while the origin certificate and application identity controls handle their own responsibilities. The design keeps those controls separate rather than expecting one network component to provide every form of security.
