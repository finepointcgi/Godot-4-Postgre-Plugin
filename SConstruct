#!/usr/bin/env python
import os
import sys
import subprocess

# Set godot-cpp path
godot_cpp_path = os.path.join(os.getcwd(), "godot-cpp")
os.environ['GODOT_CPP_PATH'] = godot_cpp_path

env = SConscript("godot-cpp/SConstruct")

# Add godot-cpp includes
env.Append(CPPPATH=[
    os.path.join(godot_cpp_path, "include"),
    os.path.join(godot_cpp_path, "gen", "include"),
])

# Platform-specific PostgreSQL library configuration
def configure_postgresql_libs(env):
    platform = env["platform"]
    
    if platform == "macos":
        # macOS with Homebrew
        homebrew_prefix = os.environ.get("HOMEBREW_PREFIX", "")
        if not homebrew_prefix:
            homebrew_prefix = "/opt/homebrew" if os.path.exists("/opt/homebrew") else "/usr/local"
        
        bundle_deps = os.environ.get("BUNDLE_DEPENDENCIES", "true").lower() == "true"
        bundle_method = os.environ.get("BUNDLE_METHOD_ACTUAL", "auto")
        
        # Check build architecture - if universal requested, check if libs support it
        build_arch = env.get("arch", "universal")
        
        print("macOS Homebrew prefix: {}".format(homebrew_prefix))
        print("Bundle dependencies: {}".format(bundle_deps))
        print("Bundle method: {}".format(bundle_method))
        print("Build architecture: {}".format(build_arch))
        
        # Check if libraries exist and what architectures they support
        libpqxx_path = os.path.join(homebrew_prefix, "opt", "libpqxx", "lib", "libpqxx.dylib")
        if os.path.exists(libpqxx_path):
            try:
                # Check library architecture
                lipo_output = subprocess.check_output(["lipo", "-info", libpqxx_path], universal_newlines=True)
                print("libpqxx architecture: {}".format(lipo_output.strip()))
                
                # Always use the architecture that matches available libraries
                if "arm64" in lipo_output and "x86_64" not in lipo_output:
                    print("Homebrew libraries are ARM64-only, forcing arm64 build")
                    env["arch"] = "arm64"
                elif "x86_64" in lipo_output and "arm64" not in lipo_output:
                    print("Homebrew libraries are x86_64-only, forcing x86_64 build")
                    env["arch"] = "x86_64"
                elif build_arch == "universal" and "arm64" in lipo_output and "x86_64" in lipo_output:
                    print("Libraries support universal build, keeping universal")
                else:
                    # Default to native architecture if uncertain
                    import platform
                    native_arch = "arm64" if platform.machine() == "arm64" else "x86_64"
                    print("Using native architecture: {}".format(native_arch))
                    env["arch"] = native_arch
            except (subprocess.CalledProcessError, OSError):
                print("Could not check library architecture, using native arch")
                import platform
                native_arch = "arm64" if platform.machine() == "arm64" else "x86_64"
                env["arch"] = native_arch
        
        env.Append(CPPPATH=[
            os.path.join(homebrew_prefix, "opt", "libpqxx", "include"),
            os.path.join(homebrew_prefix, "opt", "libpq", "include")
        ])
        env.Append(LIBPATH=[
            os.path.join(homebrew_prefix, "opt", "libpqxx", "lib"),
            os.path.join(homebrew_prefix, "opt", "libpq", "lib")
        ])
        
        # Configure linking method - prefer static for self-contained builds
        bundle_method = os.environ.get("BUNDLE_METHOD", "static")
        
        if bundle_method == "static":
            # Try static linking first for self-contained framework
            static_libs = [
                os.path.join(homebrew_prefix, "opt", "libpqxx", "lib", "libpqxx.a"),
                os.path.join(homebrew_prefix, "opt", "libpq", "lib", "libpq.a")
            ]
            
            # Also check for OpenSSL static libraries
            ssl_static_libs = [
                os.path.join(homebrew_prefix, "opt", "openssl@3", "lib", "libssl.a"),
                os.path.join(homebrew_prefix, "opt", "openssl@3", "lib", "libcrypto.a"),
                os.path.join(homebrew_prefix, "opt", "openssl@1.1", "lib", "libssl.a"),
                os.path.join(homebrew_prefix, "opt", "openssl@1.1", "lib", "libcrypto.a"),
                os.path.join(homebrew_prefix, "opt", "openssl", "lib", "libssl.a"),
                os.path.join(homebrew_prefix, "opt", "openssl", "lib", "libcrypto.a")
            ]
            
            found_ssl_static = any(os.path.exists(lib) for lib in ssl_static_libs)
            
            if all(os.path.exists(lib) for lib in static_libs):
                env.Append(LIBS=["pqxx", "pq"])
                
                # Add SSL libraries if available statically
                if found_ssl_static:
                    env.Append(LIBS=["ssl", "crypto"])
                    print("Using static linking for macOS (including SSL)")
                else:
                    print("Using static linking for macOS (PostgreSQL only, SSL will be dynamic)")
                
                # Additional system libraries needed for static PostgreSQL
                env.Append(LIBS=["iconv", "intl"])
                env.Append(LINKFLAGS=["-static-libstdc++", "-static-libgcc"])
                bundle_deps = False  # No bundling needed with static linking
                
            else:
                print("Static libraries not found, falling back to dynamic linking")
                bundle_method = "dynamic"
                bundle_deps = True
        
        if bundle_method != "static":
            # Dynamic linking - will be bundled post-build
            env.Append(LIBS=["pqxx", "pq"])
            bundle_deps = True
        
        # Store bundle settings for post-build actions
        env["bundle_deps"] = bundle_deps
        env["bundle_method"] = bundle_method
        
    elif platform == "linux":
        # Linux - try to find PostgreSQL via pkg-config
        bundle_deps = os.environ.get("BUNDLE_DEPENDENCIES", "true").lower() == "true"
        bundle_method = os.environ.get("BUNDLE_METHOD_ACTUAL", "auto")
        target_arch = os.environ.get("TARGET_ARCH", "x86_64")
        
        print("Bundle dependencies: {}".format(bundle_deps))
        print("Bundle method: {}".format(bundle_method))
        print("Target architecture: {}".format(target_arch))
        
        try:
            # Get libpqxx flags
            pqxx_cflags = subprocess.check_output(["pkg-config", "--cflags", "libpqxx"], universal_newlines=True).strip()
            pqxx_libs = subprocess.check_output(["pkg-config", "--libs", "libpqxx"], universal_newlines=True).strip()
            
            # Parse flags
            env.ParseFlags(pqxx_cflags)
            env.ParseFlags(pqxx_libs)
            
            # Check for static libraries if static linking requested
            if bundle_deps and bundle_method == "static":
                try:
                    static_libs = subprocess.check_output(["pkg-config", "--libs", "--static", "libpqxx"], universal_newlines=True).strip()
                    env.ParseFlags(static_libs)
                    print("Using static linking for Linux")
                except subprocess.CalledProcessError:
                    print("Static linking not available via pkg-config, falling back to dynamic")
                    bundle_method = "dynamic"
            
        except subprocess.CalledProcessError:
            # Fallback to standard paths
            print("pkg-config not available, using fallback paths")
            env.Append(CPPPATH=["/usr/include/pqxx", "/usr/include/postgresql"])
            
            # Architecture-specific library paths 
            arch_mapping = {
                "x86_64": "x86_64",
                "arm64": "aarch64",  # ARM64 uses aarch64 in library paths
                "aarch64": "aarch64"
            }
            lib_arch = arch_mapping.get(target_arch, target_arch)
            
            if lib_arch == "x86_64":
                env.Append(LIBPATH=["/usr/lib/x86_64-linux-gnu", "/usr/lib64", "/usr/lib"])
            elif lib_arch == "aarch64":
                env.Append(LIBPATH=["/usr/lib/aarch64-linux-gnu", "/usr/lib64", "/usr/lib"])
            else:
                env.Append(LIBPATH=["/usr/lib", "/usr/lib64"])
                
        # Add RPATH for bundled libraries if dynamic linking
        if bundle_deps and bundle_method != "static":
            env.Append(LINKFLAGS=["-Wl,-rpath,$ORIGIN/libs", "-Wl,-rpath,$ORIGIN"])
            
        # Store bundle settings for post-build actions
        env["bundle_deps"] = bundle_deps
        env["bundle_method"] = bundle_method
            
    elif platform == "windows":
        # Windows - Prefer static linking for self-contained DLL
        pg_path = os.environ.get("POSTGRESQL_PATH", "C:\\Program Files\\PostgreSQL\\16")
        vcpkg_root = os.environ.get("VCPKG_ROOT", "")
        bundle_method = os.environ.get("BUNDLE_METHOD", "static")
        
        bundle_deps = bundle_method != "static"
        print("Windows build: Attempting static linking for self-contained DLL")
        print("PostgreSQL path: {}".format(pg_path))
        print("vcpkg root: {}".format(vcpkg_root))
        print("Bundle method: {}".format(bundle_method))
        
        env.Append(CPPPATH=[
            os.path.join(pg_path, "include")
        ])
        env.Append(LIBPATH=[os.path.join(pg_path, "lib")])
        
        # Check for available libraries and determine linking strategy
        available_libs = []
        lib_search_paths = []
        
        # Use vcpkg toolchain if available
        if vcpkg_root:
            vcpkg_lib_path = os.path.join(vcpkg_root, "installed", "x64-windows", "lib")
            vcpkg_inc_path = os.path.join(vcpkg_root, "installed", "x64-windows", "include")
            
            env.Append(CPPPATH=[vcpkg_inc_path])
            env.Append(LIBPATH=[vcpkg_lib_path])
            lib_search_paths.append(vcpkg_lib_path)
            
            if bundle_method == "static":
                print("Using vcpkg static linking")
            else:
                print("Using vcpkg dynamic linking with DLL bundling")
        
        # Add PostgreSQL paths
        pg_lib_path = os.path.join(pg_path, "lib")
        lib_search_paths.append(pg_lib_path)
        
        # Check for libpqxx availability (C++ wrapper) - prefer static
        libpqxx_found = False
        static_libs_found = []
        
        for search_path in lib_search_paths:
            # Try static libraries first if static linking requested
            if bundle_method == "static":
                static_candidates = ["pqxx_static.lib", "libpqxx_static.lib", "pqxx.lib", "libpqxx.lib"]
            else:
                static_candidates = ["pqxx.lib", "libpqxx.lib", "pqxx_static.lib", "libpqxx_static.lib"]
                
            for lib_name in static_candidates:
                lib_path = os.path.join(search_path, lib_name)
                if os.path.exists(lib_path):
                    libpqxx_found = True
                    lib_clean_name = lib_name.replace("_static", "").replace(".lib", "")
                    if lib_clean_name not in available_libs:
                        available_libs.append(lib_clean_name)
                    
                    is_static = "_static" in lib_name or (bundle_method == "static" and "pqxx" in lib_name)
                    print("Found libpqxx: {} in {} [{}]".format(lib_name, search_path, "static" if is_static else "dynamic"))
                    
                    if is_static:
                        static_libs_found.append(lib_name)
                    break
            if libpqxx_found:
                break
        
        # Check for libpq availability (C client) - prefer static
        libpq_found = False
        for search_path in lib_search_paths:
            if bundle_method == "static":
                pq_candidates = ["libpq_static.lib", "pq_static.lib", "libpq.lib", "pq.lib"]
            else:
                pq_candidates = ["libpq.lib", "pq.lib", "libpq_static.lib", "pq_static.lib"]
                
            for lib_name in pq_candidates:
                lib_path = os.path.join(search_path, lib_name)
                if os.path.exists(lib_path):
                    libpq_found = True
                    lib_clean_name = lib_name.replace("_static", "").replace(".lib", "")
                    if lib_clean_name not in available_libs:
                        available_libs.append(lib_clean_name)
                    
                    is_static = "_static" in lib_name or (bundle_method == "static" and "pq" in lib_name)
                    print("Found libpq: {} in {} [{}]".format(lib_name, search_path, "static" if is_static else "dynamic"))
                    
                    if is_static:
                        static_libs_found.append(lib_name)
                    break
            if libpq_found:
                break
        
        # Configure linking based on what's available
        if libpqxx_found and libpq_found:
            # Configure static vs dynamic linking
            if bundle_method == "static" and static_libs_found:
                # Static linking - add additional Windows libraries needed for static PostgreSQL
                static_system_libs = [
                    "ws2_32", "advapi32", "secur32", "shell32", "wldap32", "crypt32",
                    "user32", "kernel32", "gdi32", "psapi", "bcrypt"
                ]
                
                # Add OpenSSL static libraries if available
                for search_path in lib_search_paths:
                    ssl_static_libs = ["libssl_static.lib", "libcrypto_static.lib",
                                     "ssl.lib", "crypto.lib"]
                    for ssl_lib in ssl_static_libs:
                        if os.path.exists(os.path.join(search_path, ssl_lib)):
                            ssl_clean = ssl_lib.replace("_static", "").replace(".lib", "")
                            if ssl_clean not in available_libs:
                                available_libs.append(ssl_clean)
                            print("Found SSL library: {} [static]".format(ssl_lib))
                
                env.Append(LIBS=available_libs + static_system_libs)
                env.Append(CPPDEFINES=["PQXX_STATIC", "LIBPQ_STATIC"])
                bundle_deps = False  # No need to bundle DLLs with static linking
                print("Using static linking - self-contained DLL with no external dependencies")
                
            else:
                # Dynamic linking fallback
                env.Append(LIBS=available_libs + ["ws2_32", "advapi32"])
                bundle_deps = True
                print("Using dynamic linking - will bundle required DLLs")
                
        elif libpq_found:
            env.Append(LIBS=["libpq", "ws2_32", "advapi32"])
            env.Append(CPPDEFINES=["LIBPQXX_NOT_AVAILABLE"])
            print("WARNING: libpqxx not found, using libpq only")
        else:
            env.Append(LIBS=["libpqxx", "libpq", "ws2_32", "advapi32"])
            print("WARNING: Libraries not found, attempting build with standard names")
        
        # Store bundle flag for later use
        env["bundle_deps"] = bundle_deps
        return  # Skip the common libs addition below
    
    # Common library names for Unix-like systems
    env.Append(LIBS=["pqxx", "pq"])

