# Azure DevOps Pipeline Setup Guide

This guide explains how to set up and run the Terraform and deployment pipelines with MongoDB Atlas integration.

## 1. Prerequisites

- Azure DevOps project created
- Service connection (`sc-azure-terraform`) configured with credentials
- Terraform state storage account provisioned (via bootstrap pipeline)
- MongoDB Atlas cluster provisioned with connection string ready
- JWT key generated (see MONGODB_ATLAS_SETUP.md for generation methods)

## 2. Create Variable Group: `Mongo-secrets`

This variable group stores sensitive credentials used by both Terraform and deployment pipelines.

### Steps

1. **Navigate to Azure DevOps Library**
   - Go to your Azure DevOps project
   - Click **Pipelines** → **Library**
   - Click **+ Variable group**

2. **Create the Variable Group**
   - **Name**: `Mongo-secrets`
   - **Description**: `Database secrets (MongoDB Atlas, JWT)`
   - Toggle: **Link secrets from an Azure key vault as variables** (optional, recommended for production)

3. **Add Variables**

   Add the following variables (all marked as **Secret** by clicking the lock icon):

   | Variable Name | Value | Secret | Notes |
   |---|---|---|---|
   | `mongo-connection-string` | `mongodb+srv://user:pass@cluster.mongodb.net/db?retryWrites=true&w=majority` | ✓ | From MongoDB Atlas |
   | `jwt_key` | `generated-jwt-secret-key` | ✓ | Generate using `openssl rand -base64 64` |
   | `mongodb-api-key` | `your-atlas-api-key` | ✓ | Optional, for automation |

4. **Save Variable Group**
   - Click **Save**

### Variable Group Permissions

To restrict access:
1. Open the variable group
2. Click **Pipeline permissions**
3. Configure which pipelines can access these variables

## 3. Update Terraform Environment File

Create your environment-specific tfvars file:

```bash
# Copy the example
cp environments/dev/terraform.tfvars.example environments/dev/terraform.tfvars

# Edit and set environment-specific values (do NOT set mongodb_atlas_connection_string or jwt_key here)
# These will be passed by the pipeline from the variable group
```

**Note**: `mongodb_atlas_connection_string` and `jwt_key` are NOT set in tfvars — the pipeline passes them via `-var` flags from the variable group.

## 4. Run Terraform Apply Pipeline

The pipeline automatically reads from the `Mongo-secrets` variable group and passes credentials to Terraform.

### Via Azure DevOps UI

1. Go to **Pipelines** → **azure-pipelines-apply.yml**
2. Click **Run pipeline**
3. Set parameters:
   - **Environment**: `dev` (or `stage`/`prod`)
   - **serviceConnection**: `sc-azure-terraform` (default)
   - **Decommission**: `false` (for apply) or `true` (for destroy)
4. Click **Run**

### Pipeline Flow

```
Fetch code + variable group (mongo-connection-string, jwt_key)
  ↓
Terraform Init (backend config)
  ↓
Terraform Plan (with -var flags from variable group)
  ↓
Manual Approval (review plan)
  ↓
Terraform Apply (with -var flags from variable group)
  ↓
Output: AKS cluster, ACR, Key Vault
```

### What Gets Created

- **Resource Group**: Contains all resources
- **AKS Cluster**: Kubernetes cluster with RBAC, OIDC issuer, workload identity
- **Azure Container Registry (ACR)**: For Docker images
- **Azure Key Vault**: Stores MongoDB Atlas connection string and JWT key
- **Log Analytics**: For monitoring
- **Virtual Network**: For AKS connectivity
- **Key Vault Secrets**:
  - `mongo-connection-string`: MongoDB Atlas connection
  - `jwt-key`: JWT signing key

## 5. Deploy Microservices Pipeline (Optional)

After Terraform completes, deploy services using the app deployment pipeline.

### Pipeline Stages

The `PIPELINE_SNIPPET.yaml` file (in microservices repo) shows the full deployment pipeline:

**Stage 1: Build & Push Images**
- Builds Docker images for all services
- Pushes to ACR with tags `latest` and `$(Build.BuildId)`

**Stage 2: Create Kubernetes Secrets**
- Retrieves credentials from variable group
- Creates `mongo-secret` with all `MONGO_URI_*` keys
- Creates `jwt-secret` with `JWT_KEY`

