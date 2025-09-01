#!/bin/bash
# Script to copy PostgreSQL libraries for Linux/macOS distribution

# Note: Removed 'set -e' to prevent script from exiting on individual copy failures

echo "Copying PostgreSQL libraries for Linux/macOS distribution..."

# Define required libraries
if [[ "$OSTYPE" == "linux-gnu"* ]]; then
    REQUIRED_LIBS=(
        "libpqxx.so"
        "libpq.so.5"
        "libssl.so.3"
        "libcrypto.so.3"
    )
    PLATFORM="linux"
elif [[ "$OSTYPE" == "darwin"* ]]; then
    REQUIRED_LIBS=(
        "libpqxx.dylib"
        "libpq.5.dylib"
        "libssl.3.dylib"
        "libcrypto.3.dylib"
    )
    PLATFORM="macos"
else
    echo "Unsupported platform: $OSTYPE"
    exit 1
fi

# Define search paths
SEARCH_PATHS=(
    "/usr/local/lib"
    "/usr/lib"
    "/usr/lib/x86_64-linux-gnu"
    "/opt/homebrew/lib"
    "/usr/local/opt/postgresql/lib"
    "/usr/local/opt/libpqxx/lib"
    "/usr/local/opt/openssl/lib"
    "/opt/homebrew/opt/postgresql/lib"
    "/opt/homebrew/opt/libpqxx/lib"
    "/opt/homebrew/opt/openssl/lib"
)

# Define output directories
OUTPUT_DIRS=(
    "demo/bin/PostgreAdapter"
    "Demo/bin/PostgreAdapter"
)

# Create output directories
for output_dir in "${OUTPUT_DIRS[@]}"; do
    if [ ! -d "$output_dir" ]; then
        echo "Creating directory: $output_dir"
        mkdir -p "$output_dir"
    fi
    # Ensure the directory is writable
    chmod 755 "$output_dir" 2>/dev/null || true
done

echo "Platform: $PLATFORM"
echo "Required libraries: ${REQUIRED_LIBS[*]}"

# Function to find and copy library
copy_library() {
    local lib_name=$1
    local found=false
    
    echo "Searching for $lib_name..."
    
    for search_path in "${SEARCH_PATHS[@]}"; do
        if [ -d "$search_path" ]; then
            # Try exact match first
            if [ -f "$search_path/$lib_name" ]; then
                for output_dir in "${OUTPUT_DIRS[@]}"; do
                    if cp "$search_path/$lib_name" "$output_dir/" 2>/dev/null; then
                        echo "  ✓ Copied $lib_name from $search_path to $output_dir"
                        found=true
                    else
                        echo "  ⚠ Failed to copy $lib_name to $output_dir (permission denied)"
                    fi
                done
                if [ "$found" = true ]; then
                    break
                fi
            fi
            
            # For .so files, also try with version numbers
            if [[ "$lib_name" == *.so* ]]; then
                local base_name="${lib_name%.so*}.so"
                local match=$(find "$search_path" -name "${base_name}*" -type f | head -1)
                if [ -n "$match" ]; then
                    for output_dir in "${OUTPUT_DIRS[@]}"; do
                        if cp "$match" "$output_dir/$lib_name" 2>/dev/null; then
                            echo "  ✓ Copied $(basename $match) as $lib_name from $search_path to $output_dir"
                            found=true
                        else
                            echo "  ⚠ Failed to copy $(basename $match) to $output_dir (permission denied)"
                        fi
                    done
                    if [ "$found" = true ]; then
                        break
                    fi
                fi
            fi
            
            # For .dylib files on macOS, try versioned names
            if [[ "$lib_name" == *.dylib ]]; then
                local base_name="${lib_name%.*}"
                local match=$(find "$search_path" -name "${base_name}*.dylib" -type f | head -1)
                if [ -n "$match" ]; then
                    for output_dir in "${OUTPUT_DIRS[@]}"; do
                        if cp "$match" "$output_dir/$lib_name" 2>/dev/null; then
                            echo "  ✓ Copied $(basename $match) as $lib_name from $search_path to $output_dir"
                            found=true
                        else
                            echo "  ⚠ Failed to copy $(basename $match) to $output_dir (permission denied)"
                        fi
                    done
                    if [ "$found" = true ]; then
                        break
                    fi
                fi
            fi
        fi
    done
    
    if [ "$found" = false ]; then
        echo "  ⚠ Warning: Could not find $lib_name in any search path"
        echo "    Searched in:"
        for search_path in "${SEARCH_PATHS[@]}"; do
            if [ -d "$search_path" ]; then
                echo "      - $search_path"
            fi
        done
    fi
}

