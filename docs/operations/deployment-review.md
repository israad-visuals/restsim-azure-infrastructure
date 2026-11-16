# Deployment review: setup, troubleshooting and cleanup

[Project overview](../../README.md) · [Architecture guides](../architecture/README.md)

I reviewed the production Terraform configuration in Azure. The October 28, 2026 run covered configuration checks, an execution plan, resource creation, subscription troubleshooting and cleanup. RestSim's live service remained on its existing VPS throughout.

## Starting with the application requirements

RestSim's single VPS keeps hosting costs low, but it ties availability, application files and background work to one server. I mapped those dependencies before choosing the Azure services. The design separates web instances, a worker, PostgreSQL, shared files, sessions, secrets and monitoring. Development has its own smaller configuration for developer testing and staging.

I organised the Terraform into separate environment folders, keeping the resource definitions together within each environment. This makes the relationships between the network, application and data resources easier to follow.

## Setup problems and changes

| Problem encountered | What I changed | Result |
| --- | --- | --- |
| Terraform was run from the repository root and found no configuration. | Used the production environment folder as the Terraform working directory. | Terraform loaded the production resource definitions together. |
| The Azure backend requested a storage account, container and state key before planning. | Used separate local state for each environment and kept protected backups outside Git. | Initialization completed without requiring a remote state account. |
| Plans repeatedly requested account details and an SSH public key. | Read the signed-in Azure account, generated a dedicated SSH key and saved environment values in ignored local variable files. | Terraform loaded the saved values automatically; the private key stayed outside the repository. |
| Creating infrastructure required an application package that had not been published. | Separated application installation from infrastructure provisioning. | The infrastructure-only configuration omitted Gallery package attachments and disabled application-dependent rolling updates and automatic repairs. |
| Infrastructure planning still requested Cloudflare and origin TLS settings. | Made application-specific inputs and TLS secret grants conditional on application installation. | The infrastructure-only plan completed without invented audience IDs or certificates. Application mode retained its required inputs. |
| An older interactive plan held the local state lock. | Cancelled that plan before starting the next operation. | The next plan acquired the lock normally, without force-unlocking or bypassing locking. |

GitHub deployment identities were disabled in the local configuration for this manual Azure run. Application installation was also disabled. The run did not change the live Cloudflare configuration or use production customer data.

## Checks and execution plan

| Check | Observed result |
| --- | --- |
| Terraform formatting and configuration validation | Passed. |
| Three local checks using mocked providers | Infrastructure mode omitted application packages and TLS grants; application mode required its release and security inputs and retained its rollout settings. |
| Azure Terraform plan | Completed successfully: **122 creates, 4 updates, 0 deletions**. |
| State and input handling | State, saved plans, real variable files and private keys stayed outside Git. |

The mocked checks exercised configuration behavior without creating Azure resources. The Azure plan refreshed the existing resource groups and described the changes before apply.

## Azure provisioning results

The run updated the four existing resource groups and created:

- Five private DNS zones for PostgreSQL, Files, Redis, Key Vault and artifact Blob Storage.
- An operations action group and a Resource Health alert.
- A monthly subscription budget.
- Region and tagging policy definitions and assignments.

Azure then rejected regional resources with `RequestDisallowedByAzure`. The configured region, `eastus`, was outside the subscription's permitted deployment regions. The VNet, VMs, database, storage accounts, Redis, Key Vault and backup vault were not created in this run.

## How I investigated the restriction

I compared the error with the subscription's effective policy assignments. The system region policy listed five permitted regions and excluded `eastus`. I also found that the project's own newly created region policy allowed only `eastus`, so a retry needed both the deployment location and that project policy to agree.

I checked service access and VM quotas before selecting another region:

| Finding on October 28, 2026 | Why it affects the next deployment |
| --- | --- |
| The configured DSv5 VM family had zero quota in all five permitted regions. | The VM size needs an eligible family or an approved quota increase. |
| The regional VM allowance was 6 vCPUs. | Two 2-vCPU web instances and one 2-vCPU worker fit that allowance; four web instances plus the worker would exceed it. |
| PostgreSQL reported subscription provisioning restrictions in East US 2, South Central US and West US 2. | A region allowed by the general subscription policy can still be unavailable for a particular service. |
| North Central US exposed PostgreSQL General Purpose and zone-redundant HA capabilities. | It became a candidate for further SKU and availability checks. |

These checks identified the requirements for a new deployment. They did not establish that every service or application path would work in another region.

## Cleanup and verification

The first destroy attempt was blocked by the resource groups' `prevent_destroy` settings. I kept a private state backup, checked that the groups contained only project resources and used a temporary local override for those four deletion guards.

I reviewed the saved destroy plan against the resource IDs in state before applying it:

```text
Reviewed cleanup plan: 0 to add, 0 to change, 18 to destroy.
Completed cleanup:    18 tracked entries removed; no additions or updates.
```

The 18 entries included 16 Azure resources or management objects and two locally generated values. Azure checks then confirmed that:

- All four RestSim resource groups and their contained resources were removed.
- The project budget, custom policy assignments and custom policy definitions were removed.
- The unrelated resource and resource-group IDs matched the inventory taken before cleanup.
- Terraform had no remaining managed resource instances and no state lock.

I removed the temporary override afterward. The normal deletion guards remained in the source configuration, and the code and private state backup were preserved.

## Requirements for a retry

The review identified the requirements for a retry: an eligible region and VM size, scaling within the subscription quota, and a private route for Key Vault secret setup. The cost review and teardown plan also needed to account for backup retention and Key Vault purge protection.

Application setup is a separate milestone: the current cloud-init template writes runtime configuration. Installing RestSim, configuring the database application role, mounting shared files, setting up TLS and checking application health require their own deployment and verification.
