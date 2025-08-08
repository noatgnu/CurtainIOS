#!/bin/bash

# Build Setup Script for Curtain iOS App
# This script handles all pre-build setup tasks

set -e

echo "🚀 Starting Curtain iOS build setup..."

# Get the script directory
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(dirname "${SCRIPT_DIR}")"

# Set SRCROOT if not already set (for standalone execution)
if [ -z "${SRCROOT}" ]; then
    export SRCROOT="${PROJECT_ROOT}"
fi

echo "📁 Project root: ${PROJECT_ROOT}"
echo "📁 Source root: ${SRCROOT}"

# 1. Download Plotly.js
echo "🔧 Step 1: Setting up Plotly.js..."
"${SCRIPT_DIR}/download-plotly.sh"

# 2. Verify WebAssets are properly configured
echo "🔧 Step 2: Verifying WebAssets..."
WEB_ASSETS_DIR="${SRCROOT}/Curtain/WebAssets"

if [ ! -d "${WEB_ASSETS_DIR}" ]; then
    echo "❌ WebAssets directory not found: ${WEB_ASSETS_DIR}"
    exit 1
fi

# Check for required files
REQUIRED_FILES=(
    "plotly.min.js"
    "plotly_template.html"
)

for file in "${REQUIRED_FILES[@]}"; do
    FILE_PATH="${WEB_ASSETS_DIR}/${file}"
    if [ -f "${FILE_PATH}" ] && [ -s "${FILE_PATH}" ]; then
        echo "✅ ${file} is present and not empty"
    else
        echo "❌ ${file} is missing or empty"
        exit 1
    fi
done

# 3. Verify file sizes (basic sanity check)
echo "🔧 Step 3: Verifying file sizes..."

PLOTLY_SIZE=$(wc -c < "${WEB_ASSETS_DIR}/plotly.min.js")
if [ "${PLOTLY_SIZE}" -lt 100000 ]; then  # Plotly should be at least 100KB
    echo "❌ plotly.min.js seems too small (${PLOTLY_SIZE} bytes). It might be corrupted."
    exit 1
else
    echo "✅ plotly.min.js size looks good (${PLOTLY_SIZE} bytes)"
fi

# 4. Generate build info (optional)
echo "🔧 Step 4: Generating build info..."
BUILD_INFO_FILE="${WEB_ASSETS_DIR}/build-info.txt"
cat > "${BUILD_INFO_FILE}" << EOF
Curtain iOS Build Information
Generated: $(date)
Plotly.js size: ${PLOTLY_SIZE} bytes
Build script version: 1.0
EOF

echo "✅ Build info written to ${BUILD_INFO_FILE}"

echo "🎉 Build setup completed successfully!"
echo ""
echo "📋 Summary:"
echo "  - Plotly.js: ✅ Ready (${PLOTLY_SIZE} bytes)"
echo "  - WebAssets: ✅ Verified"
echo "  - Build info: ✅ Generated"
echo ""
echo "Your project is ready to build! 🏗️"