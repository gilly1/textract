#!/bin/bash

# Cleanup Script for AWS Document Processing Pipeline - Linux/macOS version

set -e

# Default values
FORCE=false
REGION="us-east-1"
PROJECT_NAME="document-processor"

# Parse command line arguments
while [[ $# -gt 0 ]]; do
    case $1 in
        --force)
            FORCE=true
            shift
            ;;
        --region)
            REGION="$2"
            shift 2
            ;;
        --project-name)
            PROJECT_NAME="$2"
            shift 2
            ;;
        -h|--help)
            echo "Usage: $0 [OPTIONS]"
            echo "Options:"
            echo "  --force           Skip confirmation prompt"
            echo "  --region REGION   AWS region (default: us-east-1)"
            echo "  --project-name NAME Project name (default: document-processor)"
            echo "  -h, --help        Show this help message"
            exit 0
            ;;
        *)
            echo "Unknown option: $1"
            exit 1
            ;;
    esac
done

echo "🧹 Starting cleanup of AWS Document Processing Pipeline..."
echo "📍 Region: $REGION"
echo "📍 Project: $PROJECT_NAME"

if [ "$FORCE" = false ]; then
    echo "⚠️ This will destroy ALL infrastructure."
    read -p "Type 'yes' to continue: " confirmation
    if [ "$confirmation" != "yes" ]; then
        echo "❌ Cleanup cancelled"
        exit 0
    fi
fi

# Check if we're in the right directory
if [ ! -f "README.md" ]; then
    echo "❌ Please run this script from the project root directory"
    exit 1
fi

# Destroy with Terraform
echo "🏗️ Destroying infrastructure with Terraform..."
cd terraform

# Set environment variables
export TF_VAR_aws_region="$REGION"
export TF_VAR_project_name="$PROJECT_NAME"

# Destroy infrastructure
echo "💥 Destroying infrastructure..."
if terraform destroy -auto-approve; then
    echo "✅ Infrastructure destroyed successfully!"
else
    echo "❌ Terraform destroy failed"
    echo "You may need to manually clean up some resources in the AWS console"
    exit 1
fi

cd ..

# Clean up local build artifacts
echo "🧹 Cleaning up local build artifacts..."

ARTIFACT_PATHS=(
    ".build"
    "layers_tmp"
    "terraform/.terraform"
    "terraform/*.tfstate*"
    "terraform/tfplan"
)

for path in "${ARTIFACT_PATHS[@]}"; do
    if [ -e "$path" ] || [ -L "$path" ]; then
        rm -rf $path 2>/dev/null || true
        echo "🗑️ Removed: $path"
    fi
done

echo "🎉 Cleanup completed!"
