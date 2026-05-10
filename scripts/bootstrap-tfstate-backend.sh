#!/usr/bin/env bash
set -euo pipefail

ACTION="${1:-create}"
LOCATION="${2:-}"
RESOURCE_GROUP_NAME="${3:-}"
STORAGE_ACCOUNT_NAME="${4:-}"
CONTAINER_NAME="${5:-}"

if [[ "$ACTION" != "create" && "$ACTION" != "destroy" ]]; then
  echo "Error: action must be 'create' or 'destroy'."
  echo "Usage: $0 <create|destroy> <location> <resource_group_name> <storage_account_name> <container_name>"
  exit 1
fi

if [[ -z "$LOCATION" || -z "$RESOURCE_GROUP_NAME" || -z "$STORAGE_ACCOUNT_NAME" || -z "$CONTAINER_NAME" ]]; then
  echo "Usage: $0 <create|destroy> <location> <resource_group_name> <storage_account_name> <container_name>"
  exit 1
fi

allowed_locations=(malaysiawest southeastasia uaenorth centralindia koreacentral)
location_allowed=false
for allowed in "${allowed_locations[@]}"; do
  if [[ "$LOCATION" == "$allowed" ]]; then
    location_allowed=true
    break
  fi
done

if [[ "$location_allowed" != "true" ]]; then
  echo "Error: location '$LOCATION' is not allowed by policy."
  echo "Allowed: ${allowed_locations[*]}"
  exit 1
fi

