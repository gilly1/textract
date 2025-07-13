#!/bin/bash
set -e

# Insert a test record into DynamoDB to trigger the Step Function
# This script inserts a record into the DynamoDB table that will trigger
# the document processing pipeline via DynamoDB Streams.

FILE_NAME="${1:-invoice.pdf}"
BUCKET_NAME="${2:-}"
TABLE_NAME="${3:-}"

echo "🚀 Inserting test record into DynamoDB..."

# Get the outputs from Terraform if not provided
if [[ -z "$BUCKET_NAME" ]] || [[ -z "$TABLE_NAME" ]]; then
    echo "📋 Getting Terraform outputs..."
    
    TERRAFORM_DIR="$(dirname "$(pwd)")/terraform"
    
    if [[ -z "$BUCKET_NAME" ]]; then
        BUCKET_NAME=$(cd "$TERRAFORM_DIR" && terraform output -raw s3_bucket_name)
        echo "S3 Bucket: $BUCKET_NAME"
    fi
    
    if [[ -z "$TABLE_NAME" ]]; then
        TABLE_NAME=$(cd "$TERRAFORM_DIR" && terraform output -raw dynamodb_table_name)
        echo "DynamoDB Table: $TABLE_NAME"
    fi
fi

# Generate a unique document ID
DOCUMENT_ID="doc-$(date +%Y%m%d-%H%M%S)-$(uuidgen | cut -c1-8 | tr '[:upper:]' '[:lower:]')"
CURRENT_DATE=$(date -u +"%Y-%m-%dT%H:%M:%SZ")

# Prepare the DynamoDB item
DYNAMO_ITEM=$(cat <<EOF
{
    "document_id": {"S": "$DOCUMENT_ID"},
    "bucket": {"S": "$BUCKET_NAME"},
    "key": {"S": "uploads/$FILE_NAME"},
    "status": {"S": "pending"},
    "upload_date": {"S": "$CURRENT_DATE"},
    "processed_date": {"S": "$CURRENT_DATE"},
    "file_type": {"S": "pdf"},
    "source": {"S": "manual_trigger"}
}
EOF
)

echo "📝 Inserting record with details:"
echo "  Document ID: $DOCUMENT_ID"
echo "  Bucket: $BUCKET_NAME"
echo "  Key: uploads/$FILE_NAME"
echo "  Status: pending"

# Insert the item into DynamoDB
if aws dynamodb put-item \
    --table-name "$TABLE_NAME" \
    --item "$DYNAMO_ITEM" \
    --return-consumed-capacity TOTAL > /dev/null; then
    
    echo "✅ Successfully inserted record into DynamoDB!"
    echo "📊 This should trigger the Step Function automatically via DynamoDB Streams"
    
    # Show the inserted item
    echo ""
    echo "📋 Inserted record:"
    aws dynamodb get-item \
        --table-name "$TABLE_NAME" \
        --key "{\"document_id\": {\"S\": \"$DOCUMENT_ID\"}}" \
        --output json | jq '.'
    
    echo ""
    echo "🔍 You can monitor the execution with:"
    echo "  aws stepfunctions list-executions --state-machine-arn \"$(cd "$TERRAFORM_DIR" && terraform output -raw step_function_arn)\""
    
    echo ""
    echo "📊 Check DynamoDB for processing results:"
    echo "  aws dynamodb scan --table-name \"$TABLE_NAME\""
    
else
    echo "❌ Failed to insert record into DynamoDB"
    echo "Please ensure:"
    echo "  1. AWS CLI is configured with proper credentials"
    echo "  2. You have permissions to write to the DynamoDB table"
    echo "  3. The table name is correct: $TABLE_NAME"
    exit 1
fi

echo ""
echo "🎉 Test record insertion completed!"

