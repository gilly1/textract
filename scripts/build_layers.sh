#!/bin/bash

# AWS Document Processing Pipeline - Layer Build Script for Linux/macOS

set -e

echo "🚀 Building Lambda layers..."

LAYERS=("ocr" "qr" "pdf" "common")
BASE_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
BUILD_DIR="$BASE_DIR/.build/layers"

# Create build directory
if [ ! -d "$BUILD_DIR" ]; then
    mkdir -p "$BUILD_DIR"
    echo "📁 Created build directory: $BUILD_DIR"
fi

for layer in "${LAYERS[@]}"; do
    echo "🔨 Building layer: $layer"
    
    LAYER_PATH="$BASE_DIR/layers/$layer"
    REQUIREMENTS_FILE="$LAYER_PATH/requirements.txt"
    PYTHON_PATH="$LAYER_PATH/python"
    ZIP_FILE="$BUILD_DIR/$layer.zip"
    TEMP_DIR="$BASE_DIR/layers_tmp/$layer"

    # Clean up previous builds
    if [ -d "$TEMP_DIR" ]; then
        rm -rf "$TEMP_DIR"
        echo "🧹 Cleaned temporary directory for $layer"
    fi
    if [ -f "$ZIP_FILE" ]; then
        rm -f "$ZIP_FILE"
        echo "🧹 Removed old zip file for $layer"
    fi

    # Create temporary directory
    mkdir -p "$TEMP_DIR"

    # Install dependencies if requirements.txt exists
    if [ -f "$REQUIREMENTS_FILE" ]; then
        echo "📦 Installing Python dependencies for $layer..."
        
        if command -v pip3 >/dev/null 2>&1; then
            PIP_CMD="pip3"
        elif command -v pip >/dev/null 2>&1; then
            PIP_CMD="pip"
        else
            echo "❌ pip not found. Please install Python and pip"
            exit 1
        fi
        
        # Install for Linux x86_64 platform
        if ! $PIP_CMD install -r "$REQUIREMENTS_FILE" -t "$TEMP_DIR" \
            --no-deps --platform linux_x86_64 --only-binary=:all: 2>/dev/null; then
            # Fallback: install without platform restrictions
            echo "⚠️ Platform-specific install failed, trying fallback..."
            $PIP_CMD install -r "$REQUIREMENTS_FILE" -t "$TEMP_DIR"
        fi
        echo "✅ Dependencies installed for $layer"
    fi
    
    # Copy Python utility files if they exist
    if [ -d "$PYTHON_PATH" ]; then
        echo "📋 Copying Python utilities for $layer..."
        cp -r "$PYTHON_PATH"/* "$TEMP_DIR"/
        echo "✅ Python utilities copied for $layer"
    fi

    # Create zip file
    echo "📦 Creating zip file for $layer..."
    
    # Change to temp directory to avoid including path in zip
    cd "$TEMP_DIR"
    
    if command -v zip >/dev/null 2>&1; then
        zip -r "$ZIP_FILE" . >/dev/null 2>&1
    else
        # Fallback using Python zipfile
        python3 -c "
import zipfile
import os
with zipfile.ZipFile('$ZIP_FILE', 'w', zipfile.ZIP_DEFLATED) as zf:
    for root, dirs, files in os.walk('.'):
        for file in files:
            zf.write(os.path.join(root, file))
"
    fi
    
    cd "$BASE_DIR"
    
    ZIP_SIZE=$(du -h "$ZIP_FILE" | cut -f1)
    echo "✅ Created $layer.zip ($ZIP_SIZE)"

    # Clean up temp directory
    rm -rf "$TEMP_DIR"
done

# Clean up all temp directories
TEMP_PARENT_DIR="$BASE_DIR/layers_tmp"
if [ -d "$TEMP_PARENT_DIR" ]; then
    rm -rf "$TEMP_PARENT_DIR"
    echo "🧹 Cleaned up temporary directories"
fi

echo "🎉 Layer build completed successfully!"
echo "📍 Built layers are available in: $BUILD_DIR"
