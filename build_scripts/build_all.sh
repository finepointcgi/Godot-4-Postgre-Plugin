#!/bin/bash

# Universal build script that detects platform and builds accordingly
set -e

echo "PostgreSQL GDExtension - Universal Build Script"
echo "==============================================="

# Detect platform
if [[ "$OSTYPE" == "linux-gnu"* ]]; then
    PLATFORM="linux"
    BUILD_SCRIPT="build_linux.sh"
elif [[ "$OSTYPE" == "darwin"* ]]; then
    PLATFORM="macos"
    BUILD_SCRIPT="build_macos.sh"
elif [[ "$OSTYPE" == "msys" || "$OSTYPE" == "cygwin" ]]; then
    PLATFORM="windows"
    BUILD_SCRIPT="build_windows.bat"
else
    echo "Unsupported platform: $OSTYPE"
    echo "Supported platforms: Linux, macOS, Windows"
    exit 1
fi

echo "Detected platform: $PLATFORM"
echo "Running platform-specific build script..."
echo

# Get script directory
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

# Make build script executable
chmod +x "$SCRIPT_DIR/$BUILD_SCRIPT"

# Run platform-specific build script
if [[ "$PLATFORM" == "windows" ]]; then
    cmd.exe /c "$SCRIPT_DIR/$BUILD_SCRIPT"
else
    "$SCRIPT_DIR/$BUILD_SCRIPT"
fi

echo
echo "Build completed for $PLATFORM!"

# Show output files
echo
echo "Generated files:"
if [[ "$PLATFORM" == "macos" ]]; then
    ls -la demo/bin/PostgreAdapter/*.framework/ 2>/dev/null || echo "  No framework files found"
elif [[ "$PLATFORM" == "linux" ]]; then
    ls -la demo/bin/PostgreAdapter/*.so 2>/dev/null || echo "  No .so files found"
elif [[ "$PLATFORM" == "windows" ]]; then
    ls -la demo/bin/PostgreAdapter/*.dll 2>/dev/null || echo "  No .dll files found"
fi