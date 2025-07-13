Set-StrictMode -Version Latest
$ErrorActionPreference = "Stop"

Write-Host "Building Lambda layers..." -ForegroundColor Green

$Layers = @("ocr", "qr", "common")
$BaseDir = Split-Path (Get-Location).Path -Parent
$BuildDir = "$BaseDir\.build\layers"

# Create build directory
if (!(Test-Path $BuildDir)) { 
    New-Item -Path $BuildDir -ItemType Directory -Force | Out-Null
    Write-Host "Created build directory: $BuildDir" -ForegroundColor Blue
}

foreach ($layer in $Layers) {
    Write-Host "Building layer: $layer" -ForegroundColor Yellow

    $LayerPath = "$BaseDir\layers\$layer"
    $RequirementsFile = "$LayerPath\requirements.txt"
    $PythonPath = "$LayerPath\python"
    $ZipFile = "$BuildDir\$layer.zip"
    $TempDir = "$BaseDir\layers_tmp\$layer"

    # Clean up previous builds
    if (Test-Path $TempDir) { 
        Remove-Item $TempDir -Recurse -Force 
        Write-Host "Cleaned temporary directory for $layer" -ForegroundColor Gray
    }
    if (Test-Path $ZipFile) { 
        Remove-Item $ZipFile -Force 
        Write-Host "Removed old zip file for $layer" -ForegroundColor Gray
    }

    # Create temporary directory
    New-Item -ItemType Directory -Path $TempDir -Force | Out-Null

    # Install dependencies if requirements.txt exists
    if (Test-Path $RequirementsFile) {
        Write-Host "📦 Installing Python dependencies for $layer..." -ForegroundColor Cyan
        
        try {
            # Try platform-specific install first
            & pip install -r $RequirementsFile -t $TempDir --no-deps --platform linux_x86_64 --only-binary=:all:
            if ($LASTEXITCODE -ne 0) {
                Write-Host "⚠️ Platform-specific install failed, trying fallback..." -ForegroundColor Yellow
                # Fallback: install without platform restrictions
                & pip install -r $RequirementsFile -t $TempDir
                if ($LASTEXITCODE -ne 0) {
                    throw "pip install failed for $layer"
                }
            }
            Write-Host "✅ Dependencies installed for $layer" -ForegroundColor Green
        }
        catch {
            Write-Host "❌ Failed to install dependencies for ${layer}: $($_)" -ForegroundColor Red
            continue
        }
    }

    # Copy Python utility files if they exist
    if (Test-Path $PythonPath) {
        Write-Host "Copying Python utilities for $layer..." -ForegroundColor Cyan
        Copy-Item "$PythonPath\*" -Destination $TempDir -Recurse -Force
        Write-Host "Python utilities copied for $layer" -ForegroundColor Green
    }

    # Create zip file
    try {
        Write-Host "Creating zip file for $layer..." -ForegroundColor Cyan

        $compressionArgs = @{
            Path = "$TempDir\*"
            DestinationPath = $ZipFile
            Force = $true
        }
        Compress-Archive @compressionArgs

        $zipSize = (Get-Item $ZipFile).Length / 1MB
        Write-Host "Created $layer.zip ($([math]::Round($zipSize, 2)) MB)" -ForegroundColor Green
    }
    catch {
        Write-Host "Failed to install dependencies for ${layer}: $($_)" -ForegroundColor Red
        continue
    }

    # Clean up temp directory
    Remove-Item $TempDir -Recurse -Force
}

# Clean up all temp directories
$TempParentDir = "$BaseDir\layers_tmp"
if (Test-Path $TempParentDir) {
    Remove-Item $TempParentDir -Recurse -Force
    Write-Host "Cleaned up temporary directories" -ForegroundColor Gray
}

Write-Host "Layer build completed successfully!" -ForegroundColor Green
Write-Host "Built layers are available in: $BuildDir" -ForegroundColor Blue
