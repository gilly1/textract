#!/usr/bin/env powershell
<#
.SYNOPSIS
    Insert a test record into DynamoDB to trigger the Step Function
.DESCRIPTION
    This script inserts a record into the DynamoDB table that will trigger
    the document processing pipeline via DynamoDB Streams.
#>

param(
    [string]$FileName = "invoice.pdf",
    [string]$BucketName = "",
    [string]$TableName = ""
)

Set-StrictMode -Version Latest
$ErrorActionPreference = "Stop"

Write-Host "🚀 Inserting test record into DynamoDB..." -ForegroundColor Green

# Get the outputs from Terraform if not provided
if ([string]::IsNullOrEmpty($BucketName) -or [string]::IsNullOrEmpty($TableName)) {
    Write-Host "📋 Getting Terraform outputs..." -ForegroundColor Cyan
    
    $terraformDir = Split-Path (Get-Location).Path -Parent
    $terraformDir = Join-Path $terraformDir "terraform"
    
    try {
        Push-Location $terraformDir
        
        if ([string]::IsNullOrEmpty($BucketName)) {
            $BucketName = (terraform output -raw s3_bucket_name)
            Write-Host "S3 Bucket: $BucketName" -ForegroundColor Blue
        }
        
        if ([string]::IsNullOrEmpty($TableName)) {
            $TableName = (terraform output -raw dynamodb_table_name)
            Write-Host "DynamoDB Table: $TableName" -ForegroundColor Blue
        }
    }
    catch {
        Write-Host "❌ Failed to get Terraform outputs: $($_)" -ForegroundColor Red
        Write-Host "Please ensure you're in the project directory and Terraform has been applied." -ForegroundColor Yellow
        exit 1
    }
    finally {
        Pop-Location
    }
}

# Generate a unique document ID
$documentId = "doc-$(Get-Date -Format 'yyyyMMdd-HHmmss')-$([System.Guid]::NewGuid().ToString().Substring(0,8))"
$currentDate = Get-Date -Format "yyyy-MM-ddTHH:mm:ssZ"

# Prepare the DynamoDB item
$dynamoItem = @{
    document_id = @{ S = $documentId }
    bucket = @{ S = $BucketName }
    key = @{ S = "uploads/$FileName" }
    status = @{ S = "pending" }
    upload_date = @{ S = $currentDate }
    processed_date = @{ S = $currentDate }
    file_type = @{ S = "pdf" }
    source = @{ S = "manual_trigger" }
} | ConvertTo-Json -Depth 3

Write-Host "📝 Inserting record with details:" -ForegroundColor Cyan
Write-Host "  Document ID: $documentId" -ForegroundColor White
Write-Host "  Bucket: $BucketName" -ForegroundColor White
Write-Host "  Key: uploads/$FileName" -ForegroundColor White
Write-Host "  Status: pending" -ForegroundColor White

try {
    # Insert the item into DynamoDB
    aws dynamodb put-item `
        --table-name $TableName `
        --item $dynamoItem `
        --return-consumed-capacity TOTAL | Out-Null

    if ($LASTEXITCODE -eq 0) {
        Write-Host "✅ Successfully inserted record into DynamoDB!" -ForegroundColor Green
        Write-Host "📊 This should trigger the Step Function automatically via DynamoDB Streams" -ForegroundColor Cyan
        
        # Show the inserted item
        Write-Host "`n📋 Inserted record:" -ForegroundColor Yellow
        $getItemResult = aws dynamodb get-item `
            --table-name $TableName `
            --key "{`"document_id`": {`"S`": `"$documentId`"}}"
        
        if ($LASTEXITCODE -eq 0) {
            $getItemResult | ConvertFrom-Json | ConvertTo-Json -Depth 4
        }
        
        Write-Host "`n🔍 You can monitor the execution with:" -ForegroundColor Cyan
        Write-Host "  aws stepfunctions list-executions --state-machine-arn `"$(terraform output -raw step_function_arn)`"" -ForegroundColor White
        
        Write-Host "`n📊 Check DynamoDB for processing results:" -ForegroundColor Cyan
        Write-Host "  aws dynamodb scan --table-name `"$TableName`"" -ForegroundColor White
    }
    else {
        Write-Host "❌ Failed to insert record into DynamoDB" -ForegroundColor Red
        exit 1
    }
}
catch {
    Write-Host "❌ Error inserting record: $($_)" -ForegroundColor Red
    Write-Host "Please ensure:" -ForegroundColor Yellow
    Write-Host "  1. AWS CLI is configured with proper credentials" -ForegroundColor Yellow
    Write-Host "  2. You have permissions to write to the DynamoDB table" -ForegroundColor Yellow
    Write-Host "  3. The table name is correct: $TableName" -ForegroundColor Yellow
    exit 1
}

Write-Host "`n🎉 Test record insertion completed!" -ForegroundColor Green
