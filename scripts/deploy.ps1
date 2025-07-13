param(
    [switch]$SkipBuild,
    [switch]$PlanOnly,
    [string]$Region = "us-east-1",
    [string]$ProjectName = "document-processor"
)

$ErrorActionPreference = "Stop"

Write-Host "Starting deployment..." -ForegroundColor Green
Write-Host "Region: $Region" -ForegroundColor Blue
Write-Host "Project: $ProjectName" -ForegroundColor Blue

# Ensure script is run from project root
if (!(Test-Path "README.md")) {
    Write-Host "Run this script from the project root directory." -ForegroundColor Red
    exit 1
}

# Step 1: Build Lambda Layers (if not skipped)
if (-not $SkipBuild) {
    Write-Host "Building Lambda layers..." -ForegroundColor Yellow
    Push-Location scripts
    try {
        .\build_layers.ps1
        Write-Host "Layers built successfully." -ForegroundColor Green
    }
    catch {
        Write-Host "Layer build failed: $_" -ForegroundColor Red
        Pop-Location
        exit 1
    }
    Pop-Location
}

# Step 2: Deploy Infrastructure with Terraform
Write-Host "Deploying infrastructure with Terraform..." -ForegroundColor Yellow
Push-Location terraform

try {
    $env:TF_VAR_aws_region = $Region
    $env:TF_VAR_project_name = $ProjectName

    Write-Host "Initializing Terraform..." -ForegroundColor Cyan
    terraform init

    Write-Host "Running Terraform plan..." -ForegroundColor Cyan
    terraform plan -out=tfplan

    if ($PlanOnly) {
        Write-Host "Terraform plan complete. No changes applied." -ForegroundColor Blue
    }
    else {
        Write-Host "Applying Terraform changes..." -ForegroundColor Cyan
        terraform apply tfplan

        Write-Host "Deployment completed successfully." -ForegroundColor Green

        # Display outputs
        terraform output

        # Show next actions
        Write-Host ""
        Write-Host "Next steps:" -ForegroundColor Yellow
        Write-Host "1. Note the S3 bucket name above." -ForegroundColor White
        Write-Host "2. Upload PDF to the uploads/ prefix." -ForegroundColor White
        Write-Host "3. Check Step Functions console for progress." -ForegroundColor White
        Write-Host "4. View processed results in DynamoDB." -ForegroundColor White
    }
}
catch {
    Write-Host "Deployment failed: $_" -ForegroundColor Red
    exit 1
}
finally {
    Pop-Location
}

Write-Host "Done!" -ForegroundColor Green
