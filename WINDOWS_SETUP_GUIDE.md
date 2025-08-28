# Windows Setup Guide - PostgreSQL Godot Plugin

## 🎯 **Super Easy Setup (Recommended)**

### **One-Command Setup:**
```batch
# Run this once to install everything needed:
.\setup_vcpkg_windows.bat

# Then build your distribution package:
.\build_for_distribution.bat
```

**That's it!** This handles everything automatically.

## 🔧 **What the Setup Does**

### **Installs vcpkg + PostgreSQL Libraries:**
- ✅ **vcpkg package manager** - Microsoft's C++ library manager
- ✅ **libpqxx** - PostgreSQL C++ wrapper library
- ✅ **libpq** - PostgreSQL C client library  
- ✅ **OpenSSL** - SSL/crypto libraries (auto-installed as dependencies)
- ✅ **Environment variables** - Sets `VCPKG_ROOT` automatically

### **Creates Self-Contained Plugin:**
After setup, your build will include ALL required DLLs:
```
Demo/bin/PostgreAdapter/
├── libpostgreadapter.windows.template_debug.x86_64.dll
├── libpostgreadapter.windows.template_release.x86_64.dll  
├── pqxx.dll              # PostgreSQL C++ wrapper
├── libpq.dll             # PostgreSQL client
├── libcrypto-3-x64.dll   # OpenSSL crypto
└── libssl-3-x64.dll      # OpenSSL SSL
```

## 📋 **Requirements**

### **Before Running Setup:**
- **Windows 10/11** with PowerShell/Command Prompt
- **Git** installed and in PATH
- **Visual Studio Build Tools** or Visual Studio Community
- **Internet connection** (for downloading packages)

### **Visual Studio Setup:**
```batch
# Download Visual Studio Build Tools (free):
# https://visualstudio.microsoft.com/downloads/#build-tools-for-visual-studio-2022

# Or install Visual Studio Community (free, full IDE)
# https://visualstudio.microsoft.com/vs/community/

# Make sure "C++ build tools" are installed
```

## 🚀 **Step-by-Step Process**

### **Step 1: Get Build Tools**
```batch
# Check if you have Visual Studio tools:
where cl
# If not found, install Visual Studio Build Tools
```

### **Step 2: Run Setup Script**
```batch
# From plugin directory:
.\setup_vcpkg_windows.bat
```

**What happens:**
1. Downloads and installs vcpkg (~50MB)
2. Compiles PostgreSQL libraries (~10-30 minutes)
3. Sets environment variables
4. Verifies installation

### **Step 3: Build Plugin**
```batch
# Creates complete distribution package:
.\build_for_distribution.bat
```

**What happens:**
1. Builds godot-cpp
2. Builds your plugin
3. Automatically bundles all DLL dependencies
4. Creates ready-to-distribute package

## 🔍 **Troubleshooting**

### **Common Issues:**

#### **"Git not found"**
```batch
# Install Git for Windows:
# https://git-scm.com/download/win
# Or use winget:
winget install Git.Git
```

#### **"Visual Studio not found"**
```batch
# Install Visual Studio Build Tools:
# https://visualstudio.microsoft.com/downloads/#build-tools-for-visual-studio-2022
# Make sure to include "C++ build tools" workload
```

#### **"Cannot open input file 'libpqxx.lib'"**
This means the setup didn't complete properly. Try:
```batch
# Remove vcpkg and start over:
rmdir /s /q vcpkg
.\setup_vcpkg_windows.bat
```

#### **"vcpkg install failed"**
Common causes:
- **Antivirus blocking** - temporarily disable during install
- **Disk space** - vcpkg needs ~5GB free space
- **Network issues** - check internet connection

### **Manual Verification:**
```batch
# Check if vcpkg installed correctly:
vcpkg\vcpkg list
# Should show libpqxx and dependencies

# Check environment variable:
echo %VCPKG_ROOT%
# Should point to your vcpkg directory
```

## 🎁 **Alternative Setups**

### **If You Already Have PostgreSQL:**
```batch
# Set your PostgreSQL path:
set POSTGRESQL_PATH=C:\Program Files\PostgreSQL\16

# Then run the build (may have limited functionality):
.\build_for_distribution.bat
```

### **Manual vcpkg Setup:**
```batch
# Clone vcpkg:
git clone https://github.com/Microsoft/vcpkg.git
cd vcpkg

# Bootstrap:
.\bootstrap-vcpkg.bat

# Install PostgreSQL:
.\vcpkg install libpqxx:x64-windows

# Set environment:
set VCPKG_ROOT=%CD%
```

## ⚡ **Quick Start Summary**

For most users, this is all you need:

```batch
# 1. One-time setup (installs everything):
.\setup_vcpkg_windows.bat

# 2. Build distribution package:
.\build_for_distribution.bat

# 3. Share the Demo\bin\PostgreAdapter\ folder with users!
```

Your users get a plugin that works on any Windows machine without PostgreSQL installed! 🚀

## 📊 **What Gets Built**

### **Debug + Release Versions:**
- Plugin works in both Godot editor and exported games
- All dependencies included for both versions
- Total package size: ~15-25MB (includes everything)

### **Distribution Package:**
```
Demo/bin/PostgreAdapter/     # ← Share this entire folder
├── *.dll                   # Your plugin
└── [dependency DLLs]       # PostgreSQL + OpenSSL libraries
```

Users just copy this folder to their Godot project - no installation required!

## 🎯 **Benefits of This Approach**

✅ **One-time setup** - install once, build many times  
✅ **Automatic dependency bundling** - no manual DLL copying  
✅ **Self-contained packages** - users need no PostgreSQL  
✅ **Works everywhere** - compatible with all Windows 10/11 systems  
✅ **Easy updates** - just rebuild when you change code  
✅ **Professional distribution** - looks and works like commercial plugins