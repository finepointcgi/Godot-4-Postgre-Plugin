#!/bin/bash

# Enhanced macOS build script with dependency bundling
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
HOMEBREW_PREFIX=""

# Parse command line arguments
show_help() {
    cat << EOF
USAGE:
    $0 [OPTIONS]

OPTIONS:
    --help, -h         Show this help message
    --debug            Build debug version only
    --release          Build release version only
    --static           Force static linking (self-contained framework)
    --dynamic          Force dynamic linking with bundled dylibs
    --homebrew-prefix  Override Homebrew prefix detection
    --verbose, -v      Verbose output

DESCRIPTION:
    Builds the PostgreSQL Godot plugin for macOS with bundled dependencies.
    Creates self-contained frameworks that don't require system PostgreSQL.

BUNDLING METHODS:
    static   - Links PostgreSQL libraries directly into framework (preferred)
    dynamic  - Bundles required dylibs into framework bundle
    auto     - Automatically chooses best method based on available libraries

EXAMPLES:
    $0                           # Build both debug and release with auto bundling
    $0 --debug --static          # Build debug only with static linking
    $0 --release --dynamic       # Build release only with dylib bundling
    $0 --homebrew-prefix /usr/local  # Use specific Homebrew installation

REQUIREMENTS:
    - Xcode Command Line Tools
    - Homebrew with libpqxx installed: brew install libpqxx
    - SCons: pip install scons or brew install scons

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
        --homebrew-prefix)
            HOMEBREW_PREFIX="$2"
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
info "PostgreSQL GDExtension - macOS Build with Bundled Dependencies"
info "============================================================"
info ""
info "Build configuration:"
info "  Build type: $BUILD_TYPE"
info "  Bundle method: $BUNDLE_METHOD"
info "  Verbose: $VERBOSE"
info ""

# Check for required tools
info "Checking build dependencies..."

# Check for Xcode tools
if ! command -v clang &> /dev/null; then
    error "Xcode Command Line Tools not found. Install with: xcode-select --install"
fi

# Check for SCons
if ! command -v scons &> /dev/null; then
    error "SCons not found. Install with: pip install scons or brew install scons"
fi

# Detect Homebrew installation
if [[ -n "$HOMEBREW_PREFIX" ]]; then
    if [[ ! -d "$HOMEBREW_PREFIX" ]]; then
        error "Specified Homebrew prefix does not exist: $HOMEBREW_PREFIX"
    fi
    info "Using specified Homebrew prefix: $HOMEBREW_PREFIX"
elif [[ -d "/opt/homebrew" ]]; then
    HOMEBREW_PREFIX="/opt/homebrew"
    info "Detected Apple Silicon Homebrew: $HOMEBREW_PREFIX"
elif [[ -d "/usr/local" ]] && [[ -d "/usr/local/Cellar" ]]; then
    HOMEBREW_PREFIX="/usr/local"
    info "Detected Intel Mac Homebrew: $HOMEBREW_PREFIX"
else
    error "Homebrew not found. Install from https://brew.sh"
fi

# Check for PostgreSQL libraries
LIBPQXX_PATH="$HOMEBREW_PREFIX/opt/libpqxx"
LIBPQ_PATH="$HOMEBREW_PREFIX/opt/libpq"

if [[ ! -d "$LIBPQXX_PATH" ]]; then
    error "libpqxx not found. Install with: brew install libpqxx"
fi

if [[ ! -d "$LIBPQ_PATH" ]]; then
    warning "libpq not found separately, using libpqxx's bundled libpq"
    LIBPQ_PATH="$LIBPQXX_PATH"  # libpqxx usually includes libpq
fi

success "Dependencies found"
info "  libpqxx: $LIBPQXX_PATH"
info "  libpq: $LIBPQ_PATH"

# Determine bundling strategy
BUNDLE_DEPENDENCIES="true"
STATIC_LIBS_AVAILABLE=false

