# Cross-Platform Dependency Bundling

This document explains how to build the PostgreSQL Godot plugin with bundled dependencies on all supported platforms (Windows, macOS, Linux).

## 🎯 Quick Start

### Windows
```batch
# Automatic bundling (recommended)
.\build_scripts\build_windows_bundled.bat

# Force static linking
.\build_scripts\build_windows_bundled.bat --static

# Manual SCons build
set BUNDLE_DEPENDENCIES=true
scons platform=windows target=template_debug
```

### macOS
```bash
# Automatic bundling (recommended) 
./build_scripts/build_macos_bundled.sh

# Force static linking
./build_scripts/build_macos_bundled.sh --static

# Manual SCons build
export BUNDLE_DEPENDENCIES=true
scons platform=macos target=template_debug
```

### Linux
```bash
# Automatic bundling (recommended)
./build_scripts/build_linux_bundled.sh

# Force static linking  
./build_scripts/build_linux_bundled.sh --static

# Manual SCons build
export BUNDLE_DEPENDENCIES=true
scons platform=linux target=template_debug
```

## 📋 Platform-Specific Details

### Windows Bundling

**Method 1: Static Linking (Preferred)**
- Links PostgreSQL libraries directly into the plugin DLL
- Creates a single, self-contained DLL
- Requires vcpkg or static PostgreSQL libraries

**Method 2: Dynamic Bundling**
- Copies required DLLs alongside the plugin
- Works with standard PostgreSQL installations
- Dependencies: `pqxx.dll`, `libpq.dll`, `libcrypto-3-x64.dll`, `libssl-3-x64.dll`

**Output Structure:**
```
Demo/bin/PostgreAdapter/
├── libpostgreadapter.windows.template_debug.x86_64.dll
├── libpostgreadapter.windows.template_release.x86_64.dll
├── pqxx.dll                    # (if dynamic bundling)
├── libpq.dll                   # (if dynamic bundling)
├── libcrypto-3-x64.dll        # (if dynamic bundling)
└── libssl-3-x64.dll           # (if dynamic bundling)
```

### macOS Bundling

**Method 1: Static Linking (Preferred)**
- Links PostgreSQL libraries directly into the framework
- Creates self-contained frameworks
- Requires static libraries: `brew install libpqxx --static`

**Method 2: Dynamic Bundling**
- Bundles required dylibs into framework using `@rpath`
- Uses `install_name_tool` to update library paths
- Compatible with standard Homebrew installations
- Dependencies: `libpqxx.dylib`, `libpq.dylib`, `libssl.dylib`, `libcrypto.dylib`

**Output Structure:**
```
Demo/bin/PostgreAdapter/
├── libpostgreadapter.macos.template_debug.framework/
│   ├── libpostgreadapter.macos.template_debug
│   └── Libraries/              # (if dynamic bundling)
│       ├── libpqxx.*.dylib
│       ├── libpq.*.dylib
│       ├── libssl.*.dylib
│       └── libcrypto.*.dylib
└── libpostgreadapter.macos.template_release.framework/
    ├── libpostgreadapter.macos.template_release
    └── Libraries/              # (if dynamic bundling)
        └── ...
```

### Linux Bundling

**Method 1: Static Linking (Preferred)**
- Links PostgreSQL libraries directly into the .so file
- Creates self-contained shared libraries
- Uses `pkg-config --static` flags when available

**Method 2: Dynamic Bundling**
- Bundles required .so files with `$ORIGIN` RPATH
- Uses `patchelf` or linker RPATH settings
- Compatible with system package manager installations
- Dependencies: `libpqxx.so`, `libpq.so`, `libssl.so`, `libcrypto.so`

**Output Structure:**
```
Demo/bin/PostgreAdapter/
├── libpostgreadapter.linux.template_debug.x86_64.so
├── libpostgreadapter.linux.template_release.x86_64.so
└── libs/                       # (if dynamic bundling)
    ├── libpqxx.so.*
    ├── libpq.so.*
    ├── libssl.so.*
    └── libcrypto.so.*
```

## 🔧 Environment Variables

The build system recognizes these environment variables across all platforms:

### Common Variables
- `BUNDLE_DEPENDENCIES=true/false` - Enable/disable dependency bundling (default: true)
- `BUNDLE_METHOD_ACTUAL=static/dynamic/auto` - Force specific bundling method

### Platform-Specific Variables

**Windows:**
- `POSTGRESQL_PATH` - Path to PostgreSQL installation
- `VCPKG_ROOT` - Path to vcpkg installation

**macOS:**
- `HOMEBREW_PREFIX` - Override Homebrew prefix detection

**Linux:**
- `TARGET_ARCH` - Target architecture (x86_64, arm64)

## 📦 Installation Requirements

### Windows
```batch
# Option 1: vcpkg (recommended for static linking)
git clone https://github.com/Microsoft/vcpkg.git
cd vcpkg && .\bootstrap-vcpkg.bat
.\vcpkg install libpqxx:x64-windows

# Option 2: PostgreSQL installer
# Download from https://www.postgresql.org/download/windows/

# Build tools
pip install scons
# Ensure Visual Studio Build Tools are installed
```

