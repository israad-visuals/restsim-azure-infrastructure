# RestSim architecture

[Project overview](../../README.md)

[View architecture diagrams](https://viewer.diagrams.net/?nav=1&title=RestSim%20Azure%20Architecture#Uhttps%3A%2F%2Fraw.githubusercontent.com%2Fisraad-visuals%2Frestsim-azure-infrastructure%2Fmain%2Fdocs%2Farchitecture%2FRestSim-Azure-Architecture.drawio)

These pages explain the problems behind the Azure design, why I chose each component and the improvement it is intended to provide. Each page includes its diagram alongside the explanation.

RestSim's growing customer base is the reason for the work: the current single-VPS setup needs a path toward better availability, shared data, controlled changes and clearer monitoring.

| Architecture page | What it explains |
| --- | --- |
| [Landing zone](01-landing-zone.md) | How the resources are organised and why compute, data, identity and recovery are separated. |
| [Production network](02-production-network.md) | How customers reach the application and why its dependencies use private connections. |
| [Development network](03-development-network.md) | How developers test and stage application changes in an environment isolated from production. |
| [Application CI/CD](04-application-cicd.md) | How one application version moves through testing, deployment and recovery. |
| [Terraform CI/CD](05-terraform-cicd.md) | How infrastructure changes become repeatable and reviewable. |
| [Production monitoring](06-production-monitoring.md) | How application, VM and service signals support troubleshooting. |

The diagrams present the Azure design. The production Terraform contains its resource definitions; the workflow folder is a scaffold. The live customer service remains on the existing VPS, while the Azure environment uses separate credentials and synthetic data. Deployment evidence and measured outcomes are separate from these design explanations.
