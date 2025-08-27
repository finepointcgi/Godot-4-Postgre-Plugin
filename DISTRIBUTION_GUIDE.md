# PostgreSQL Godot Plugin - Distribution Guide

## 🎯 Building for Distribution (No PostgreSQL Required for End Users)

This guide shows how to build a complete, self-contained plugin package that your users can use without installing PostgreSQL.

## 🚀 Quick Build for Distribution

### Windows
```batch
# Simple one-command build that includes all dependencies
.\build_for_distribution.bat
```

This creates a complete plugin package in `Demo\bin\PostgreAdapter\` with ALL dependencies included.

### macOS
```bash
# Build with automatic dependency bundling
./build_scripts/build_macos_bundled.sh
```

Creates self-contained frameworks with all dependencies bundled.

### Linux  
```bash
# Build with automatic dependency bundling
./build_scripts/build_linux_bundled.sh
```

Creates libraries with all dependencies bundled using RPATH.

## 📦 What Gets Bundled

### Windows Package Includes:
```
Demo/bin/PostgreAdapter/
├── libpostgreadapter.windows.template_debug.x86_64.dll
├── libpostgreadapter.windows.template_release.x86_64.dll
├── libpq.dll              # PostgreSQL client library
├── libcrypto-3-x64.dll    # OpenSSL crypto library
├── libssl-3-x64.dll       # OpenSSL SSL library
└── pqxx.dll               # C++ PostgreSQL wrapper
```

### macOS Package Includes:
```
Demo/bin/PostgreAdapter/
├── libpostgreadapter.macos.template_debug.framework/
│   ├── libpostgreadapter.macos.template_debug
│   └── Libraries/          # All dependencies bundled here
└── libpostgreadapter.macos.template_release.framework/
    ├── libpostgreadapter.macos.template_release  
    └── Libraries/          # All dependencies bundled here
```

### Linux Package Includes:
```
Demo/bin/PostgreAdapter/
├── libpostgreadapter.linux.template_debug.x86_64.so
├── libpostgreadapter.linux.template_release.x86_64.so
└── libs/                   # All dependencies bundled here
    ├── libpqxx.so.*
    ├── libpq.so.*
    ├── libssl.so.*
    └── libcrypto.so.*
```

## 📋 Prerequisites (For Building Only)

### Windows
- Visual Studio Build Tools or Visual Studio
- PostgreSQL installation OR vcpkg with libpqxx
- Python with SCons: `pip install scons`

**Recommended setup:**
```batch
# Install PostgreSQL (includes development libraries)
# Download from: https://www.postgresql.org/download/windows/

# Or use vcpkg
git clone https://github.com/Microsoft/vcpkg.git
cd vcpkg
.\bootstrap-vcpkg.bat
.\vcpkg install libpqxx:x64-windows
```

### macOS
```bash
# Install Homebrew dependencies
brew install libpqxx scons
```

### Linux
```bash
# Ubuntu/Debian
sudo apt-get install libpqxx-dev libpq-dev build-essential
pip install scons

# Fedora/RHEL  
sudo dnf install libpqxx-devel libpq-devel gcc-c++
pip install scons
```

## 🎁 Distributing to Your Users

### What to Include in Your Release

**For all platforms**, zip/package the entire directory:
- Windows: `Demo\bin\PostgreAdapter\` 
- macOS: `Demo/bin/PostgreAdapter/`
- Linux: `Demo/bin/PostgreAdapter/`

### User Installation Instructions

**Your users only need to:**

1. **Extract** the PostgreAdapter folder to their Godot project
2. **Place** the `.gdextension` file in their project root
3. **Use** the plugin - no PostgreSQL installation required!

**Example user folder structure:**
```
MyGodotProject/
├── postgreadapter.gdextension
├── bin/
│   └── PostgreAdapter/
│       └── [all the bundled files]
└── [their game files]
```

## ✅ Verification

### Test Your Distribution Package

1. **Build** your distribution package
2. **Copy** to a clean machine without PostgreSQL
3. **Test** in Godot - should work without any additional installations

### Common Issues & Solutions

**"Module not found" errors:**
- Ensure all DLL/dylib/so files are in the same directory as specified in `.gdextension`
- Check architecture matches (x64 vs x86)

**"Library not loaded" on macOS:**
- Verify framework structure is correct
- Check that `@rpath` is properly set (done automatically by build)

**"Library not found" on Linux:**
- Ensure `libs/` subdirectory exists with bundled libraries
- Verify RPATH is set correctly (done automatically by build)

## 🔧 Advanced Distribution Options

### Minimal Package (Windows only)
If you want to reduce package size and know your users' setup:

```batch
# Build without bundling (users need PostgreSQL)
set BUNDLE_DEPENDENCIES=false
scons platform=windows target=template_release
```

### Debug vs Release
- **Release builds** are smaller and faster for distribution
- **Debug builds** include debugging symbols for development

```batch
# Build only release for distribution
.\build_for_distribution.bat --release
```

## 📊 Package Sizes (Approximate)

- **Windows**: ~15-25 MB (includes PostgreSQL + OpenSSL DLLs)
- **macOS**: ~10-20 MB (framework with bundled dylibs)  
- **Linux**: ~8-15 MB (shared libraries with bundled dependencies)

These sizes include ALL dependencies needed for PostgreSQL connectivity.

## ⚖️ Licensing Considerations

When distributing bundled dependencies:

- **PostgreSQL libraries**: PostgreSQL License (similar to BSD/MIT)
- **OpenSSL libraries**: Apache License 2.0
- **Your plugin**: Your chosen license

**Recommendation**: Include a `LICENSES.txt` file with your distribution acknowledging the bundled libraries and their licenses.

## 🎯 Summary

✅ **Use `build_for_distribution.bat` on Windows for one-command building**  
✅ **All dependencies automatically bundled**  
✅ **Users don't need PostgreSQL installed**  
✅ **Works on clean machines**  
✅ **Complete self-contained packages**  

Your users get a plugin that "just works" without any setup hassles! 🚀