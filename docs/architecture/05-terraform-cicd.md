# Terraform CI/CD: repeatable and reviewable infrastructure changes

[Project overview](../../README.md) · [Architecture pages](README.md)

As RestSim's infrastructure grows beyond one server, changes need to be understandable and repeatable. I chose Terraform to describe the Azure resources in code and designed a separate infrastructure pipeline so network or storage changes do not become mixed with application releases.

[![RestSim Terraform infrastructure CI/CD design](05-terraform-cicd.png)](https://viewer.diagrams.net/?nav=1&title=RestSim%20Azure%20Architecture&page-id=8nira5fFPzOVPsJZNsbC#Uhttps%3A%2F%2Fraw.githubusercontent.com%2Fisraad-visuals%2Frestsim-azure-infrastructure%2Fmain%2Fdocs%2Farchitecture%2FRestSim-Azure-Architecture.drawio)

## Why I chose these controls

| RestSim requirement | Design choice | Intended improvement |
| --- | --- | --- |
| Keep infrastructure settings consistent and explainable. | Terraform configuration held in Git. | Makes resource definitions and their history reviewable. |
| Catch configuration problems before deployment. | Formatting, validation, security checks and a plan preview on pull requests. | Gives the reviewer a view of the change before it reaches an environment. |
| Reduce the risk of testing directly against production. | Separate development and production configuration and state. | Allows environment-specific review without mixing their resource records. |
| Understand what a production change will replace or delete. | A fresh production plan with a separate review gate. | Makes potentially disruptive actions visible before apply. |
| Keep the reviewed change tied to the deployment. | Apply the exact saved plan. | Prevents an unrelated new plan from silently replacing the reviewed one. |
| Keep state management simple while working locally. | A local `terraform.tfstate` file in each environment folder. | Records production and development separately without a dedicated Azure state-storage account. |
| Avoid storing a long-lived Azure client secret in GitHub. | GitHub OIDC and scoped deployment identities. | Ties Azure access to the trusted repository and job context. |
| Retain the resource record through deployment and cleanup. | Protected local state backups, kept outside Git. | Preserves the state needed to manage and remove resources. |

## How an infrastructure change moves

**Pull request → checks and plan preview → review and merge → development deployment → production plan review → saved-plan apply**

Development and production use different inputs and state, so their plans are separate artifacts. The production review covers creates, updates, replacements, deletions and cost implications. State, private inputs and saved plans stay outside the public repository because they can contain sensitive values.

## Access and change ownership

The infrastructure identity has scoped resource-group and vault permissions. Subscription-level policies and role assignments have a separate administrative permission requirement. The runner also needs a private network path to protected services.

Terraform owns resource configuration. Autoscale owns the current web instance count, and application delivery owns later Gallery release versions. Keeping those responsibilities explicit prevents an infrastructure change from resetting an application release or undoing a scaling decision.

Infrastructure recovery uses the failed change, resource state and a new reviewed plan. Application rollback and database/file recovery remain separate processes.

I run Terraform from the local deployment machine. Production uses `terraform/environments/production/terraform.tfstate`; development uses `terraform/environments/development/terraform.tfstate`. These files and their backups stay out of Git. Local state remains on this machine; GitHub-hosted infrastructure runs would need a persistent state arrangement before use.
