# Verification script to check project structure

Write-Host "🔍 Verifying project structure..." -ForegroundColor Green

$requiredFiles = @(
    ".build\layers\common.zip",
    ".build\layers\ocr.zip", 
    ".build\layers\qr.zip",
    "lambdas\convert_to_image\app.py",
    "lambdas\qr_scanner\app.py",
    "lambdas\ocr_text\app.py",
    "lambdas\validator\app.py",
    "terraform\main.tf",
    "terraform\variables.tf",
    "terraform\outputs.tf"
)

$allGood = $true

foreach ($file in $requiredFiles) {
    if (Test-Path $file) {
        Write-Host "✅ $file" -ForegroundColor Green
    } else {
        Write-Host "❌ $file" -ForegroundColor Red
        $allGood = $false
    }
}

if ($allGood) {
    Write-Host "🎉 All required files present!" -ForegroundColor Green
} else {
    Write-Host "⚠️ Some files are missing" -ForegroundColor Yellow
}

# Check AWS CLI
try {
    $awsIdentity = aws sts get-caller-identity --output json 2>$null | ConvertFrom-Json
    Write-Host "✅ AWS CLI configured for account: $($awsIdentity.Account)" -ForegroundColor Green
} catch {
    Write-Host "❌ AWS CLI not configured or no permissions" -ForegroundColor Red
}

# Check Terraform
try {
    $tfVersion = terraform version -json 2>$null | ConvertFrom-Json
    Write-Host "✅ Terraform version: $($tfVersion.terraform_version)" -ForegroundColor Green
} catch {
    Write-Host "❌ Terraform not installed or not in PATH" -ForegroundColor Red
}
