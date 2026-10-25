# Application CI/CD: consistent releases across RestSim servers

[Project overview](../../README.md) · [Architecture pages](README.md)

Deploying to one VPS is different from keeping several web instances and a worker on the correct version. I designed the Azure release extension around RestSim's existing GitHub Actions and RQOS checks, with one versioned package moving through staging and controlled deployment.

![RestSim application CI/CD and recovery design](04-application-cicd.png)

## Why I chose each release component

| RestSim requirement | Design choice | Intended improvement |
| --- | --- | --- |
| Keep the existing application checks. | Reuse Web CI and RQOS rather than create another test suite. | Builds on the existing release work and avoids competing pipelines. |
| Know exactly what code a release contains. | Source commit SHA, package manifest, version and SHA256. | Connects the deployed payload to its source and identifies the package bytes. |
| Avoid different builds reaching staging and production. | Build one Linux package and promote the same artifact. | Reduces differences caused by rebuilding for each environment. |
| Keep release packages private. | Private Azure Blob Storage. | Separates application artifacts from customer-facing traffic and storage. |
| Distribute software without logging into every VM. | Azure Compute Gallery VM Applications. | Provides a versioned installation path for both the VMSS and worker. |
| New or replacement VMs need the correct application version. | An exact application-version pin in the VMSS model. | Keeps scale-out tied to the selected release rather than an uncontrolled latest version. |
| A failed update should not continue across the fleet. | Staging, release approval, controlled batches and readiness checks. | Provides decision points to stop promotion and restore a prior compatible version. |
| Scheduled jobs must not run twice during a release. | A separate worker handover. | Keeps scheduler ownership separate from web rollout. |
| Automation needs Azure access without a stored client secret. | GitHub OIDC with separate publisher and release identities. | Limits the role of each job and avoids a long-lived Azure client secret in GitHub. |

## How the release moves

Developers test and stage the application in the development environment, isolated from production. The same versioned package moves toward production only after the staging checks and release gate.

**Existing checks → versioned package → private Blob → Compute Gallery → staging → release gate → controlled VMSS rollout**

The package contains the application and installation actions. Environment settings and secrets remain separate. The same payload can support web and worker roles with different configuration.

The Terraform rolling policy uses a maximum 50% batch and a five-minute pause. Readiness determines whether the next batch proceeds. The recovery path restores the previous compatible version in the VMSS model and affected instances; database changes have their own compatibility requirements.

## Worker and infrastructure ownership

Web instances have schedulers disabled. Worker handover drains work, stops the old scheduler, confirms ownership and then starts the replacement. This keeps scaling and release changes from multiplying scheduled jobs.

Terraform defines the infrastructure and initial Gallery version. Application delivery owns later version changes, while autoscale owns web instance count. The dashed Gallery arrows show deployment relationships, separate from Cloudflare and customer request traffic.

The pipeline diagram presents the Azure release extension. Gallery resources and identities provide its infrastructure; package installation and workflow integration are separate parts of implementing that release path.