# Configure PostgreSQL libraries based on platform
configure_postgresql_libs(env)

# Function to copy required DLLs for Windows
def copy_windows_dependencies(env, target):
    if env["platform"] != "windows" or not env.get("bundle_deps", False):
        return
    
    import shutil
    import glob
    
    # Get paths
    pg_path = os.environ.get("POSTGRESQL_PATH", "C:\\Program Files\\PostgreSQL\\16")
    vcpkg_root = os.environ.get("VCPKG_ROOT", "")
    target_dir = os.path.dirname(str(target[0]))
    
    # Comprehensive list of required DLLs for distribution
    required_dlls = [
        "libpq.dll",           # PostgreSQL client library (REQUIRED)
        "pqxx.dll",            # libpqxx C++ wrapper (REQUIRED for C++ code)
    ]
    
    # Alternative names for required DLLs (try if main names not found)
    required_alt_dlls = [
        "libpqxx.dll",         # libpqxx C++ wrapper (alternative name)
        "pq.dll",              # PostgreSQL client (alternative name)
    ]
    
    # SSL/Crypto libraries (REQUIRED for secure connections)
    ssl_dlls = [
        "libcrypto-3-x64.dll", # OpenSSL crypto (v3.x, 64-bit) - preferred
        "libssl-3-x64.dll",    # OpenSSL SSL (v3.x, 64-bit) - preferred
        "libcrypto-1_1-x64.dll", # OpenSSL crypto (v1.1.x, 64-bit)
        "libssl-1_1-x64.dll",    # OpenSSL SSL (v1.1.x, 64-bit)
        "libeay32.dll",        # OpenSSL crypto (legacy)
        "ssleay32.dll",        # OpenSSL SSL (legacy)
    ]
    
    # Additional PostgreSQL dependencies that may be needed
    postgres_support_dlls = [
        "libiconv-2.dll",      # Character encoding conversion
        "libintl-8.dll",       # Internationalization
        "zlib1.dll",           # Compression library
        "libwinpthread-1.dll", # Threading support
    ]
    
    # Visual C++ runtime libraries (may be needed)
    runtime_dlls = [
        "msvcp140.dll",        # Visual C++ 2015-2022 runtime (C++)
        "vcruntime140.dll",    # Visual C++ 2015-2022 runtime
        "vcruntime140_1.dll",  # Visual C++ 2015-2022 runtime (additional)
        "msvcp120.dll",        # Visual C++ 2013 runtime (C++)
        "msvcr120.dll",        # Visual C++ 2013 runtime
    ]
    
    # Combine all DLLs to search for
    optional_dlls = required_alt_dlls + ssl_dlls + postgres_support_dlls + runtime_dlls
    
    print("Copying Windows dependencies to: {}".format(target_dir))
    
    # Search locations for DLLs (comprehensive search)
    search_paths = []
    
    # vcpkg paths (highest priority)
    if vcpkg_root and os.path.exists(vcpkg_root):
        vcpkg_bin = os.path.join(vcpkg_root, "installed", "x64-windows", "bin")
        vcpkg_lib = os.path.join(vcpkg_root, "installed", "x64-windows", "lib")
        if os.path.exists(vcpkg_bin):
            search_paths.append(vcpkg_bin)
        if os.path.exists(vcpkg_lib):
            search_paths.append(vcpkg_lib)
    
    # PostgreSQL installation paths
    if os.path.exists(pg_path):
        pg_bin = os.path.join(pg_path, "bin")
        pg_lib = os.path.join(pg_path, "lib")
        if os.path.exists(pg_bin):
            search_paths.append(pg_bin)
        if os.path.exists(pg_lib):
            search_paths.append(pg_lib)
    
    # Additional PostgreSQL installation locations
    for pg_version in ["16", "15", "14", "13", "12"]:
        pg_alt_path = "C:\\Program Files\\PostgreSQL\\{}".format(pg_version)
        if os.path.exists(pg_alt_path):
            search_paths.extend([
                os.path.join(pg_alt_path, "bin"),
                os.path.join(pg_alt_path, "lib")
            ])
    
    # System paths for OpenSSL and runtime DLLs
    system_paths = [
        "C:\\Windows\\System32",
        os.path.join(os.environ.get("ProgramFiles", "C:\\Program Files"), "OpenSSL-Win64", "bin"),
        os.path.join(os.environ.get("ProgramFiles(x86)", "C:\\Program Files (x86)"), "OpenSSL-Win32", "bin"),
        os.path.join(os.environ.get("ProgramFiles", "C:\\Program Files"), "OpenSSL", "bin"),
    ]
    
    # Add system paths that exist
    for sys_path in system_paths:
        if os.path.exists(sys_path):
            search_paths.append(sys_path)
    
    print("Searching for dependencies in {} locations:".format(len(search_paths)))
    for i, path in enumerate(search_paths[:5]):  # Show first 5 paths
        print("  {}: {}".format(i+1, path))
    if len(search_paths) > 5:
        print("  ... and {} more locations".format(len(search_paths) - 5))
    
    # Track what we copy
    copied_dlls = []
    missing_required = []
    
    # Copy required DLLs first (including alternatives)
    all_required = required_dlls + required_alt_dlls
    for dll in all_required:
        if dll not in copied_dlls:
            found = False
            for search_path in search_paths:
                dll_path = os.path.join(search_path, dll)
                if os.path.exists(dll_path):
                    target_path = os.path.join(target_dir, dll)
                    try:
                        shutil.copy2(dll_path, target_path)
                        if dll in required_dlls:
                            print("  [OK] Copied required: {} -> {}".format(dll, os.path.basename(target_path)))
                        else:
                            print("  [OK] Copied alternative: {} -> {}".format(dll, os.path.basename(target_path)))
                        copied_dlls.append(dll)
                        found = True
                        break
                    except Exception as e:
                        print("  [ERROR] Failed to copy {}: {}".format(dll, e))
            
            if not found and dll in required_dlls:
                print("  [MISSING] Required DLL not found: {}".format(dll))
                missing_required.append(dll)
    
    # Copy SSL libraries (try to get at least one crypto and one SSL)
    crypto_found = False
    ssl_found = False
    for dll in ssl_dlls:
        if dll not in copied_dlls:
            for search_path in search_paths:
                dll_path = os.path.join(search_path, dll)
                if os.path.exists(dll_path):
                    target_path = os.path.join(target_dir, dll)
                    try:
                        shutil.copy2(dll_path, target_path)
                        print("  [OK] Copied SSL/crypto: {} -> {}".format(dll, os.path.basename(target_path)))
                        copied_dlls.append(dll)
                        if "crypto" in dll.lower():
                            crypto_found = True
                        if "ssl" in dll.lower():
                            ssl_found = True
                        break
                    except Exception as e:
                        print("  [ERROR] Failed to copy {}: {}".format(dll, e))
    
    # Copy runtime libraries if needed
    runtime_copied = False
    for dll in runtime_dlls:
        if dll not in copied_dlls and not runtime_copied:
            for search_path in search_paths:
                dll_path = os.path.join(search_path, dll)
                if os.path.exists(dll_path):
                    target_path = os.path.join(target_dir, dll)
                    try:
                        shutil.copy2(dll_path, target_path)
                        print("  [OK] Copied runtime: {} -> {}".format(dll, os.path.basename(target_path)))
                        copied_dlls.append(dll)
                        if "msvcp" in dll or "vcruntime" in dll:
                            runtime_copied = True
                        break
                    except Exception as e:
                        print("  [ERROR] Failed to copy {}: {}".format(dll, e))
    
    # Summary
    print("\nDependency bundling summary:")
    print("  Copied {} DLLs: {}".format(len(copied_dlls), ", ".join(copied_dlls)))
    
    if missing_required:
        print("  [MISSING] Missing required: {}".format(", ".join(missing_required)))
    if not crypto_found:
        print("  [WARNING] No crypto library found")
    if not ssl_found:
        print("  [WARNING] No SSL library found")
    
    # Show final directory contents
    try:
        dll_files = [f for f in os.listdir(target_dir) if f.endswith('.dll')]
        print("  Final plugin directory contains {} DLL files".format(len(dll_files)))
    except Exception:
        pass