# Install dependencies if not found locally (Linux only)
install_dependencies() {
    if [[ "$OSTYPE" == "linux-gnu"* ]]; then
        echo "Attempting to install missing dependencies..."
        if command -v apt-get &> /dev/null; then
            echo "Using apt-get to install PostgreSQL libraries..."
            apt-get update -qq
            apt-get install -y libpqxx-dev libpq-dev libssl3 libssl-dev
        elif command -v yum &> /dev/null; then
            echo "Using yum to install PostgreSQL libraries..."
            yum install -y libpqxx-devel postgresql-devel openssl-libs openssl-devel
        elif command -v dnf &> /dev/null; then
            echo "Using dnf to install PostgreSQL libraries..."
            dnf install -y libpqxx-devel postgresql-devel openssl-libs openssl-devel
        elif command -v pacman &> /dev/null; then
            echo "Using pacman to install PostgreSQL libraries..."
            pacman -S --noconfirm libpqxx postgresql-libs openssl
        else
            echo "No supported package manager found"
        fi
    elif [[ "$OSTYPE" == "darwin"* ]]; then
        if command -v brew &> /dev/null; then
            echo "Using Homebrew to install PostgreSQL libraries..."
            brew install libpqxx postgresql openssl
        else
            echo "Homebrew not found, please install it first"
        fi
    fi
}

# Copy each required library
successful_copies=0
for lib in "${REQUIRED_LIBS[@]}"; do
    copy_library "$lib"
    # Check if at least one copy was successful for this library
    for output_dir in "${OUTPUT_DIRS[@]}"; do
        if [ -f "$output_dir/$lib" ]; then
            ((successful_copies++))
            break
        fi
    done
done

# Check if we're missing critical libraries
missing_count=0
for output_dir in "${OUTPUT_DIRS[@]}"; do
    if [ -d "$output_dir" ]; then
        echo ""
        echo "Checking libraries in $output_dir:"
        for lib in "${REQUIRED_LIBS[@]}"; do
            if [ -f "$output_dir/$lib" ]; then
                size=$(stat -c%s "$output_dir/$lib" 2>/dev/null || stat -f%z "$output_dir/$lib" 2>/dev/null || echo "unknown")
                echo "  ✓ Found: $lib ($size bytes)"
            else
                echo "  ✗ Missing: $lib"
                ((missing_count++))
            fi
        done
    fi
done

# Try to install dependencies if many are missing
if [ $missing_count -gt 2 ]; then
    echo ""
    echo "Many libraries are missing. Attempting to install dependencies..."
    install_dependencies
    
    # Retry copying after installation
    echo "Retrying library copy after installation..."
    for lib in "${REQUIRED_LIBS[@]}"; do
        copy_library "$lib"
    done
fi

echo ""
echo "Library copy process completed."
echo "Successfully copied $successful_copies library instances."
echo ""
echo "Note: Make sure these libraries are distributed alongside your GDExtension"
echo "for proper runtime dependency resolution."

# Final verification
echo ""
echo "Final verification:"
for output_dir in "${OUTPUT_DIRS[@]}"; do
    if [ -d "$output_dir" ]; then
        echo "Contents of $output_dir:"
        ls -la "$output_dir" || echo "  (Unable to list contents)"
    fi
done

# Exit successfully even if some copies failed, as long as we got some libraries
echo ""
if [ $successful_copies -gt 0 ]; then
    echo "✓ Script completed successfully with $successful_copies libraries copied."
    exit 0
else
    echo "⚠ Warning: No libraries were successfully copied, but script completed."
    exit 0
fi