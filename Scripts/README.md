# Build Scripts for Curtain iOS

This directory contains automated build scripts for the Curtain iOS project.

## Scripts Overview

### 🚀 `build-setup.sh` - Main Build Setup Script
The comprehensive build setup script that handles all pre-build tasks.

**Usage:**
```bash
./Scripts/build-setup.sh
```

**What it does:**
- Downloads and verifies Plotly.js
- Verifies all required WebAssets files
- Performs file size validation
- Generates build information
- Provides a complete build readiness report

### 📥 `download-plotly.sh` - Plotly.js Download Script
Handles automatic downloading of Plotly.js library.

**Usage:**
```bash
SRCROOT="$(pwd)" ./Scripts/download-plotly.sh
```

**Features:**
- Downloads Plotly.js v3.0.1 (configurable)
- Validates existing files before downloading
- Basic file integrity checking
- Works with both curl and wget
- Automatic fallback between download tools

## Integration Options

### Option 1: Manual Execution (Recommended for Development)
Run the build setup script manually before building:

```bash
# From project root
./Scripts/build-setup.sh

# Then build normally in Xcode or with xcodebuild
```

### Option 2: Xcode Build Phase Integration
To make the process fully automatic, you can add this as a "Run Script" build phase in Xcode:

1. Open your Xcode project
2. Select your target
3. Go to "Build Phases"
4. Click "+" and add "New Run Script Phase"
5. Move it to be the first build phase
6. Add this script content:
   ```bash
   "${SRCROOT}/Scripts/build-setup.sh"
   ```

### Option 3: Pre-build Hook
Add to your CI/CD pipeline or development workflow:

```bash
# In your CI/CD script or Makefile
pre-build:
	./Scripts/build-setup.sh

build: pre-build
	xcodebuild -scheme Curtain build
```

## Configuration

### Updating Plotly.js Version
Edit `download-plotly.sh` and change the version:
```bash
PLOTLY_VERSION="3.0.1"  # Change this to desired version
```

### Customizing Download URL
If you need to use a different CDN or local mirror:
```bash
PLOTLY_URL="https://your-cdn.com/plotly-${PLOTLY_VERSION}.min.js"
```

## File Structure

After running the scripts, your WebAssets should contain:

```
Curtain/WebAssets/
├── plotly.min.js          # Main Plotly.js library
├── plotly_template.html   # HTML template for charts
└── build-info.txt         # Build information (generated)
```

## Troubleshooting

### Download Issues
- **No internet connection**: Scripts will fail gracefully
- **CDN issues**: Try running the script again later
- **Permission issues**: Make sure scripts are executable (`chmod +x`)

### File Validation Issues
- **File too small**: The script will redownload if Plotly.js is smaller than expected
- **File corruption**: Basic validation checks for "plotly" string in the file
- **Missing files**: Scripts will report exactly which files are missing

### Build Integration Issues
- **SRCROOT not set**: Scripts will auto-detect project root when run manually
- **Path issues**: Use absolute paths in Xcode build phases
- **Permissions**: Ensure scripts have execute permissions

## Requirements

- **System**: macOS with Xcode
- **Network tools**: curl or wget (both are standard on macOS)
- **Permissions**: Execute permissions on script files

## Version History

- **v1.0**: Initial implementation with Plotly.js 3.0.1 support
  - Automatic download and verification
  - Build integration support
  - Comprehensive validation and reporting