#!/bin/bash

# Build script for macOS platforms
set -e

echo "Building PostgreSQL GDExtension for macOS..."

# Check for required dependencies
echo "Checking dependencies..."

# Check for Homebrew
if ! command -v brew &> /dev/null; then
    echo "Homebrew not found. Install from https://brew.sh"
    exit 1
fi

# Check for libpqxx
if ! brew list | grep -q libpqxx; then
    echo "libpqxx not found. Install with:"
    echo "   brew install libpqxx"
    exit 1
fi

# Check for SCons
if ! command -v scons &> /dev/null; then
    echo "SCons not found. Install with:"
    echo "   pip install scons"
    echo "   or: brew install scons"
    exit 1
fi

echo "Dependencies found"

# Build godot-cpp first
echo "Building godot-cpp for macOS..."
cd godot-cpp
scons platform=macos target=template_debug arch=universal -j$(sysctl -n hw.ncpu)
scons platform=macos target=template_release arch=universal -j$(sysctl -n hw.ncpu)
cd ..

# Build the extension
echo "Building PostgreSQL extension for macOS..."
scons platform=macos target=template_debug arch=universal -j$(sysctl -n hw.ncpu)
scons platform=macos target=template_release arch=universal -j$(sysctl -n hw.ncpu)

echo "macOS build completed!"
echo "Debug framework: demo/bin/PostgreAdapter/libpostgreadapter.macos.template_debug.framework/"
echo "Release framework: demo/bin/PostgreAdapter/libpostgreadapter.macos.template_release.framework/"