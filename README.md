# AKS Terraform Platform (Azure DevOps)

This repository provisions AKS on Azure using Terraform and runs fully remote from Azure DevOps.

It includes:
- Production-style Terraform module layout
- Environment-specific configuration for dev, stage, and prod
- Azure DevOps apply and destroy pipelines
- Strict mode guardrails so apply and destroy cannot be mixed accidentally
- Region guardrails aligned with your Azure Policy

## Repository Structure

```text
infrastructure-Terraform/
  modules/
    resource_group/
    network/
    acr/
    monitoring/
    aks/
  stacks/
    aks/
  environments/
    dev/
    stage/
    prod/
  pipelines/
    templates/
      terraform-stages.yml
  scripts/
    bootstrap-tfstate-backend.sh
  azure-pipelines-bootstrap-state.yml
  azure-pipelines-apply.yml
  azure-pipelines-destroy.yml
```

## Allowed Regions

Your policy allows only these locations:
- malaysiawest
- southeastasia
- uaenorth
- centralindia
- koreacentral

The stack validates this through:
- Terraform variable validation in stacks/aks/variables.tf
- Pipeline precheck in pipelines/templates/terraform-stages.yml

## What Gets Created

- Resource Group
- Virtual Network + AKS subnet
- Azure Container Registry (ACR)
- Log Analytics workspace
- AKS cluster with:
  - System node pool (autoscaling)
  - Optional user node pool (autoscaling)
  - OIDC issuer enabled
  - Workload identity enabled
  - Azure policy add-on enabled
- AcrPull role assignment from AKS kubelet identity to ACR

## Azure DevOps Setup

Create an Azure DevOps project and define three YAML pipelines:
1. Bootstrap pipeline using azure-pipelines-bootstrap-state.yml
2. Apply pipeline using azure-pipelines-apply.yml
3. Destroy pipeline using azure-pipelines-destroy.yml

Create pipeline variables (or variable group) with these names:
- PIPELINE_APPROVER_EMAILS (optional, defaults to run initiator)

Service connection selection:
- Pipelines use a runtime parameter named serviceConnection.
- Default is sc-azure-terraform.
- Change it only if your service connection uses a different name.

Terraform backend defaults in Apply/Destroy runtime parameters:
- stateResourceGroup: rg-tfstate-shared
- stateStorageAccount: sttfstatepyq8
- stateContainer: tfstate
- stateKeyPrefix: aks
- Override these in Run pipeline if your backend values change.

Recommended:
- Use workload identity federation in service connection
- Configure environment approvals on:
  - aks-dev-apply, aks-stage-apply, aks-prod-apply
  - aks-dev-destroy, aks-stage-destroy, aks-prod-destroy

## Bootstrap Backend Pipeline

File: azure-pipelines-bootstrap-state.yml

Use this pipeline to create or destroy Terraform backend resources remotely in Azure DevOps:
- Resource group
- Storage account
- Blob container for tfstate

Runtime parameters:
- location (must be policy-allowed)
- resourceGroupName
- storageAccountName (used as prefix; pipeline appends random suffix)
- containerName
- Decommission (false=create, true=destroy)
- ConfirmDestroy (must be YES when Decommission=true)

The pipeline uses scripts/bootstrap-tfstate-backend.sh and is idempotent.
You can rerun it safely.

Bootstrap flow behavior:
- Decommission=false:
  - Validate request
  - Create backend resources
  - Generate final storage account name from prefix + random suffix
- Decommission=true:
  - Validate request
  - Manual approval
  - Destroy backend resource group and all contained resources

Important:
- For cleanup, first run infra destroy pipeline for all environments.
- Run bootstrap with Decommission=true and ConfirmDestroy=YES only after all infra is gone.
- After bootstrap succeeds, ensure Apply/Destroy runtime parameters use backend values from bootstrap output.

## How Apply Pipeline Works

File: azure-pipelines-apply.yml

- Triggered on main/dev changes to Terraform paths
- Runs validate + plan
- Mandatory manual approval after plan
- Applies only for non-PR runs
- Decommission is hardcoded to false
- Mode guard enforces apply behavior only
- Uses environment tfvars file:
  - environments/<environment>/terraform.tfvars

## How Destroy Pipeline Works

File: azure-pipelines-destroy.yml

Runtime parameters:
- environment: dev/stage/prod
- ConfirmDestroy: must be YES for destroy execution

Destroy flow:
1. Validate
2. Destroy plan
3. Mandatory manual approval after destroy plan
4. Destroy apply only when:
  - Decommission is hardcoded to true
  - ConfirmDestroy is YES
  - Environment approval (if configured) is granted
5. Mode guard enforces destroy behavior only

## First Run Checklist

1. Run bootstrap pipeline (azure-pipelines-bootstrap-state.yml).
2. Set Azure DevOps pipeline variables listed above.
3. Run apply pipeline for dev.
4. Verify outputs in pipeline logs:
   - AKS name
   - ACR login server
   - Resource group
5. Use these outputs in your app deployment repository pipeline.

## Security Notes for Public Repo

Safe to keep public:
- Terraform code
- YAML pipeline logic
- Non-secret tfvars defaults

Never commit:
- Access keys or client secrets
- Real secret tfvars files
- Terraform state files
- kubeconfig files

## Next Integration Step

After apply succeeds, connect your app repo pipeline to:
- Build/push images to ACR
- Deploy manifests or Helm to AKS
- Expose app via ingress + domain + TLS
- Add New Relic and Datadog agents for observability
