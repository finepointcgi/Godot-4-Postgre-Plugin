#!/bin/bash

# Enhanced Linux build script with dependency bundling
# This script builds the PostgreSQL Godot plugin with bundled dependencies

set -e

# Color output functions
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

error() { echo -e "${RED}[ERROR]${NC} $1" >&2; exit 1; }
info() { echo -e "${BLUE}[INFO]${NC} $1"; }
success() { echo -e "${GREEN}[SUCCESS]${NC} $1"; }
warning() { echo -e "${YELLOW}[WARNING]${NC} $1"; }

# Default configuration
BUILD_TYPE="both"
BUNDLE_METHOD="auto"
VERBOSE=false
ARCH="x86_64"

# Parse command line arguments
show_help() {
    cat << EOF
USAGE:
    $0 [OPTIONS]

OPTIONS:
    --help, -h         Show this help message
    --debug            Build debug version only
    --release          Build release version only
    --static           Force static linking (self-contained .so)
    --dynamic          Force dynamic linking with bundled libraries
    --arch ARCH        Target architecture (x86_64, arm64) [default: x86_64]
    --verbose, -v      Verbose output

DESCRIPTION:
    Builds the PostgreSQL Godot plugin for Linux with bundled dependencies.
    Creates self-contained shared libraries that don't require system PostgreSQL.

BUNDLING METHODS:
    static   - Links PostgreSQL libraries directly into .so (preferred)
    dynamic  - Bundles required .so files with RPATH pointing to plugin directory
    auto     - Automatically chooses best method based on available libraries

EXAMPLES:
    $0                           # Build both debug and release with auto bundling
    $0 --debug --static          # Build debug only with static linking
    $0 --release --dynamic       # Build release only with bundled libraries
    $0 --arch arm64              # Build for ARM64 architecture

REQUIREMENTS:
    - GCC/Clang compiler
    - PostgreSQL development libraries
    - SCons build system

PACKAGE INSTALLATION:
    Ubuntu/Debian: sudo apt-get install libpqxx-dev libpq-dev build-essential
    Fedora/RHEL:   sudo dnf install libpqxx-devel libpq-devel gcc-c++
    Arch Linux:    sudo pacman -S libpqxx postgresql-libs base-devel
    openSUSE:      sudo zypper install libpqxx-devel postgresql-devel

EOF
}

while [[ $# -gt 0 ]]; do
    case $1 in
        --help|-h)
            show_help
            exit 0
            ;;
        --debug)
            BUILD_TYPE="debug"
            shift
            ;;
        --release)
            BUILD_TYPE="release"
            shift
            ;;
        --static)
            BUNDLE_METHOD="static"
            shift
            ;;
        --dynamic)
            BUNDLE_METHOD="dynamic"
            shift
            ;;
        --arch)
            ARCH="$2"
            shift 2
            ;;
        --verbose|-v)
            VERBOSE=true
            shift
            ;;
        *)
            error "Unknown option: $1. Use --help for usage information."
            ;;
    esac
done

info "============================================================"
info "PostgreSQL GDExtension - Linux Build with Bundled Dependencies"
info "============================================================"
info ""
info "Build configuration:"
info "  Build type: $BUILD_TYPE"
info "  Bundle method: $BUNDLE_METHOD"
info "  Architecture: $ARCH"
info "  Verbose: $VERBOSE"
info ""

# Detect Linux distribution
DISTRO="unknown"
if [[ -f /etc/os-release ]]; then
    . /etc/os-release
    DISTRO="$ID"
fi
info "Detected distribution: $DISTRO"

# Check for required tools
info "Checking build dependencies..."

# Check for compiler
if command -v clang++ &> /dev/null; then
    COMPILER="clang++"
    info "Found compiler: clang++"
elif command -v g++ &> /dev/null; then
    COMPILER="g++"
    info "Found compiler: g++"
else
    error "No C++ compiler found. Install build tools for your distribution."
fi

# Check for SCons
if ! command -v scons &> /dev/null; then
    error "SCons not found. Install with: pip install scons or your package manager"
fi

# Check for pkg-config
if ! command -v pkg-config &> /dev/null; then
    error "pkg-config not found. Install with your package manager"
fi

# Check for PostgreSQL libraries
if ! pkg-config --exists libpqxx; then
    error "libpqxx development libraries not found. Install with your package manager:
    Ubuntu/Debian: sudo apt-get install libpqxx-dev libpq-dev
    Fedora/RHEL:   sudo dnf install libpqxx-devel libpq-devel  
    Arch Linux:    sudo pacman -S libpqxx postgresql-libs
    openSUSE:      sudo zypper install libpqxx-devel postgresql-devel"
fi

success "Dependencies found"

# Get library information
LIBPQXX_VERSION=$(pkg-config --modversion libpqxx 2>/dev/null || echo "unknown")
LIBPQ_VERSION=$(pkg-config --modversion libpq 2>/dev/null || echo "unknown")
info "  libpqxx version: $LIBPQXX_VERSION"
info "  libpq version: $LIBPQ_VERSION"