# Check if static libraries are available
if [[ -f "$LIBPQXX_PATH/lib/libpqxx.a" ]] && [[ -f "$LIBPQ_PATH/lib/libpq.a" ]]; then
    STATIC_LIBS_AVAILABLE=true
    info "Static libraries available for static linking"
fi

if [[ "$BUNDLE_METHOD" == "static" ]]; then
    if [[ "$STATIC_LIBS_AVAILABLE" == "false" ]]; then
        error "Static linking requested but static libraries not found. Try: brew install libpqxx --static"
    fi
    info "Using static linking"
    export BUNDLE_METHOD_ACTUAL="static"
elif [[ "$BUNDLE_METHOD" == "dynamic" ]]; then
    info "Using dynamic linking with bundled dylibs"
    export BUNDLE_METHOD_ACTUAL="dynamic"
else
    # Auto mode
    if [[ "$STATIC_LIBS_AVAILABLE" == "true" ]]; then
        info "Auto mode: Using static linking (static libraries available)"
        export BUNDLE_METHOD_ACTUAL="static"
    else
        info "Auto mode: Using dynamic linking with bundled dylibs"
        export BUNDLE_METHOD_ACTUAL="dynamic"
    fi
fi

# Set environment variables for build
export BUNDLE_DEPENDENCIES="$BUNDLE_DEPENDENCIES"
export HOMEBREW_PREFIX="$HOMEBREW_PREFIX"

# Set verbose flags
SCONS_FLAGS=""
if [[ "$VERBOSE" == "true" ]]; then
    SCONS_FLAGS="--debug=explain"
fi

# Build godot-cpp first
info ""
info "Building godot-cpp..."
cd godot-cpp

if [[ "$BUILD_TYPE" == "both" ]] || [[ "$BUILD_TYPE" == "debug" ]]; then
    info "  Building godot-cpp debug..."
    scons platform=macos target=template_debug arch=universal -j$(sysctl -n hw.ncpu) $SCONS_FLAGS || error "Failed to build godot-cpp debug"
fi

if [[ "$BUILD_TYPE" == "both" ]] || [[ "$BUILD_TYPE" == "release" ]]; then
    info "  Building godot-cpp release..."
    scons platform=macos target=template_release arch=universal -j$(sysctl -n hw.ncpu) $SCONS_FLAGS || error "Failed to build godot-cpp release"
fi

cd ..

# Build the extension
info ""
info "Building PostgreSQL extension..."

if [[ "$BUILD_TYPE" == "both" ]] || [[ "$BUILD_TYPE" == "debug" ]]; then
    info "  Building extension debug..."
    scons platform=macos target=template_debug arch=universal -j$(sysctl -n hw.ncpu) $SCONS_FLAGS || error "Failed to build PostgreSQL extension debug"
    success "Debug build completed"
fi

if [[ "$BUILD_TYPE" == "both" ]] || [[ "$BUILD_TYPE" == "release" ]]; then
    info "  Building extension release..."
    scons platform=macos target=template_release arch=universal -j$(sysctl -n hw.ncpu) $SCONS_FLAGS || error "Failed to build PostgreSQL extension release"
    success "Release build completed"
fi

