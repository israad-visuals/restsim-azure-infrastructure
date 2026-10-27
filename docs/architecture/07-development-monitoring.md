# Development monitoring

[Project overview](../../README.md) · [Architecture pages](README.md)

I kept development monitoring separate from production so developers can investigate application changes without mixing the two environments' logs or notifications. I used the same Azure monitoring services with a smaller collection budget and two focused alerts.

[![RestSim development monitoring](07-development-monitoring.png)](https://viewer.diagrams.net/?nav=1&title=RestSim%20Azure%20Architecture&page-id=gxs_Zrl31glBiPyCSrfB#Uhttps%3A%2F%2Fraw.githubusercontent.com%2Fisraad-visuals%2Frestsim-azure-infrastructure%2Fmain%2Fdocs%2Farchitecture%2FRestSim-Azure-Architecture.drawio)

[Open full-size image](07-development-monitoring.png) · [Open draw.io viewer](https://viewer.diagrams.net/?nav=1&title=RestSim%20Azure%20Architecture&page-id=gxs_Zrl31glBiPyCSrfB#Uhttps%3A%2F%2Fraw.githubusercontent.com%2Fisraad-visuals%2Frestsim-azure-infrastructure%2Fmain%2Fdocs%2Farchitecture%2FRestSim-Azure-Architecture.drawio)

## What I collect and why

| Component | Configuration | Reason for the choice |
| --- | --- | --- |
| Azure Monitor Agent and Data Collection Rule | Warning-and-higher syslog; CPU, memory and disk counters every 60 seconds. | Gives developers Linux events and resource usage in one place when a release has a problem. |
| Azure service diagnostics | `allLogs` for PostgreSQL, Key Vault and the Azure Files service. | Adds database, secret-access and file-service events to the same investigation. |
| Application Insights | `appi-restsim-dev`, linked to the development workspace; 25% sampling configured. | Provides a destination for application request and dependency telemetry through application instrumentation. |
| Log Analytics | `law-restsim-dev`; 30-day retention and a 0.5 GB/day ingestion cap. | Keeps a useful troubleshooting window while controlling the volume of retained development logs. |

The agent follows `dcr-restsim-dev-linux` and sends `Microsoft-Syslog` and `Microsoft-Perf` to the workspace. Syslog collection includes the `auth`, `authpriv`, `daemon`, `syslog` and `user` facilities. Service diagnostics send resource logs; platform metric alerts are evaluated separately.

## Alerts and notification flow

| Signal | Trigger | Severity |
| --- | --- | --- |
| Development VM CPU | Average above 85% over 15 minutes. | 3 |
| PostgreSQL storage | Average above 80% over 15 minutes. | 2 |

Both rules evaluate every five minutes and notify `ag-restsim-dev-operations`. The action group sends email to `alert_email` using the common alert schema. I chose these rules to highlight sustained VM pressure and database capacity before they interrupt development work.

## Cost and application integration

I limited routine syslog noise, used a 60-second performance interval and kept two alert rules. The ingestion cap controls data collection volume; it is not a total monitoring spending limit and can leave gaps when reached.

The dashed application path represents SDK instrumentation. Terraform creates Application Insights and its workspace link; the application supplies request and dependency telemetry through its instrumentation. The VM agent handles guest monitoring separately.
