# AWS Document Processing Pipeline - Simple Deployment Script

param(
    [switch]$SkipBuild,
    [switch]$PlanOnly
)

$ErrorActionPreference = "Stop"

Write-Host "Starting deployment..." -ForegroundColor Green

# Check directory
if (!(Test-Path "README.md")) {
    Write-Host "Run from project root directory" -ForegroundColor Red
    exit 1
}

# Build layers
if (!$SkipBuild) {
    Write-Host "Building layers..." -ForegroundColor Yellow
    Set-Location scripts
    try {
        .\build_layers.ps1
        Write-Host "Layers built successfully" -ForegroundColor Green
    }
    catch {
        Write-Host "Layer build failed: $_" -ForegroundColor Red
        exit 1
    }
    Set-Location ..
}

# Deploy infrastructure
Write-Host "Deploying infrastructure..." -ForegroundColor Yellow
Set-Location terraform

try {
    # Initialize
    Write-Host "Initializing Terraform..." -ForegroundColor Cyan
    terraform init

    # Plan
    Write-Host "Running Terraform plan..." -ForegroundColor Cyan
    terraform plan -out=tfplan

    if ($PlanOnly) {
        Write-Host "Plan complete. Review above." -ForegroundColor Blue
    } else {
        # Apply
        Write-Host "Applying infrastructure changes..." -ForegroundColor Cyan
        terraform apply tfplan

        Write-Host "Deployment completed successfully!" -ForegroundColor Green
        terraform output
    }
}
catch {
    Write-Host "Deployment failed: $_" -ForegroundColor Red
    exit 1
}
finally {
    Set-Location ..
}

Write-Host "Done." -ForegroundColor Green
