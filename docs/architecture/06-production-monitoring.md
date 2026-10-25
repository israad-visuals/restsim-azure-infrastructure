# Production monitoring: understanding RestSim failures

[Project overview](../../README.md) · [Architecture pages](README.md)

RestSim already has server-health monitoring. Moving to several application instances and managed services adds more places where a request can fail. I chose a central Azure monitoring design to connect application errors, Linux events and service health instead of treating each server as a separate view.

[![RestSim production monitoring design](06-production-monitoring.png)](https://viewer.diagrams.net/?nav=1&title=RestSim%20Azure%20Architecture&page-id=ZR1PCFiNJjQxqDGBOhbM#Uhttps%3A%2F%2Fraw.githubusercontent.com%2Fisraad-visuals%2Frestsim-azure-infrastructure%2Fmain%2Fdocs%2Farchitecture%2FRestSim-Azure-Architecture.drawio)

## Why I chose each monitoring component

| RestSim requirement | Design choice | Intended improvement |
| --- | --- | --- |
| Understand which requests or dependencies are failing. | Application Insights with application instrumentation. | Adds application-level context beyond CPU and server availability. |
| Investigate several VMs and services together. | A shared Log Analytics workspace. | Provides one query location for the collected logs. |
| See Linux service and authentication problems. | Azure Monitor Agent and a Data Collection Rule. | Collects selected guest events from the VMSS and worker consistently. |
| Include managed dependencies in the same operational view. | Diagnostic settings for PostgreSQL, Redis, Files, Key Vault, artifact storage and Load Balancer. | Brings supported service events into the workspace. |
| Avoid depending on someone watching a dashboard. | Metric and Resource Health alerts with an action group. | Sends operational notifications when configured conditions occur. |
| Keep monitoring useful without collecting everything. | Warning-and-higher syslog selection, retention and ingestion controls. | Reduces routine noise and helps manage log volume. |

## How the signals connect

Application instrumentation sends request, dependency and failure telemetry through Application Insights to the linked workspace. Azure Monitor Agent sends the selected Linux events through the DCR. Service diagnostic settings provide the platform events each resource supports.

Metric alerts and Resource Health rules use the operations action group, `ag-restsim-prod-ops`, to send email notifications. This provides a common response path while keeping log collection and alert evaluation separate.

## Alert choices in the Terraform

The seven metric rules evaluate every minute over a 15-minute window:

| Signal | Trigger | Why it matters to RestSim |
| --- | --- | --- |
| PostgreSQL CPU and storage | Average above 80%, in separate rules. | Highlights database pressure before it affects more requests. |
| Redis server load | Average above 80%. | Highlights pressure on the shared session service. |
| Failed application requests | Total above 5 in the window. | Draws attention to errors affecting application requests. |
| VMSS and worker CPU | Average above 85%, in separate rules. | Separates web capacity pressure from background-job pressure. |
| Load-balancer probe health | Average `DipAvailability` below `0.99`. | Highlights unhealthy application backends. |

A separate Resource Health rule covers degraded, unavailable and unknown states. The probe threshold represents backend health, rather than a measured customer-uptime target.

## Operational and cost decisions

The workspace keeps logs for 30 days with a 5 GB/day ingestion cap. The cap limits ingestion, with a trade-off of missing logs if it is reached; it is not a total spending limit. Application Insights is configured for 100% sampling.

An alert starts an investigation. The useful connection is between the failure time, affected dependency, VM events and release version. Credentials, payment details, activation codes and customer information are excluded from the intended telemetry content.

Terraform defines the monitoring resources and collection rules. Application instrumentation supplies request-level telemetry; installing the VM agent alone does not add that application context.