# Check library paths
LIBPQXX_LIBDIR=$(pkg-config --variable=libdir libpqxx 2>/dev/null || echo "")
LIBPQ_LIBDIR=$(pkg-config --variable=libdir libpq 2>/dev/null || echo "")
info "  libpqxx libdir: $LIBPQXX_LIBDIR"
info "  libpq libdir: $LIBPQ_LIBDIR"

# Determine bundling strategy
BUNDLE_DEPENDENCIES="true"
STATIC_LIBS_AVAILABLE=false

# Check if static libraries are available
STATIC_PATHS=(
    "$LIBPQXX_LIBDIR/libpqxx.a"
    "$LIBPQ_LIBDIR/libpq.a"
    "/usr/lib/$ARCH-linux-gnu/libpqxx.a"
    "/usr/lib/$ARCH-linux-gnu/libpq.a"
    "/usr/lib/libpqxx.a"
    "/usr/lib/libpq.a"
)

for static_lib in "${STATIC_PATHS[@]}"; do
    if [[ -f "$static_lib" ]]; then
        STATIC_LIBS_AVAILABLE=true
        break
    fi
done

if [[ "$STATIC_LIBS_AVAILABLE" == "true" ]]; then
    info "Static libraries available for static linking"
fi

if [[ "$BUNDLE_METHOD" == "static" ]]; then
    if [[ "$STATIC_LIBS_AVAILABLE" == "false" ]]; then
        error "Static linking requested but static libraries not found.
Try installing static development packages:
    Ubuntu/Debian: sudo apt-get install libpqxx-dev libpq-dev (static libs often included)
    Fedora/RHEL:   sudo dnf install libpqxx-static libpq-devel-static  
    Arch Linux:    Static libraries usually included in main packages"
    fi
    info "Using static linking"
    export BUNDLE_METHOD_ACTUAL="static"
elif [[ "$BUNDLE_METHOD" == "dynamic" ]]; then
    info "Using dynamic linking with bundled libraries"
    export BUNDLE_METHOD_ACTUAL="dynamic"
else
    # Auto mode
    if [[ "$STATIC_LIBS_AVAILABLE" == "true" ]]; then
        info "Auto mode: Using static linking (static libraries available)"
        export BUNDLE_METHOD_ACTUAL="static"
    else
        info "Auto mode: Using dynamic linking with bundled libraries"
        export BUNDLE_METHOD_ACTUAL="dynamic"
    fi
fi

# Set environment variables for build
export BUNDLE_DEPENDENCIES="$BUNDLE_DEPENDENCIES"
export TARGET_ARCH="$ARCH"

# Set verbose flags
SCONS_FLAGS=""
if [[ "$VERBOSE" == "true" ]]; then
    SCONS_FLAGS="--debug=explain"
fi

# Detect CPU count for parallel builds
NPROC_COUNT=$(nproc 2>/dev/null || echo "4")

# Build godot-cpp first
info ""
info "Building godot-cpp..."
cd godot-cpp

if [[ "$BUILD_TYPE" == "both" ]] || [[ "$BUILD_TYPE" == "debug" ]]; then
    info "  Building godot-cpp debug..."
    scons platform=linux target=template_debug arch="$ARCH" -j"$NPROC_COUNT" $SCONS_FLAGS || error "Failed to build godot-cpp debug"
fi

if [[ "$BUILD_TYPE" == "both" ]] || [[ "$BUILD_TYPE" == "release" ]]; then
    info "  Building godot-cpp release..."
    scons platform=linux target=template_release arch="$ARCH" -j"$NPROC_COUNT" $SCONS_FLAGS || error "Failed to build godot-cpp release"
fi

cd ..

# Build the extension
info ""
info "Building PostgreSQL extension..."

if [[ "$BUILD_TYPE" == "both" ]] || [[ "$BUILD_TYPE" == "debug" ]]; then
    info "  Building extension debug..."
    scons platform=linux target=template_debug arch="$ARCH" -j"$NPROC_COUNT" $SCONS_FLAGS || error "Failed to build PostgreSQL extension debug"
    success "Debug build completed"
fi

if [[ "$BUILD_TYPE" == "both" ]] || [[ "$BUILD_TYPE" == "release" ]]; then
    info "  Building extension release..."
    scons platform=linux target=template_release arch="$ARCH" -j"$NPROC_COUNT" $SCONS_FLAGS || error "Failed to build PostgreSQL extension release"
    success "Release build completed"
fi