generate_random_suffix() {
  local length="$1"
  local chars='abcdefghijklmnopqrstuvwxyz0123456789'
  local chars_len="${#chars}"
  local result=''

  while (( ${#result} < length )); do
    result+="${chars:$(( RANDOM % chars_len )):1}"
  done

  echo "$result"
}

sanitize_storage_prefix() {
  local raw="$1"
  echo "$raw" | tr '[:upper:]' '[:lower:]' | tr -cd 'a-z0-9'
}

SUBSCRIPTION_ID="$(az account show --query id --output tsv)"
SERVICE_PRINCIPAL_APP_ID="$(az account show --query user.name --output tsv)"
SERVICE_PRINCIPAL_OBJECT_ID="$(az ad sp show --id "$SERVICE_PRINCIPAL_APP_ID" --query id --output tsv)"

if [[ -z "$SUBSCRIPTION_ID" ]]; then
  echo "Error: unable to determine active Azure subscription from current login context."
  exit 1
fi

echo "Using subscription '$SUBSCRIPTION_ID'."
echo "Using service principal app id '$SERVICE_PRINCIPAL_APP_ID'."
echo "Using service principal object id '$SERVICE_PRINCIPAL_OBJECT_ID'."
az account set --subscription "$SUBSCRIPTION_ID" >/dev/null

if [[ "$ACTION" == "create" ]]; then
  if (( ${#CONTAINER_NAME} < 3 || ${#CONTAINER_NAME} > 63 )); then
    echo "Error: container name must be 3-63 characters."
    exit 1
  fi

  if [[ ! "$CONTAINER_NAME" =~ ^[a-z0-9]+(-[a-z0-9]+)*$ ]]; then
    echo "Error: container name must contain lowercase letters, numbers, and single hyphens only."
    echo "It must start and end with a letter or number."
    exit 1
  fi

  STORAGE_ACCOUNT_PREFIX="$(sanitize_storage_prefix "$STORAGE_ACCOUNT_NAME")"

  if (( ${#STORAGE_ACCOUNT_PREFIX} < 3 )); then
    echo "Error: provided storage account name/prefix '$STORAGE_ACCOUNT_NAME' is invalid after sanitization."
    echo "Use at least 3 alphanumeric characters."
    exit 1
  fi

  RANDOM_SUFFIX_LENGTH=4
  MAX_PREFIX_LENGTH=$(( 24 - RANDOM_SUFFIX_LENGTH ))

  if (( ${#STORAGE_ACCOUNT_PREFIX} > MAX_PREFIX_LENGTH )); then
    STORAGE_ACCOUNT_PREFIX="${STORAGE_ACCOUNT_PREFIX:0:$MAX_PREFIX_LENGTH}"
  fi

  echo "Creating or updating resource group '$RESOURCE_GROUP_NAME' in '$LOCATION'..."
  az group create \
    --name "$RESOURCE_GROUP_NAME" \
    --subscription "$SUBSCRIPTION_ID" \
    --location "$LOCATION" \
    --tags managed_by=azure-devops purpose=tfstate >/dev/null

  STORAGE_PROVIDER_STATE="$(az provider show \
    --namespace Microsoft.Storage \
    --subscription "$SUBSCRIPTION_ID" \
    --query registrationState \
    --output tsv || true)"

  if [[ "$STORAGE_PROVIDER_STATE" != "Registered" ]]; then
    echo "Registering Microsoft.Storage resource provider..."
    az provider register \
      --namespace Microsoft.Storage \
      --subscription "$SUBSCRIPTION_ID" \
      --wait >/dev/null
  fi

  EFFECTIVE_STORAGE_ACCOUNT_NAME=""

  EXISTING_STORAGE_ACCOUNT_NAME="$(az storage account show \
    --name "$STORAGE_ACCOUNT_PREFIX" \
    --resource-group "$RESOURCE_GROUP_NAME" \
    --subscription "$SUBSCRIPTION_ID" \
    --query name \
    --output tsv 2>/dev/null || true)"

  if [[ -n "$EXISTING_STORAGE_ACCOUNT_NAME" ]]; then
    EFFECTIVE_STORAGE_ACCOUNT_NAME="$EXISTING_STORAGE_ACCOUNT_NAME"
    echo "Reusing existing storage account '$EFFECTIVE_STORAGE_ACCOUNT_NAME'."
  fi

  if [[ -z "$EFFECTIVE_STORAGE_ACCOUNT_NAME" ]]; then
    for _ in 1 2 3 4 5 6 7 8; do
      CANDIDATE_NAME="${STORAGE_ACCOUNT_PREFIX}$(generate_random_suffix "$RANDOM_SUFFIX_LENGTH")"
      echo "Trying storage account name '$CANDIDATE_NAME'..."

      set +e
      CREATE_OUTPUT="$(az storage account create \
        --name "$CANDIDATE_NAME" \
        --resource-group "$RESOURCE_GROUP_NAME" \
        --subscription "$SUBSCRIPTION_ID" \
        --location "$LOCATION" \
        --sku Standard_LRS \
        --kind StorageV2 \
        --min-tls-version TLS1_2 \
        --allow-blob-public-access false \
        --https-only true 2>&1)"
      CREATE_EXIT_CODE=$?
      set -e

      if [[ "$CREATE_EXIT_CODE" -eq 0 ]]; then
        EFFECTIVE_STORAGE_ACCOUNT_NAME="$CANDIDATE_NAME"
        break
      fi

      if echo "$CREATE_OUTPUT" | grep -qiE "StorageAccountAlreadyTaken|StorageAccountAlreadyExists|already taken|already in use"; then
        echo "Storage account name '$CANDIDATE_NAME' is unavailable. Trying another suffix..."
        continue
      fi

      echo "Error: failed to create storage account '$CANDIDATE_NAME'."
      echo "$CREATE_OUTPUT"
      echo "If this shows SubscriptionNotFound, the service connection identity still lacks valid access to subscription '$SUBSCRIPTION_ID'."
      exit "$CREATE_EXIT_CODE"
    done
  fi

  if [[ -z "$EFFECTIVE_STORAGE_ACCOUNT_NAME" ]]; then
    echo "Error: could not find an available storage account name for prefix '$STORAGE_ACCOUNT_PREFIX'."
    exit 1
  fi

  if [[ "$EFFECTIVE_STORAGE_ACCOUNT_NAME" == "$STORAGE_ACCOUNT_PREFIX" ]]; then
    echo "Storage account prefix '$STORAGE_ACCOUNT_PREFIX' resolved to existing account '$EFFECTIVE_STORAGE_ACCOUNT_NAME'."
  else
    echo "Storage account prefix '$STORAGE_ACCOUNT_PREFIX' resolved to '$EFFECTIVE_STORAGE_ACCOUNT_NAME'."
    echo "Storage account '$EFFECTIVE_STORAGE_ACCOUNT_NAME' created."
  fi

  echo "Creating tfstate container '$CONTAINER_NAME'..."
  ACCOUNT_KEY="$(az storage account keys list \
    --resource-group "$RESOURCE_GROUP_NAME" \
    --account-name "$EFFECTIVE_STORAGE_ACCOUNT_NAME" \
    --subscription "$SUBSCRIPTION_ID" \
    --query "[0].value" \
    --output tsv)"

  az storage container create \
    --name "$CONTAINER_NAME" \
    --account-name "$EFFECTIVE_STORAGE_ACCOUNT_NAME" \
    --account-key "$ACCOUNT_KEY" \
    --public-access off >/dev/null

  STORAGE_ACCOUNT_ID="$(az storage account show \
    --name "$EFFECTIVE_STORAGE_ACCOUNT_NAME" \
    --resource-group "$RESOURCE_GROUP_NAME" \
    --subscription "$SUBSCRIPTION_ID" \
    --query id \
    --output tsv)"

  EXISTING_ROLE_ASSIGNMENT="$(az role assignment list \
    --assignee-object-id "$SERVICE_PRINCIPAL_OBJECT_ID" \
    --assignee-principal-type ServicePrincipal \
    --scope "$STORAGE_ACCOUNT_ID" \
    --role "Storage Blob Data Contributor" \
    --query '[0].id' \
    --output tsv 2>/dev/null || true)"

  if [[ -z "$EXISTING_ROLE_ASSIGNMENT" ]]; then
    echo "Granting Storage Blob Data Contributor on the tfstate storage account to the current service principal..."
    az role assignment create \
      --assignee-object-id "$SERVICE_PRINCIPAL_OBJECT_ID" \
      --assignee-principal-type ServicePrincipal \
      --role "Storage Blob Data Contributor" \
      --scope "$STORAGE_ACCOUNT_ID" >/dev/null
  else
    echo "Storage Blob Data Contributor is already assigned for the current service principal."
  fi

  echo "Bootstrap create complete."
  echo ""
  echo "Set these Azure DevOps pipeline variables:"
  echo "  TF_STATE_RESOURCE_GROUP=$RESOURCE_GROUP_NAME"
  echo "  TF_STATE_STORAGE_ACCOUNT=$EFFECTIVE_STORAGE_ACCOUNT_NAME"
  echo "  TF_STATE_CONTAINER=$CONTAINER_NAME"

  echo ""
  echo "Example backend config values:"
  echo "  resource_group_name  = \"$RESOURCE_GROUP_NAME\""
  echo "  storage_account_name = \"$EFFECTIVE_STORAGE_ACCOUNT_NAME\""
  echo "  container_name       = \"$CONTAINER_NAME\""
  echo "  key                  = \"aks-dev.tfstate\""

  echo "TFSTATE_STORAGE_ACCOUNT_NAME=$EFFECTIVE_STORAGE_ACCOUNT_NAME"
fi

if [[ "$ACTION" == "destroy" ]]; then
  echo "Destroy mode selected."
  echo "Deleting backend resource group '$RESOURCE_GROUP_NAME' and all contained resources..."

  RG_EXISTS="$(az group exists --name "$RESOURCE_GROUP_NAME" --subscription "$SUBSCRIPTION_ID" --output tsv)"

  if [[ "$RG_EXISTS" == "false" ]]; then
    echo "Resource group '$RESOURCE_GROUP_NAME' does not exist. Nothing to destroy."
    exit 0
  fi

  az group delete --name "$RESOURCE_GROUP_NAME" --subscription "$SUBSCRIPTION_ID" --yes >/dev/null
  az group wait --deleted --name "$RESOURCE_GROUP_NAME" --subscription "$SUBSCRIPTION_ID" --interval 15 --timeout 3600

  echo "Bootstrap destroy complete. Backend resources cleaned up."
fi