### macOS
```bash
# Install Homebrew dependencies
brew install libpqxx scons

# For static linking (optional)
brew install libpqxx --static
```

### Linux
```bash
# Ubuntu/Debian
sudo apt-get install libpqxx-dev libpq-dev build-essential
pip install scons

# Fedora/RHEL
sudo dnf install libpqxx-devel libpq-devel gcc-c++
pip install scons

# Arch Linux
sudo pacman -S libpqxx postgresql-libs base-devel
pip install scons

# For RPATH manipulation (optional)
sudo apt install patchelf  # Ubuntu/Debian
```

## 🚀 Build Examples

### Simple Build (All Platforms)
```bash
# Uses automatic dependency detection and bundling
scons platform=<platform> target=template_debug
scons platform=<platform> target=template_release
```

### Force Static Linking
```bash
# Windows (with vcpkg)
set BUNDLE_DEPENDENCIES=true
set BUNDLE_METHOD_ACTUAL=static
scons platform=windows target=template_debug

# macOS (with static libs)
export BUNDLE_DEPENDENCIES=true
export BUNDLE_METHOD_ACTUAL=static
scons platform=macos target=template_debug

# Linux (with static packages)
export BUNDLE_DEPENDENCIES=true
export BUNDLE_METHOD_ACTUAL=static
scons platform=linux target=template_debug
```

### Force Dynamic Bundling
```bash
# All platforms
export BUNDLE_DEPENDENCIES=true        # or set on Windows
export BUNDLE_METHOD_ACTUAL=dynamic
scons platform=<platform> target=template_debug
```

### Disable Bundling
```bash
# Creates plugin that requires system PostgreSQL libraries
export BUNDLE_DEPENDENCIES=false       # or set on Windows
scons platform=<platform> target=template_debug
```

## 🔍 Troubleshooting

### Common Issues

**"Library not found" errors:**
- Ensure PostgreSQL development libraries are installed
- Check environment variable paths
- Verify static libraries exist if using static linking

**Runtime dependency errors:**
- For dynamic bundling, ensure all dependency files are distributed
- Check RPATH/install_name settings on macOS/Linux
- Verify DLL locations on Windows

**Build system not detecting libraries:**
- Check pkg-config on Linux: `pkg-config --exists libpqxx`
- Verify Homebrew installation on macOS: `brew list libpqxx`
- Check PostgreSQL installation on Windows

### Platform-Specific Troubleshooting

**Windows:**
- Use Visual Studio Developer Command Prompt
- Ensure all DLLs are in the same directory as the plugin
- Check architecture compatibility (x64 vs x86)

**macOS:**
- Install Xcode Command Line Tools: `xcode-select --install`
- Use the correct Homebrew prefix (Apple Silicon vs Intel)
- Check framework structure and @rpath settings: `otool -L`

**Linux:**
- Install build-essential packages
- Check library paths: `ldconfig -p | grep pqxx`
- Verify RPATH settings: `objdump -x library.so | grep RPATH`

## 📖 Technical Details

### How Static Linking Works
- Embeds PostgreSQL library code directly into plugin binary
- Eliminates runtime dependencies
- Increases binary size but improves portability
- Uses linker flags: `-static-libstdc++` (macOS), `--static` (Linux)

### How Dynamic Bundling Works

**Windows:**
- Copies DLLs to plugin directory
- Windows searches current directory for dependencies
- No additional configuration needed

**macOS:**
- Bundles dylibs into framework `Libraries/` directory
- Uses `install_name_tool` to update library references
- Sets `@rpath` to `@loader_path` for relative loading

**Linux:**
- Bundles .so files into `libs/` subdirectory
- Sets RPATH to `$ORIGIN/libs:$ORIGIN` for relative loading
- Uses `patchelf` or linker flags to modify RPATH

### Build System Integration
- SCons detects available bundling methods automatically
- Post-build actions handle dependency copying/bundling
- Environment variables override automatic detection
- Cross-platform compatibility maintained through unified interface

## 🎁 Distribution

### What to Include in Your Release

**Windows:**
```
PostgreAdapter/
├── libpostgreadapter.windows.template_debug.x86_64.dll
├── libpostgreadapter.windows.template_release.x86_64.dll
└── [dependency DLLs if dynamic bundling]
```

**macOS:**
```
PostgreAdapter/
├── libpostgreadapter.macos.template_debug.framework/
└── libpostgreadapter.macos.template_release.framework/
```

**Linux:**
```
PostgreAdapter/
├── libpostgreadapter.linux.template_debug.x86_64.so
├── libpostgreadapter.linux.template_release.x86_64.so
└── libs/ [if dynamic bundling]
```

### License Considerations
- Check PostgreSQL and OpenSSL licensing for redistribution
- Static linking may have different license implications
- Consider providing separate "system dependencies" builds

## 🔗 Related Files
- `build_scripts/build_windows_bundled.bat` - Enhanced Windows build script
- `build_scripts/build_macos_bundled.sh` - Enhanced macOS build script  
- `build_scripts/build_linux_bundled.sh` - Enhanced Linux build script
- `SConstruct` - Updated build configuration with bundling support
- `WINDOWS_DEPENDENCIES.md` - Windows-specific dependency information