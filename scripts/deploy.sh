#!/bin/bash

# AWS Document Processing Pipeline - Deployment Script for Linux/macOS

set -e

# Default values
SKIP_BUILD=false
PLAN_ONLY=false
REGION="us-east-1"
PROJECT_NAME="document-processor"

# Parse command line arguments
while [[ $# -gt 0 ]]; do
    case $1 in
        --skip-build)
            SKIP_BUILD=true
            shift
            ;;
        --plan-only)
            PLAN_ONLY=true
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
            echo "  --skip-build      Skip building Lambda layers"
            echo "  --plan-only       Show plan without applying"
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

echo "🚀 Starting deployment..."
echo "📍 Region: $REGION"
echo "📍 Project: $PROJECT_NAME"

# Check if we're in the right directory
if [ ! -f "README.md" ]; then
    echo "❌ Please run this script from the project root directory"
    exit 1
fi

# Build Lambda layers (unless skipped)
if [ "$SKIP_BUILD" = false ]; then
    echo "🔨 Building layers..."
    cd scripts
    if [ -f "build_layers.sh" ]; then
        ./build_layers.sh
        echo "✅ Layers built"
    else
        echo "❌ build_layers.sh not found. Please create Linux version of layer builder"
        exit 1
    fi
    cd ..
else
    echo "⏭️ Skipping layer build"
fi

# Deploy with Terraform
echo "🏗️ Deploying infrastructure..."
cd terraform

# Set environment variables
export TF_VAR_aws_region="$REGION"
export TF_VAR_project_name="$PROJECT_NAME"

# Initialize Terraform
echo "📋 Initializing..."
terraform init

# Plan deployment
echo "📊 Planning..."
terraform plan -out=tfplan

if [ "$PLAN_ONLY" = true ]; then
    echo "📋 Plan complete"
else
    # Apply deployment
    echo "🚀 Applying..."
    terraform apply tfplan

    echo "✅ Deployment completed!"
    terraform output
    
    echo ""
    echo "📍 Next steps:"
    echo "1. Note the S3 bucket name above"
    echo "2. Upload PDF to uploads/ prefix"
    echo "3. Check Step Functions console"
    echo "4. View results in DynamoDB"
fi

cd ..
echo "🎉 Done!"
