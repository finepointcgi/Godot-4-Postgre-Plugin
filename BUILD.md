# Building PostgreSQL GDExtension

This document provides comprehensive instructions for building the PostgreSQL GDExtension for all supported platforms.

## Quick Start

### Automated Building
```bash
# Build for current platform automatically
./build_scripts/build_all.sh

# Or use platform-specific scripts
./build_scripts/build_macos.sh     # macOS
./build_scripts/build_linux.sh    # Linux  
./build_scripts/build_windows.bat # Windows
```

## Platform-Specific Instructions

### macOS

**Prerequisites:**
- Xcode Command Line Tools
- Homebrew
- PostgreSQL libraries

**Setup:**
```bash
# Install Homebrew (if not installed)
/bin/bash -c "$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/HEAD/install.sh)"

# Install dependencies
brew install libpqxx postgresql
pip install scons
```

**Build:**
```bash
./build_scripts/build_macos.sh
```

**Output:**
- `demo/bin/libpostgreadapter.macos.template_debug.framework/`
- `demo/bin/libpostgreadapter.macos.template_release.framework/`

### Linux

**Prerequisites:**
- GCC or Clang
- PostgreSQL development libraries
- pkg-config

**Setup (Ubuntu/Debian):**
```bash
sudo apt-get update
sudo apt-get install -y libpqxx-dev libpq-dev build-essential pkg-config
pip install scons
```

**Setup (Fedora/RHEL):**
```bash
sudo dnf install libpqxx-devel libpq-devel gcc-c++ pkg-config
pip install scons
```

**Setup (Arch Linux):**
```bash
sudo pacman -S libpqxx postgresql-libs base-devel pkg-config
pip install scons
```

**Build:**
```bash
./build_scripts/build_linux.sh
```

**Output:**
- `demo/bin/libpostgreadapter.linux.template_debug.x86_64.so`
- `demo/bin/libpostgreadapter.linux.template_release.x86_64.so`

### Windows

**Prerequisites:**
- Visual Studio 2019/2022 or Build Tools
- PostgreSQL for Windows
- Python 3.x

**Setup:**
1. Install Visual Studio with C++ development tools
2. Download and install PostgreSQL from https://www.postgresql.org/download/windows/
3. Install Python and SCons:
   ```cmd
   pip install scons
   ```

**Build:**
```cmd
# Run from Visual Studio Developer Command Prompt
build_scripts\build_windows.bat
```

**Output:**
- `demo/bin/libpostgreadapter.windows.template_debug.x86_64.dll`
- `demo/bin/libpostgreadapter.windows.template_release.x86_64.dll`

## Manual Building

### Step 1: Initialize Submodules
```bash
git submodule update --init --recursive
```

### Step 2: Build godot-cpp
```bash
cd godot-cpp

# Debug build
scons platform=<platform> target=template_debug arch=<arch>

# Release build  
scons platform=<platform> target=template_release arch=<arch>

cd ..
```

### Step 3: Build Extension
```bash
# Debug build
scons platform=<platform> target=template_debug arch=<arch>

# Release build
scons platform=<platform> target=template_release arch=<arch>
```

**Platform/Architecture Options:**
- `platform`: `macos`, `linux`, `windows`
- `arch`: `x86_64`, `arm64`, `universal` (macOS only)

## Continuous Integration

The project includes GitHub Actions workflows for automated building:

- **Trigger:** Push to main/master branch, pull requests, releases
- **Platforms:** Ubuntu (Linux), Windows Server, macOS
- **Artifacts:** Debug and release builds for all platforms
- **Release Packaging:** Automatic creation of release archives

## Cross-Compilation

### Linux ARM64 (from x86_64)
```bash
# Install cross-compilation tools
sudo apt-get install gcc-aarch64-linux-gnu g++-aarch64-linux-gnu

# Build with cross-compiler
scons platform=linux target=template_release arch=arm64 CXX=aarch64-linux-gnu-g++
```

### macOS Universal Binaries
```bash
# Builds both Intel and Apple Silicon binaries
scons platform=macos target=template_release arch=universal
```

## Troubleshooting

### PostgreSQL Not Found
- **macOS:** `brew install libpqxx`
- **Linux:** Install `libpqxx-dev` or `libpqxx-devel`
- **Windows:** Set `POSTGRESQL_PATH` environment variable

### SCons Errors
- Ensure Python 3.x is installed
- Install SCons: `pip install scons`
- Check PATH includes Python scripts directory

### Linking Errors
- Verify PostgreSQL libraries are installed
- Check library paths in SConstruct
- Ensure compatible architecture (x86_64 vs ARM64)

### Build Performance
- Use parallel building: `-j$(nproc)` (Linux), `-j$(sysctl -n hw.ncpu)` (macOS)
- Consider using ccache for faster rebuilds
- Clean build directory if experiencing issues: `scons -c`

## Build Configuration

The build system automatically detects platform-specific library paths:

- **macOS:** Homebrew paths (`/opt/homebrew` or `/usr/local`)
- **Linux:** pkg-config detection with fallback paths
- **Windows:** Environment variable or standard installation paths

For custom PostgreSQL installations, modify the SConstruct file or set environment variables:
- `POSTGRESQL_PATH` (Windows)
- `PKG_CONFIG_PATH` (Linux)

## Binary Compatibility

### Minimum Requirements
- **Godot:** 4.1+
- **PostgreSQL:** 12+ (client libraries)
- **libpqxx:** 7.0+

### ABI Compatibility
- Built binaries are compatible within major Godot versions
- PostgreSQL client library versions are forward compatible
- Use release builds for distribution