**Stage 3: Deploy Microservices**
- Updates k8s manifests with ACR image references
- Deploys services to AKS
- Verifies deployments

### To Run Deployment Pipeline

1. Create a new YAML pipeline using `PIPELINE_SNIPPET.yaml` as a template
2. Add variable group reference:
   ```yaml
   variables:
     - group: Mongo-secrets
   ```
3. Run the pipeline

## 6. Verify Deployment

### Check AKS Resources

```bash
# Get AKS credentials
az aks get-credentials --resource-group rg-microservices-dev-cin-abcd --name aks-microservices-dev-cin-abcd

# Check key vault (created by Terraform)
kubectl get secret mongo-secret -o yaml
kubectl get secret jwt-secret -o yaml

# Check pods
kubectl get pods
kubectl get deployments

# Check service status
kubectl logs <pod-name>
```

### Check Terraform Outputs

After apply completes, view outputs:

```bash
terraform output
```

Key outputs:
- `aks_name`: AKS cluster name
- `acr_login_server`: ACR endpoint
- `keyvault_name`: Key Vault name
- `mongo_secret_name`: K8s secret name in Key Vault

## 7. Troubleshooting

### Pipeline Fails: Variable Group Not Found

**Error**: `##[error]The variable group 'Mongo-secrets' could not be found`

**Solution**: 
- Ensure `Mongo-secrets` variable group exists in Library
- Verify the pipeline has permission to access the variable group
- Check variable group name spelling (case-sensitive)

### Secret Values Masked in Pipeline Logs

This is expected behavior for variables marked as **Secret**. To debug:
- Add `echo` statements that reference non-secret variables
- Use Azure CLI to query created resources after pipeline completes

### Terraform Plan Shows "Sensitive" Values

This is expected for variables marked as `sensitive` in Terraform. The plan output will show `(sensitive)` instead of actual values.

### AKS Cluster Creation Timeout

- Check Azure quota limits for your subscription
- Verify service connection has sufficient permissions
- Check regional availability (pipeline restricts to allowed regions)

## 8. Scaling & Advanced Configuration

### Node Pool Autoscaling

To enable autoscaling on the system node pool (currently using static `node_count`):

In `stacks/aks/main.tf`, update the `default_node_pool` to use:
```hcl
enable_auto_scaling = true
min_count           = var.system_node_min_count
max_count           = var.system_node_max_count
```

### Multiple Environments

Repeat the above steps for `stage` and `prod`:

```bash
cp environments/dev/terraform.tfvars.example environments/stage/terraform.tfvars
cp environments/dev/terraform.tfvars.example environments/prod/terraform.tfvars
```

Edit each environment's tfvars with appropriate values (cluster size, region, etc.).

## 9. Cleanup & Decommissioning

To destroy all resources:

1. Run the **azure-pipelines-destroy.yml** pipeline
2. Set parameters:
   - **environment**: `dev` (or `stage`/`prod`)
   - **Decommission**: `true`
   - **ConfirmDestroy**: `YES`
3. Review destroy plan, then approve

This will:
- Destroy AKS cluster, ACR, Key Vault, and all supporting resources
- Remove Terraform state file (if decommission bootstrap is also run)

## 10. Best Practices

- ✓ Always review terraform plan before approving apply
- ✓ Use separate variable groups for dev/stage/prod environments
- ✓ Rotate JWT keys periodically
- ✓ Store backups of MongoDB Atlas regularly
- ✓ Monitor Azure spending via Cost Management
- ✓ Enable Azure Policy for compliance
- ✓ Use private endpoints for Key Vault / database in production
- ✓ Configure alerts for pipeline failures

## 11. Next Steps

After successful deployment:

1. **Configure Ingress & TLS**: Set up ingress controller, DNS, and SSL certificates
2. **Set Up Monitoring**: Configure Application Insights or Prometheus/Grafana
3. **Configure CI/CD**: Set up continuous deployment trigger on code push
4. **Security Hardening**: Enable pod security policies, RBAC, network policies
5. **Backup & Disaster Recovery**: Configure AKS backup, database backups

See `MONGODB_ATLAS_SETUP.md` for MongoDB Atlas integration details.
