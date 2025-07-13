# Cleanup Script for AWS Document Processing Pipeline

param(
    [switch]$Force,
    [string]$Region = "us-east-1",
    [string]$ProjectName = "document-processor"
)

$ErrorActionPreference = "Stop"

Write-Host "Starting cleanup of AWS Document Processing Pipeline..." -ForegroundColor Yellow
Write-Host "Region: $Region" -ForegroundColor Blue
Write-Host "Project: $ProjectName" -ForegroundColor Blue

if (!$Force) {
    $confirmation = Read-Host "This will destroy ALL infrastructure. Type 'yes' to continue"
    if ($confirmation -ne "yes") {
        Write-Host "Cleanup cancelled" -ForegroundColor Red
        exit 0
    }
}

# Check if we're in the right directory
if (!(Test-Path "README.md")) {
    Write-Host "Please run this script from the project root directory" -ForegroundColor Red
    exit 1
}

# Destroy with Terraform
Write-Host "Destroying infrastructure with Terraform..." -ForegroundColor Yellow
Set-Location terraform

try {
    # Set environment variables
    $env:TF_VAR_aws_region = $Region
    $env:TF_VAR_project_name = $ProjectName

    # Destroy infrastructure
    Write-Host "Destroying infrastructure..." -ForegroundColor Red
    terraform destroy -auto-approve

    Write-Host "Infrastructure destroyed successfully!" -ForegroundColor Green
}
catch {
    Write-Host "Terraform destroy failed: $_" -ForegroundColor Red
    Write-Host "You may need to manually clean up some resources in the AWS console" -ForegroundColor Yellow
    exit 1
}
finally {
    Set-Location ..
}

# Clean up local build artifacts
Write-Host "Cleaning up local build artifacts..." -ForegroundColor Yellow

$artifactPaths = @(".build", "layers_tmp", "terraform\.terraform", "terraform\*.tfstate*", "terraform\tfplan")

foreach ($path in $artifactPaths) {
    if (Test-Path $path) {
        Remove-Item $path -Recurse -Force
        Write-Host "Removed: $path" -ForegroundColor Gray
    }
}

Write-Host "Cleanup completed!" -ForegroundColor Green
