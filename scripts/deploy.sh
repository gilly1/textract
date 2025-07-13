#!/bin/bash

# AWS Document Processing Pipeline Deployment Script

set -e

echo "🚀 Starting deployment of AWS Document Processing Pipeline..."

# Check if we're in the right directory
if [ ! -f "README.md" ]; then
    echo "❌ Please run this script from the project root directory"
    exit 1
fi

# Build Lambda layers
echo "🔨 Building Lambda layers..."
cd scripts
if [[ "$OSTYPE" == "msys" || "$OSTYPE" == "win32" ]]; then
    powershell.exe -ExecutionPolicy Bypass -File build_layers.ps1
else
    echo "❌ This deployment script is currently configured for Windows PowerShell"
    echo "Please run the build_layers.ps1 script manually and then continue with Terraform"
    exit 1
fi
cd ..

# Deploy with Terraform
echo "🏗️ Deploying infrastructure with Terraform..."
cd terraform

# Initialize Terraform
echo "📋 Initializing Terraform..."
terraform init

# Plan deployment
echo "📊 Planning deployment..."
terraform plan

# Apply deployment
echo "🚀 Applying deployment..."
terraform apply -auto-approve

echo "✅ Deployment completed successfully!"
echo ""
echo "📍 Next steps:"
echo "1. Note the S3 bucket name from the output"
echo "2. Upload a PDF file to the 'uploads/' prefix in the bucket"
echo "3. Check the Step Function execution in AWS Console"
echo "4. View results in the DynamoDB table"