# Function to bundle dependencies for macOS frameworks
def bundle_macos_dependencies(env, target):
    if env["platform"] != "macos" or not env.get("bundle_deps", False) or env.get("bundle_method") == "static":
        return
    
    import shutil
    import subprocess
    
    target_path = str(target[0])
    
    # Fix framework path detection
    if ".framework/" in target_path:
        # Path like: demo/bin/PostgreAdapter/libpostgreadapter.macos.template_debug.framework/libpostgreadapter.macos.template_debug
        framework_path = target_path[:target_path.find(".framework") + len(".framework")]
        binary_path = target_path
    else:
        # Fallback
        framework_path = os.path.dirname(target_path)
        binary_path = target_path
    
    homebrew_prefix = os.environ.get("HOMEBREW_PREFIX", "/opt/homebrew" if os.path.exists("/opt/homebrew") else "/usr/local")
    
    print("Bundling macOS dependencies for: {}".format(os.path.basename(framework_path)))
    print("Framework path: {}".format(framework_path))
    print("Binary path: {}".format(binary_path))
    
    # Create Libraries directory in framework
    libs_dir = os.path.join(framework_path, "Libraries")
    try:
        os.makedirs(libs_dir, exist_ok=True)
    except Exception as e:
        print("Error creating Libraries directory: {}".format(e))
        return
    
    # Required libraries
    required_libs = ["libpqxx", "libpq", "libssl", "libcrypto"]
    
    # Additional support libraries that may be needed on macOS
    support_libs = ["libiconv", "libintl", "libz"]
    
    # Copy all required and support libraries
    all_libs = required_libs + support_libs
    for lib in all_libs:
        # Search for dylib - more comprehensive search
        search_paths = [
            os.path.join(homebrew_prefix, "opt", "libpqxx", "lib"),
            os.path.join(homebrew_prefix, "opt", "libpq", "lib"),
            os.path.join(homebrew_prefix, "opt", "openssl@3", "lib"),  # OpenSSL 3.x
            os.path.join(homebrew_prefix, "opt", "openssl@1.1", "lib"), # OpenSSL 1.1.x
            os.path.join(homebrew_prefix, "opt", "openssl", "lib"),    # Generic OpenSSL
            os.path.join(homebrew_prefix, "opt", "gettext", "lib"),   # For libintl
            os.path.join(homebrew_prefix, "opt", "libiconv", "lib"),  # For libiconv
            os.path.join(homebrew_prefix, "lib"),
            "/usr/lib",  # System libraries fallback
        ]
        
        dylib_path = None
        for search_path in search_paths:
            candidate = os.path.join(search_path, lib + ".dylib")
            if os.path.exists(candidate):
                dylib_path = candidate
                break
            # Also check for versioned dylibs
            import glob
            versioned = glob.glob(os.path.join(search_path, lib + ".*.dylib"))
            if versioned:
                # Sort to get the highest version
                versioned.sort(reverse=True)
                dylib_path = versioned[0]
                break
        
        if dylib_path:
            dest_path = os.path.join(libs_dir, os.path.basename(dylib_path))
            shutil.copy2(dylib_path, dest_path)
            if lib in required_libs:
                print("  Copied required: {}".format(os.path.basename(dylib_path)))
            else:
                print("  Copied support: {}".format(os.path.basename(dylib_path)))
            
            # Update install names
            try:
                subprocess.run(["install_name_tool", "-id", "@rpath/Libraries/" + os.path.basename(dylib_path), dest_path], check=False)
                subprocess.run(["install_name_tool", "-change", dylib_path, "@rpath/Libraries/" + os.path.basename(dylib_path), binary_path], check=False)
            except Exception:
                pass
        elif lib in ["libpqxx", "libpq"]:
            print("  Warning: Required library not found: {}".format(lib))
    
    # Add @rpath to binary
    try:
        subprocess.run(["install_name_tool", "-add_rpath", "@loader_path", binary_path], check=False)
    except Exception:
        pass

