# RestSim — Azure Cloud Infrastructure Engineering

**Landing Zone · Terraform · Networking · High Availability · Security · CI/CD · Cloud Operations**

An Azure infrastructure engineering project for RestSim, a travel eSIM web and mobile product. The project focuses on environment separation, repeatable infrastructure, private service connectivity, resilient compute and cloud operations.

## Project status

**Architecture and implementation planning.** This is the initial repository setup. Terraform code, deployment workflows and verified Azure deployment results will be added as the project progresses.

## Engineering scope

| Area | Intended deliverable |
| --- | --- |
| Landing zone | Management-group hierarchy, separate development and production subscriptions, resource-group structure and governance. |
| Terraform | Reusable infrastructure definitions, environment configuration and separate remote state. |
| Networking | Production and development topologies, subnet design, ingress, private connectivity and DNS. |
| High availability | Multi-instance production compute, shared application dependencies and recovery design. |
| Security | Scoped identities, secrets management, tester authentication and network controls. |
| CI/CD | Infrastructure review, validation, environment approvals and controlled deployment. |
| Cloud operations | Monitoring, alerting, release health, recovery validation, cost tracking and cleanup. |

## Planned milestones

- [ ] Publish the reviewed landing-zone, network and CI/CD architecture diagrams.
- [ ] Implement and verify an isolated development environment with Terraform.
- [ ] Add infrastructure validation and deployment workflows.
- [ ] Document network, identity, monitoring and recovery test results.
- [ ] Record deployment costs, teardown evidence and engineering decisions.

## Evidence standard

Architecture diagrams describe the target design. Implemented features and operational results will be linked to dated code, checks and deployment evidence as they are completed.
