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
    rm -rf "$TEMP_DIR" "$ZIP_FILE"
    mkdir -p "$TEMP_DIR"
    echo "🧹 Cleaned previous build for $layer"

    # Install dependencies
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

        # Try platform-specific binary install first
        if ! $PIP_CMD install -r "$REQUIREMENTS_FILE" -t "$TEMP_DIR" \
            --platform manylinux2014_x86_64 \
            --implementation cp \
            --python-version 3.12 \
            --abi cp312 \
            --only-binary=:all:; then
            echo "⚠️ Binary-only install failed, trying fallback with source builds..."
            $PIP_CMD install -r "$REQUIREMENTS_FILE" -t "$TEMP_DIR"
        fi

        echo "📁 Contents of $TEMP_DIR after pip install:"
        ls -lah "$TEMP_DIR"
        
        # Fail fast if install did nothing
        if [ -z "$(ls -A "$TEMP_DIR")" ]; then
            echo "❌ ERROR: No files installed for $layer. Aborting."
            exit 1
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
    (
        cd "$TEMP_DIR"
        if command -v zip >/dev/null 2>&1; then
            zip -r "$ZIP_FILE" . >/dev/null 2>&1
        else
            python3 -c "
import zipfile, os
with zipfile.ZipFile('$ZIP_FILE', 'w', zipfile.ZIP_DEFLATED) as zf:
    for root, _, files in os.walk('.'):
        for f in files:
            full_path = os.path.join(root, f)
            zf.write(full_path, arcname=full_path)
"
        fi
    )

    ZIP_SIZE=$(du -h "$ZIP_FILE" | cut -f1)
    echo "✅ Created $layer.zip ($ZIP_SIZE)"

    # Clean up temp directory
    rm -rf "$TEMP_DIR"
done

# Clean up all temp directories
rm -rf "$BASE_DIR/layers_tmp"
echo "🧹 Cleaned up temporary directories"

echo "🎉 Layer build completed successfully!"
echo "📍 Built layers are available in: $BUILD_DIR"
