#!/bin/bash

# Build script for Linux platforms
set -e

echo "Building PostgreSQL GDExtension for Linux..."

# Check for required dependencies
echo "Checking dependencies..."

# Check for libpqxx
if ! pkg-config --exists libpqxx; then
    echo "libpqxx not found. Install with:"
    echo "   Ubuntu/Debian: sudo apt-get install libpqxx-dev libpq-dev"
    echo "   Fedora/RHEL:   sudo dnf install libpqxx-devel libpq-devel"
    echo "   Arch Linux:    sudo pacman -S libpqxx postgresql-libs"
    exit 1
fi

# Check for SCons
if ! command -v scons &> /dev/null; then
    echo "SCons not found. Install with:"
    echo "   pip install scons"
    echo "   or your distribution's package manager"
    exit 1
fi

echo "Dependencies found"

# Build godot-cpp first
echo "Building godot-cpp for Linux..."
cd godot-cpp
scons platform=linux target=template_debug arch=x86_64 -j$(nproc)
scons platform=linux target=template_release arch=x86_64 -j$(nproc)
cd ..

# Build the extension
echo "Building PostgreSQL extension for Linux..."
scons platform=linux target=template_debug arch=x86_64 -j$(nproc)
scons platform=linux target=template_release arch=x86_64 -j$(nproc)

echo "Linux build completed!"
echo "Debug library: demo/bin/libpostgreadapter.linux.template_debug.x86_64.so"
echo "Release library: demo/bin/libpostgreadapter.linux.template_release.x86_64.so"