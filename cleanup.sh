#!/bin/bash

# WARNING: This script is DESTRUCTIVE and will attempt to delete AWS resources
# including ECR images, Terraform-managed infrastructure, the S3 state bucket,
# and the DynamoDB lock table. Review carefully before running.
# MANUAL CONFIRMATION IS STILL REQUIRED for terraform destroy.

# --- Configuration ---
# These values are expected as command-line arguments:
# $1: Terraform State S3 Bucket Name
# $2: Terraform Lock DynamoDB Table Name
ARG_STATE_BUCKET="$1"
ARG_LOCK_TABLE="$2"

# These can remain here or be parameterized further if needed
PROJECT_NAME="vaultllm"
AWS_REGION="ap-northeast-1" # Ensure this matches your deployment region

OLLAMA_REPO="${PROJECT_NAME}/ollama"
WEBUI_REPO="${PROJECT_NAME}/open-webui"

# --- Argument and Safety Checks ---
# Check if required arguments are provided
if [[ -z "$ARG_STATE_BUCKET" || -z "$ARG_LOCK_TABLE" ]]; then
  echo "ERROR: Missing required arguments."
  echo "Usage: $0 <state_bucket_name> <lock_table_name>"
  echo "Example: $0 vaultllm-tfstate-xxxx-yyy vaultllm-tfstate-lock"
  exit 1
fi

# Confirm execution using the passed arguments
read -p "This script will target BUCKET: [$ARG_STATE_BUCKET] and TABLE: [$ARG_LOCK_TABLE] for DELETION after terraform destroy. Are you absolutely sure? (yes/N): " confirm
if [[ "$confirm" != "yes" ]]; then
    echo "Aborted."
    exit 0
fi


echo "### Starting VaultLLM Cleanup for Bucket: ${ARG_STATE_BUCKET}, Table: ${ARG_LOCK_TABLE} ###"

# 1. Delete ECR Images
echo "--- Deleting ECR Images for ${OLLAMA_REPO} ---"
ollama_images=$(aws ecr list-images --repository-name "${OLLAMA_REPO}" --region "${AWS_REGION}" --query 'imageIds[*]' --output json 2>/dev/null)
if [ $? -eq 0 ] && [ -n "$ollama_images" ] && [ "$ollama_images" != "[]" ]; then
    echo "Found images in ${OLLAMA_REPO}, attempting deletion..."
    aws ecr batch-delete-image --repository-name "${OLLAMA_REPO}" --region "${AWS_REGION}" --image-ids "$ollama_images" || echo "WARN: Failed to delete some Ollama images. Manual cleanup might be needed."
else
    echo "No images found or error listing images in ${OLLAMA_REPO}."
fi

echo "--- Deleting ECR Images for ${WEBUI_REPO} ---"
webui_images=$(aws ecr list-images --repository-name "${WEBUI_REPO}" --region "${AWS_REGION}" --query 'imageIds[*]' --output json 2>/dev/null)
if [ $? -eq 0 ] && [ -n "$webui_images" ] && [ "$webui_images" != "[]" ]; then
    echo "Found images in ${WEBUI_REPO}, attempting deletion..."
    aws ecr batch-delete-image --repository-name "${WEBUI_REPO}" --region "${AWS_REGION}" --image-ids "$webui_images" || echo "WARN: Failed to delete some WebUI images. Manual cleanup might be needed."
else
    echo "No images found or error listing images in ${WEBUI_REPO}."
fi
echo "ECR Image Deletion Attempted."
echo "Waiting a few seconds for ECR changes to propagate..."
sleep 5

# 2. Destroy Terraform Resources (Requires Manual 'yes' Confirmation)
echo "--- Running Terraform Destroy (Requires 'yes' confirmation) ---"
# Initialize with backend config first (pass bucket/table via CLI or use backend.conf)
# Using backend.conf is simpler if the file exists
if [ -f "backend.conf" ]; then
    echo "Initializing with backend.conf..."
    # Optional check (uncomment if needed):
    # grep "bucket *= *\"${ARG_STATE_BUCKET}\"" backend.conf > /dev/null || echo "WARN: backend.conf bucket may not match argument $ARG_STATE_BUCKET"
    # grep "dynamodb_table *= *\"${ARG_LOCK_TABLE}\"" backend.conf > /dev/null || echo "WARN: backend.conf table may not match argument $ARG_LOCK_TABLE"
    terraform init -backend-config=backend.conf
else
    echo "backend.conf not found. Initializing with CLI arguments..."
    terraform init \
        -backend-config="bucket=${ARG_STATE_BUCKET}" \
        -backend-config="key=${PROJECT_NAME}/root/terraform.tfstate" \
        -backend-config="region=${AWS_REGION}" \
        -backend-config="dynamodb_table=${ARG_LOCK_TABLE}" \
        -backend-config="encrypt=true"
fi
# Check init status before proceeding
if [ $? -ne 0 ]; then
  echo "ERROR: Terraform init failed. Aborting destroy."
  exit 1
fi

# Run destroy using the tfvars file
echo "Running destroy with terraform.tfvars..."
terraform destroy -var-file=terraform.tfvars

# Check if destroy was successful
destroy_status=$?
if [ $destroy_status -ne 0 ]; then
  echo "ERROR: Terraform destroy failed with status ${destroy_status}."
  echo "MANUAL CLEANUP REQUIRED for remaining resources AND the S3 state bucket/DynamoDB lock table."
  echo "Skipping automatic backend resource deletion."
  exit 1
fi
echo "Terraform destroy completed successfully."

# 3. Delete S3 Bucket (Automated, using the argument)
echo "--- Deleting State S3 Bucket: ${ARG_STATE_BUCKET} ---"
echo "WARNING: Deleting the state bucket. This is irreversible."
aws s3 rb "s3://${ARG_STATE_BUCKET}" --force
if [ $? -ne 0 ]; then
    echo "WARN: Failed to delete S3 bucket ${ARG_STATE_BUCKET}. Manual deletion required."
else
    echo "S3 Bucket Deletion Attempted."
fi

# 4. Delete DynamoDB Table (Automated, using the argument)
echo "--- Deleting Lock DynamoDB Table: ${ARG_LOCK_TABLE} ---"
aws dynamodb delete-table --table-name "${ARG_LOCK_TABLE}" --region "${AWS_REGION}"
if [ $? -ne 0 ]; then
    echo "WARN: Failed to delete DynamoDB table ${ARG_LOCK_TABLE}. Manual deletion required."
else
    echo "DynamoDB Table Deletion Attempted."
fi

# 5. Manual Reminder
echo ""
echo "----------------------------------"
echo "----- MANUAL ACTION REQUIRED -----"
echo "----------------------------------"
echo "-> Log in to your domain registrar (e.g., Oname, Google Domains) and UPDATE/REMOVE the NS records for hashiiiii.com pointing to AWS Route 53."
echo "-> Double-check AWS Console for any remaining resources (e.g., failed deletions, logs with retention)."
echo "### Cleanup Script Finished ###"