# Function to bundle dependencies for Linux libraries
def bundle_linux_dependencies(env, target):
    if env["platform"] != "linux" or not env.get("bundle_deps", False) or env.get("bundle_method") == "static":
        return
    
    import shutil
    import subprocess
    import glob
    
    target_path = str(target[0])
    target_dir = os.path.dirname(target_path)
    
    print("Bundling Linux dependencies for: {}".format(os.path.basename(target_path)))
    
    # Create libs subdirectory
    libs_dir = os.path.join(target_dir, "libs")
    os.makedirs(libs_dir, exist_ok=True)
    
    # Required libraries with comprehensive coverage
    required_libs = ["libpqxx", "libpq", "libssl", "libcrypto"]
    
    # Additional support libraries that may be needed
    support_libs = ["libiconv", "libintl", "libz", "libgssapi_krb5", "libkrb5", "libk5crypto"]
    
    # Get library directories from pkg-config
    try:
        libpqxx_libdir = subprocess.check_output(["pkg-config", "--variable=libdir", "libpqxx"], universal_newlines=True).strip()
        libpq_libdir = subprocess.check_output(["pkg-config", "--variable=libdir", "libpq"], universal_newlines=True).strip()
    except subprocess.CalledProcessError:
        libpqxx_libdir = "/usr/lib"
        libpq_libdir = "/usr/lib"
    
    target_arch = os.environ.get("TARGET_ARCH", "x86_64")
    
    # Map architecture names for library paths
    arch_mapping = {
        "x86_64": "x86_64",
        "arm64": "aarch64",  # ARM64 uses aarch64 in library paths
        "aarch64": "aarch64"
    }
    lib_arch = arch_mapping.get(target_arch, target_arch)
    
    search_paths = [
        libpqxx_libdir,
        libpq_libdir,
        "/usr/lib/{}-linux-gnu".format(lib_arch),
        "/usr/lib64",
        "/usr/lib",
        "/lib/{}-linux-gnu".format(lib_arch),
        "/lib64",
        "/lib",
        "/usr/local/lib",  # Common for manually installed libraries
    ]
    
    # Copy all required and support libraries
    all_libs = required_libs + support_libs
    for lib in all_libs:
        so_path = None
        for search_path in search_paths:
            candidate = os.path.join(search_path, lib + ".so")
            if os.path.exists(candidate):
                so_path = candidate
                break
            # Check for versioned libraries
            versioned = glob.glob(os.path.join(search_path, lib + ".so.*"))
            if versioned:
                # Sort to get the highest version
                versioned.sort(reverse=True)
                so_path = versioned[0]
                break
        
        if so_path:
            dest_path = os.path.join(libs_dir, os.path.basename(so_path))
            shutil.copy2(so_path, dest_path)
            os.chmod(dest_path, 0o755)
            if lib in required_libs:
                print("  Copied required: {}".format(os.path.basename(so_path)))
            else:
                print("  Copied support: {}".format(os.path.basename(so_path)))
        elif lib in ["libpqxx", "libpq"]:
            print("  Warning: Required library not found: {}".format(lib))

