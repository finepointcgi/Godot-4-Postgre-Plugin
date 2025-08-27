# Windows Dependencies Solution

> **UPDATE**: The build system now supports automatic dependency bundling! See [Automated Bundling](#automated-bundling) below for the easiest solution.

## Problem
On Windows, the PostgreSQL Godot plugin fails to load with the error:
```
ERROR: Can't open dynamic library: .../libpostgreadapter.windows.template_debug.x86_64.dll. Error: Error 126: The specified module could not be found.
```

This error occurs because Windows cannot find the required PostgreSQL client library dependencies.

## Required Dependencies

The Windows build requires the following DLL files to be placed in the same directory as `libpostgreadapter.windows.template_debug.x86_64.dll` and `libpostgreadapter.windows.template_release.x86_64.dll`:

### Core Dependencies
- `pqxx.dll` - libpqxx C++ PostgreSQL library
- `libpq.dll` - PostgreSQL C client library  
- `libcrypto-3-x64.dll` - OpenSSL crypto library (64-bit)
- `libssl-3-x64.dll` - OpenSSL SSL library (64-bit)

### For 32-bit builds (if needed)
- `libcrypto-3-x86.dll` - OpenSSL crypto library (32-bit)
- `libssl-3-x86.dll` - OpenSSL SSL library (32-bit)

## Solution Steps

### Option 1: Download Dependencies Manually

1. **Download PostgreSQL Windows Binaries**:
   - Go to https://www.postgresql.org/download/windows/
   - Download the PostgreSQL installer or zip binaries
   - Extract and locate the DLL files in the `bin` folder

2. **Copy Required Files**:
   ```bash
   # Navigate to your project's Demo/bin/PostgreAdapter/ directory
   # Copy the following files from PostgreSQL installation:
   - pqxx.dll (from libpqxx installation)
   - libpq.dll (from PostgreSQL bin/)
   - libcrypto-3-x64.dll (from PostgreSQL bin/)
   - libssl-3-x64.dll (from PostgreSQL bin/)
   ```

3. **Verify File Structure**:
   ```
   Demo/
   └── bin/
       └── PostgreAdapter/
           ├── libpostgreadapter.windows.template_debug.x86_64.dll
           ├── libpostgreadapter.windows.template_release.x86_64.dll
           ├── pqxx.dll
           ├── libpq.dll
           ├── libcrypto-3-x64.dll
           └── libssl-3-x64.dll
   ```

### Option 2: Using vcpkg (Recommended for Developers)

If you're building from source:

1. **Install vcpkg**:
   ```bash
   git clone https://github.com/Microsoft/vcpkg.git
   cd vcpkg
   .\bootstrap-vcpkg.bat
   ```

2. **Install PostgreSQL Libraries**:
   ```bash
   .\vcpkg install libpqxx:x64-windows
   .\vcpkg install postgresql:x64-windows
   ```

3. **Copy Dependencies**:
   ```bash
   # Copy from vcpkg/installed/x64-windows/bin/ to your project's bin directory
   ```

## Verification

After copying the dependencies:

1. Open your Godot project
2. The plugin should load without the "Error 126" message
3. Check the Godot console for successful plugin initialization

## Troubleshooting

### Still Getting Error 126?
- Ensure all DLL files are in the same directory as the plugin DLL
- Verify the PostgreSQL DLL versions match (all should be from the same PostgreSQL distribution)
- Check that you're using the correct architecture (x64 vs x86)

### Missing specific DLLs?
Use Dependency Walker or similar tools to identify missing dependencies:
1. Download Dependency Walker (depends.exe)
2. Open your `libpostgreadapter.windows.template_debug.x86_64.dll` 
3. It will show all missing dependencies

### Version Conflicts?
- Ensure all PostgreSQL-related DLLs are from the same version
- Clear any conflicting PostgreSQL installations from PATH

## Distribution Notes

**For Plugin Redistributors**: 
- These DLLs may need to be included in releases for Windows users
- Check PostgreSQL and OpenSSL licensing requirements for redistribution
- Consider using static linking to avoid dependency issues (requires rebuild)

## Alternative: Static Linking

For a permanent solution without runtime dependencies, rebuild the plugin with static linking:
1. Link statically against libpqxx and libpq
2. This eliminates the need for separate DLL files
3. Results in a larger but self-contained plugin DLL

## Automated Bundling

### Easy Solution: Use the Enhanced Build Script

The project now includes an enhanced build script that automatically bundles dependencies:

```batch
# Run the bundled build script
.\build_scripts\build_windows_bundled.bat

# Or for specific options:
.\build_scripts\build_windows_bundled.bat --static    # Force static linking
.\build_scripts\build_windows_bundled.bat --dynamic   # Bundle DLLs dynamically  
.\build_scripts\build_windows_bundled.bat --help      # Show all options
```

### How It Works

The enhanced build system supports two bundling methods:

#### 1. Static Linking (Preferred)
- Links PostgreSQL libraries directly into the plugin DLL
- Creates a single, self-contained DLL with no external dependencies
- Requires vcpkg or static PostgreSQL libraries
- Resulting DLL is larger but completely portable

#### 2. Dynamic Bundling (Fallback)  
- Automatically copies required DLLs to the plugin directory
- Uses the existing PostgreSQL dynamic libraries
- Smaller plugin DLL but requires bundled dependencies
- Compatible with standard PostgreSQL installations

### Build Environment Variables

The build system recognizes these environment variables:

- `BUNDLE_DEPENDENCIES=true/false` - Enable/disable dependency bundling
- `POSTGRESQL_PATH` - Path to PostgreSQL installation
- `VCPKG_ROOT` - Path to vcpkg installation (for static linking)

### Examples

```batch
# Build with automatic dependency detection
scons platform=windows target=template_debug

# Force static linking (requires vcpkg)
set BUNDLE_DEPENDENCIES=true
scons platform=windows target=template_debug

# Disable bundling (creates plugin that needs manual DLL placement)
set BUNDLE_DEPENDENCIES=false
scons platform=windows target=template_debug
```

## Manual Solutions (Legacy)

If you prefer manual dependency management or the automated bundling doesn't work:

## Credits

- Solution originally identified by GitHub user kieranju in issue discussions
- Enhanced build system with automatic bundling support added