# Bundle dependencies function
bundle_library_dependencies() {
    local SO_PATH="$1"
    local SO_DIR=$(dirname "$SO_PATH")
    
    if [[ ! -f "$SO_PATH" ]]; then
        warning "Library not found: $SO_PATH"
        return 1
    fi
    
    info "Bundling dependencies for: $(basename "$SO_PATH")"
    
    # Create libs subdirectory
    local LIBS_DIR="$SO_DIR/libs"
    mkdir -p "$LIBS_DIR"
    
    # Find required libraries
    local REQUIRED_LIBS=(
        "libpqxx"
        "libpq" 
        "libssl"
        "libcrypto"
    )
    
    # Function to find library file
    find_library() {
        local lib_name="$1"
        local search_paths=(
            "$LIBPQXX_LIBDIR"
            "$LIBPQ_LIBDIR"
            "/usr/lib/$ARCH-linux-gnu"
            "/usr/lib64"
            "/usr/lib"
            "/lib/$ARCH-linux-gnu"
            "/lib64"
            "/lib"
        )
        
        for path in "${search_paths[@]}"; do
            if [[ -f "$path/${lib_name}.so" ]]; then
                echo "$path/${lib_name}.so"
                return 0
            fi
            # Check for versioned libraries
            local versioned=$(find "$path" -name "${lib_name}.so.*" 2>/dev/null | head -1)
            if [[ -n "$versioned" ]]; then
                echo "$versioned"
                return 0
            fi
        done
        return 1
    }
    
    for lib in "${REQUIRED_LIBS[@]}"; do
        local lib_path=$(find_library "$lib")
        if [[ -n "$lib_path" ]]; then
            local dest_path="$LIBS_DIR/$(basename "$lib_path")"
            cp "$lib_path" "$dest_path"
            info "  Copied: $(basename "$lib_path")"
            
            # Set appropriate permissions
            chmod 755 "$dest_path"
        else
            if [[ "$lib" == "libpqxx" ]] || [[ "$lib" == "libpq" ]]; then
                warning "Required library not found: $lib"
            else
                info "  Optional library not found: $lib (may be system-provided)"
            fi
        fi
    done
    
    # Set RPATH to look in libs subdirectory
    if command -v patchelf &> /dev/null; then
        info "  Setting RPATH..."
        patchelf --set-rpath '$ORIGIN/libs:$ORIGIN' "$SO_PATH" 2>/dev/null || true
    else
        warning "patchelf not found - cannot set RPATH. Install with: apt install patchelf"
        info "  Adding RPATH using linker flags in future builds..."
    fi
    
    # Verify dependencies
    info "  Verifying library dependencies..."
    ldd "$SO_PATH" | grep -E "(libpq|libpqxx|libssl|libcrypto)" | while read -r line; do
        if [[ "$line" =~ "not found" ]]; then
            warning "    ⚠ Missing dependency: $(echo "$line" | awk '{print $1}')"
        else
            local dep_path=$(echo "$line" | awk '{print $3}')
            if [[ "$dep_path" =~ ^$SO_DIR/libs/ ]] || [[ "$dep_path" =~ \$ORIGIN ]]; then
                info "    ✓ Bundled: $(echo "$line" | awk '{print $1}')"
            else
                info "    → System: $(echo "$line" | awk '{print $1}') ($dep_path)"
            fi
        fi
    done
}

# Bundle dependencies for shared libraries if using dynamic linking
if [[ "$BUNDLE_METHOD_ACTUAL" == "dynamic" ]]; then
    info ""
    info "Bundling library dependencies..."
    
    for so_file in demo/bin/PostgreAdapter/*.so; do
        if [[ -f "$so_file" ]]; then
            bundle_library_dependencies "$so_file"
        fi
    done
fi

info ""
info "============================================================"
success "BUILD COMPLETED SUCCESSFULLY!"
info "============================================================"

# Show build outputs
info "Built libraries:"
for so_file in demo/bin/PostgreAdapter/*.so; do
    if [[ -f "$so_file" ]]; then
        info "  $so_file"
        
        # Show library size
        local SIZE=$(du -sh "$so_file" | cut -f1)
        info "    Size: $SIZE"
        
        # Show architecture
        local ARCH_INFO=$(file "$so_file" | grep -o 'x86-64\|aarch64\|i386' || echo "Unknown")
        info "    Architecture: $ARCH_INFO"
        
        # Show bundled libraries
        local LIBS_DIR="$(dirname "$so_file")/libs"
        if [[ -d "$LIBS_DIR" ]]; then
            local LIB_COUNT=$(ls "$LIBS_DIR"/*.so* 2>/dev/null | wc -l || echo 0)
            info "    Bundled libraries: $LIB_COUNT"
        fi
    fi
done

info ""
info "NEXT STEPS:"
info "  1. Open your Godot project"
info "  2. The plugin should now load without dependency errors"
info "  3. Configure your PostgreSQL connection string"
info "  4. Test the plugin functionality"

if [[ "$BUNDLE_METHOD_ACTUAL" == "static" ]]; then
    info ""
    success "Built with static linking - libraries are fully self-contained"
else
    info ""
    success "Built with dynamic bundling - all dependencies included with libraries"
    info "Note: Include both .so files and libs/ directory when distributing"
fi

info ""
info "For distribution, include all files from: demo/bin/PostgreAdapter/"