# For reference:
# - CCFLAGS are compilation flags shared between C and C++
# - CFLAGS are for C-specific compilation flags
# - CXXFLAGS are for C++-specific compilation flags
# - CPPFLAGS are for pre-processor flags
# - CPPDEFINES are for pre-processor defines
# - LINKFLAGS are for linking flags

# tweak this if you want to use different folders, or more folders, to store your source code in.
env.Append(CPPPATH=["src/"])
sources = Glob("src/*.cpp")

# Enable C++ exceptions
if env["platform"] == "windows":
    # MSVC uses /EHsc for exception handling
    env.Append(CXXFLAGS=['/EHsc'])
else:
    # GCC/Clang use -fexceptions
    env.Append(CXXFLAGS=['-fexceptions'])

if env["platform"] == "macos":
    # Create framework structure for macOS
    library = env.SharedLibrary(
        "demo/bin/PostgreAdapter/libpostgreadapter.{}.{}.framework/libpostgreadapter.{}.{}".format(
            env["platform"], env["target"], env["platform"], env["target"]
        ),
        source=sources,
    )
elif env["platform"] == "ios":
    if env["ios_simulator"]:
        library = env.StaticLibrary(
            "demo/bin/PostgreAdapter/libpostgreadapter.{}.{}.simulator.a".format(env["platform"], env["target"]),
            source=sources,
        )
    else:
        library = env.StaticLibrary(
            "demo/bin/PostgreAdapter/libpostgreadapter.{}.{}.a".format(env["platform"], env["target"]),
            source=sources,
        )
else:
    library = env.SharedLibrary(
        "demo/bin/PostgreAdapter/libpostgreadapter{}{}".format(env["suffix"], env["SHLIBSUFFIX"]),
        source=sources,
    )

# Add post-build actions for dependency bundling
if env["platform"] == "windows":
    env.AddPostAction(library, lambda target, source, env: copy_windows_dependencies(env, target))
elif env["platform"] == "macos":
    env.AddPostAction(library, lambda target, source, env: bundle_macos_dependencies(env, target))
elif env["platform"] == "linux":
    env.AddPostAction(library, lambda target, source, env: bundle_linux_dependencies(env, target))

Default(library)
