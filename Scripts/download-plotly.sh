#!/bin/bash

# Download Plotly.js Script for Curtain iOS App
# This script automatically downloads Plotly.js if it's not present

set -e

# Configuration
PLOTLY_VERSION="3.0.1"  # Updated to latest version
PLOTLY_URL="https://cdn.plot.ly/plotly-${PLOTLY_VERSION}.min.js"
WEB_ASSETS_DIR="${SRCROOT}/Curtain/WebAssets"
PLOTLY_FILE="${WEB_ASSETS_DIR}/plotly.min.js"

echo "🔍 Checking for Plotly.js..."

# Create WebAssets directory if it doesn't exist
mkdir -p "${WEB_ASSETS_DIR}"

# Check if plotly.min.js exists and is not empty
if [ -f "${PLOTLY_FILE}" ] && [ -s "${PLOTLY_FILE}" ]; then
    echo "✅ Plotly.js already exists and is not empty"
    
    # Check if it's a valid JavaScript file (contains Plotly)
    if grep -q "plotly" "${PLOTLY_FILE}" 2>/dev/null; then
        echo "✅ Plotly.js appears to be valid"
        exit 0
    else
        echo "⚠️  Existing plotly.min.js appears to be invalid, redownloading..."
    fi
fi

echo "📥 Downloading Plotly.js v${PLOTLY_VERSION}..."

# Download Plotly.js with error handling
if command -v curl >/dev/null 2>&1; then
    if curl -fsSL "${PLOTLY_URL}" -o "${PLOTLY_FILE}"; then
        echo "✅ Successfully downloaded Plotly.js using curl"
    else
        echo "❌ Failed to download Plotly.js using curl"
        exit 1
    fi
elif command -v wget >/dev/null 2>&1; then
    if wget -q "${PLOTLY_URL}" -O "${PLOTLY_FILE}"; then
        echo "✅ Successfully downloaded Plotly.js using wget"
    else
        echo "❌ Failed to download Plotly.js using wget"
        exit 1
    fi
else
    echo "❌ Neither curl nor wget is available. Please install one of them."
    exit 1
fi

# Verify the downloaded file
if [ -f "${PLOTLY_FILE}" ] && [ -s "${PLOTLY_FILE}" ]; then
    FILE_SIZE=$(wc -c < "${PLOTLY_FILE}")
    echo "✅ Download complete. File size: ${FILE_SIZE} bytes"
    
    # Basic validation - check if it contains expected Plotly content
    if grep -q "plotly" "${PLOTLY_FILE}" 2>/dev/null; then
        echo "✅ Plotly.js validation successful"
    else
        echo "⚠️  Downloaded file may not be valid Plotly.js"
    fi
else
    echo "❌ Download failed or file is empty"
    exit 1
fi

echo "🎉 Plotly.js setup complete!"