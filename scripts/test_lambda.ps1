Set-StrictMode -Version Latest
$ErrorActionPreference = "Stop"

# Test individual Lambda functions
# Usage: .\test_lambda.ps1 -FunctionName <function_name> [-PayloadFile <payload_file>]

param(
    [Parameter(Position=0)]
    [string]$FunctionName = "convert_to_image",
    
    [Parameter(Position=1)]
    [string]$PayloadFile
)

if ([string]::IsNullOrEmpty($PayloadFile)) {
    $PayloadFile = "test_payloads\${FunctionName}_payload.json"
}

# Get the function name with project prefix
$ProjectPrefix = "document-processor"
$FullFunctionName = "${ProjectPrefix}-${FunctionName}"

Write-Host "🧪 Testing Lambda function: $FullFunctionName" -ForegroundColor Green
Write-Host "📄 Using payload file: $PayloadFile" -ForegroundColor Blue

if (!(Test-Path $PayloadFile)) {
    Write-Host "❌ Payload file not found: $PayloadFile" -ForegroundColor Red
    Write-Host "Available payload files:" -ForegroundColor Yellow
    Get-ChildItem "test_payloads\*.json" | Format-Table Name, Length, LastWriteTime
    exit 1
}

Write-Host ""
Write-Host "📋 Payload content:" -ForegroundColor Cyan
Get-Content $PayloadFile | ConvertFrom-Json | ConvertTo-Json -Depth 10

Write-Host ""
Write-Host "🚀 Invoking Lambda function..." -ForegroundColor Yellow

# Invoke the Lambda function
aws lambda invoke `
    --function-name $FullFunctionName `
    --payload "file://$PayloadFile" `
    --output json `
    response.json | Out-Null

Write-Host ""
Write-Host "📊 Lambda response:" -ForegroundColor Cyan
if (Test-Path "response.json") {
    $response = Get-Content "response.json" | ConvertFrom-Json
    $response | ConvertTo-Json -Depth 10
    
    Write-Host ""
    Write-Host "📄 Function output:" -ForegroundColor Magenta
    if ($response.Payload) {
        try {
            $payload = $response.Payload | ConvertFrom-Json
            $payload | ConvertTo-Json -Depth 10
        }
        catch {
            Write-Host $response.Payload
        }
    }
}

# Clean up
if (Test-Path "response.json") {
    Remove-Item "response.json" -Force
}

Write-Host ""
Write-Host "✅ Lambda test completed!" -ForegroundColor Green