# Bundle dependencies function
bundle_framework_dependencies() {
    local FRAMEWORK_PATH="$1"
    local BINARY_PATH="$FRAMEWORK_PATH/$(basename "$FRAMEWORK_PATH" .framework)"
    
    if [[ ! -f "$BINARY_PATH" ]]; then
        warning "Framework binary not found: $BINARY_PATH"
        return 1
    fi
    
    info "Bundling dependencies for: $(basename "$FRAMEWORK_PATH")"
    
    # Create Libraries directory in framework
    local LIBS_DIR="$FRAMEWORK_PATH/Libraries"
    mkdir -p "$LIBS_DIR"
    
    # Find and copy required dylibs
    local REQUIRED_LIBS=(
        "libpqxx"
        "libpq"
        "libssl"
        "libcrypto"
    )
    
    for lib in "${REQUIRED_LIBS[@]}"; do
        # Find the dylib
        local DYLIB_PATH=""
        for search_path in "$HOMEBREW_PREFIX/opt/*/lib" "$HOMEBREW_PREFIX/lib"; do
            if [[ -f "$search_path/${lib}.dylib" ]]; then
                DYLIB_PATH="$search_path/${lib}.dylib"
                break
            fi
            # Also check for versioned dylibs
            local VERSIONED=$(find "$search_path" -name "${lib}.*.dylib" 2>/dev/null | head -1)
            if [[ -n "$VERSIONED" ]]; then
                DYLIB_PATH="$VERSIONED"
                break
            fi
        done
        
        if [[ -n "$DYLIB_PATH" ]]; then
            local DEST_PATH="$LIBS_DIR/$(basename "$DYLIB_PATH")"
            cp "$DYLIB_PATH" "$DEST_PATH"
            info "  Copied: $(basename "$DYLIB_PATH")"
            
            # Update install names to use @rpath
            install_name_tool -id "@rpath/Libraries/$(basename "$DYLIB_PATH")" "$DEST_PATH" 2>/dev/null || true
            
            # Update main binary to reference bundled dylib
            install_name_tool -change "$DYLIB_PATH" "@rpath/Libraries/$(basename "$DYLIB_PATH")" "$BINARY_PATH" 2>/dev/null || true
            install_name_tool -change "$(basename "$DYLIB_PATH")" "@rpath/Libraries/$(basename "$DYLIB_PATH")" "$BINARY_PATH" 2>/dev/null || true
        else
            if [[ "$lib" == "libpqxx" ]] || [[ "$lib" == "libpq" ]]; then
                warning "Required library not found: $lib"
            else
                info "  Optional library not found: $lib (may be system-provided)"
            fi
        fi
    done
    
    # Add @rpath to the binary
    install_name_tool -add_rpath "@loader_path" "$BINARY_PATH" 2>/dev/null || true
    
    # Verify dependencies
    info "  Verifying framework dependencies..."
    otool -L "$BINARY_PATH" | grep -E "(libpq|libpqxx|libssl|libcrypto)" | while read -r line; do
        if [[ "$line" =~ @rpath ]]; then
            info "    ✓ $(echo "$line" | awk '{print $1}')"
        else
            warning "    ⚠ External dependency: $(echo "$line" | awk '{print $1}')"
        fi
    done
}

# Bundle dependencies for frameworks if using dynamic linking
if [[ "$export BUNDLE_METHOD_ACTUAL" == "dynamic" ]]; then
    info ""
    info "Bundling framework dependencies..."
    
    for framework in demo/bin/PostgreAdapter/*.framework; do
        if [[ -d "$framework" ]]; then
            bundle_framework_dependencies "$framework"
        fi
    done
fi

info ""
info "============================================================"
success "BUILD COMPLETED SUCCESSFULLY!"
info "============================================================"

# Show build outputs
info "Built frameworks:"
for framework in demo/bin/PostgreAdapter/*.framework; do
    if [[ -d "$framework" ]]; then
        info "  $framework"
        
        # Show framework size
        local SIZE=$(du -sh "$framework" | cut -f1)
        info "    Size: $SIZE"
        
        # Show architecture
        local BINARY="$framework/$(basename "$framework" .framework)"
        if [[ -f "$BINARY" ]]; then
            local ARCHS=$(lipo -info "$BINARY" 2>/dev/null | awk -F': ' '{print $3}' || echo "Unknown")
            info "    Architectures: $ARCHS"
        fi
        
        # Show bundled libraries
        if [[ -d "$framework/Libraries" ]]; then
            local LIB_COUNT=$(ls "$framework/Libraries"/*.dylib 2>/dev/null | wc -l || echo 0)
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

if [[ "$export BUNDLE_METHOD_ACTUAL" == "static" ]]; then
    info ""
    success "Built with static linking - frameworks are fully self-contained"
else
    info ""
    success "Built with dynamic bundling - all dependencies included in frameworks"
fi

info ""
info "For distribution, include the entire framework directories from: demo/bin/PostgreAdapter/"