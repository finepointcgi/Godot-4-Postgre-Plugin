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
                
                # If building universal but library is single-arch, adjust build
                if build_arch == "universal" and "Non-fat file" in lipo_output:
                    if "arm64" in lipo_output:
                        print("Homebrew libraries are ARM64-only, switching to arm64 build")
                        env["arch"] = "arm64"
                    elif "x86_64" in lipo_output:
                        print("Homebrew libraries are x86_64-only, switching to x86_64 build")
                        env["arch"] = "x86_64"
            except (subprocess.CalledProcessError, OSError):
                print("Could not check library architecture, proceeding with requested arch")
        
        env.Append(CPPPATH=[
            os.path.join(homebrew_prefix, "opt", "libpqxx", "include"),
            os.path.join(homebrew_prefix, "opt", "libpq", "include")
        ])
        env.Append(LIBPATH=[
            os.path.join(homebrew_prefix, "opt", "libpqxx", "lib"),
            os.path.join(homebrew_prefix, "opt", "libpq", "lib")
        ])
        
        # Configure linking method
        if bundle_deps and bundle_method == "static":
            # Try static linking first
            static_libs = [
                os.path.join(homebrew_prefix, "opt", "libpqxx", "lib", "libpqxx.a"),
                os.path.join(homebrew_prefix, "opt", "libpq", "lib", "libpq.a")
            ]
            if all(os.path.exists(lib) for lib in static_libs):
                env.Append(LIBS=["pqxx", "pq"])
                env.Append(LINKFLAGS=["-static-libstdc++"])
                print("Using static linking for macOS")
            else:
                print("Static libraries not found, falling back to dynamic linking")
                bundle_method = "dynamic"
        
        if not bundle_deps or bundle_method != "static":
            # Dynamic linking - will be bundled post-build
            env.Append(LIBS=["pqxx", "pq"])
        
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
        # Windows - Always use dynamic linking and bundle DLLs for user distribution
        pg_path = os.environ.get("POSTGRESQL_PATH", "C:\\Program Files\\PostgreSQL\\16")
        vcpkg_root = os.environ.get("VCPKG_ROOT", "")
        
        # Force DLL bundling for end-user distribution
        bundle_deps = True
        print("Windows build: Always bundling dependencies for end-user distribution")
        print("PostgreSQL path: {}".format(pg_path))
        print("vcpkg root: {}".format(vcpkg_root))
        
        env.Append(CPPPATH=[
            os.path.join(pg_path, "include")
        ])
        env.Append(LIBPATH=[os.path.join(pg_path, "lib")])
        
        # Use vcpkg toolchain if available
        if vcpkg_root:
            env.Append(CPPPATH=[os.path.join(vcpkg_root, "installed", "x64-windows", "include")])
            env.Append(LIBPATH=[os.path.join(vcpkg_root, "installed", "x64-windows", "lib")])
            print("Using vcpkg dynamic linking with DLL bundling")
        else:
            print("Using PostgreSQL installation dynamic linking with DLL bundling")
        
        # Always use dynamic linking - simpler and allows DLL bundling
        env.Append(LIBS=["libpqxx", "libpq", "ws2_32", "advapi32"])
        
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
        "libpq.dll",           # PostgreSQL client library
        "libcrypto-3-x64.dll", # OpenSSL crypto (newer naming)
        "libssl-3-x64.dll",    # OpenSSL SSL (newer naming)
    ]
    optional_dlls = [
        "pqxx.dll",            # libpqxx C++ wrapper
        "libcrypto-1_1-x64.dll",  # OpenSSL crypto (older naming)
        "libssl-1_1-x64.dll",     # OpenSSL SSL (older naming)
        "libeay32.dll",        # OpenSSL crypto (legacy naming)
        "ssleay32.dll",        # OpenSSL SSL (legacy naming)
        "msvcr120.dll",        # Visual C++ runtime (sometimes needed)
        "msvcp120.dll",        # Visual C++ runtime (sometimes needed)
    ]
    
    print("Copying Windows dependencies to: {}".format(target_dir))
    
    # Search locations for DLLs (comprehensive search)
    search_paths = []
    if vcpkg_root:
        search_paths.append(os.path.join(vcpkg_root, "installed", "x64-windows", "bin"))
        search_paths.append(os.path.join(vcpkg_root, "installed", "x64-windows", "lib"))
    
    # PostgreSQL installation paths
    search_paths.extend([
        os.path.join(pg_path, "bin"),
        os.path.join(pg_path, "lib")
    ])
    
    # System paths (for OpenSSL and runtime DLLs)
    search_paths.extend([
        "C:\\Windows\\System32",
        "C:\\Windows\\SysWOW64",
        os.path.join(os.environ.get("ProgramFiles", "C:\\Program Files"), "OpenSSL-Win64", "bin"),
        os.path.join(os.environ.get("ProgramFiles(x86)", "C:\\Program Files (x86)"), "OpenSSL-Win32", "bin")
    ])
    
    for dll in required_dlls + optional_dlls:
        found = False
        for search_path in search_paths:
            dll_path = os.path.join(search_path, dll)
            if os.path.exists(dll_path):
                target_path = os.path.join(target_dir, dll)
                try:
                    shutil.copy2(dll_path, target_path)
                    print("  Copied: {} -> {}".format(dll, os.path.basename(target_path)))
                    found = True
                    break
                except Exception as e:
                    print("  Warning: Failed to copy {}: {}".format(dll, e))
        
        if not found and dll in required_dlls:
            print("  Warning: Required DLL not found: {}".format(dll))

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
    
    for lib in required_libs:
        # Search for dylib - more comprehensive search
        search_paths = [
            os.path.join(homebrew_prefix, "opt", "libpqxx", "lib"),
            os.path.join(homebrew_prefix, "opt", "libpq", "lib"),
            os.path.join(homebrew_prefix, "opt", "openssl@3", "lib"),  # OpenSSL 3.x
            os.path.join(homebrew_prefix, "opt", "openssl@1.1", "lib"), # OpenSSL 1.1.x  
            os.path.join(homebrew_prefix, "opt", "openssl", "lib"),    # Generic OpenSSL
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
                dylib_path = versioned[0]
                break
        
        if dylib_path:
            dest_path = os.path.join(libs_dir, os.path.basename(dylib_path))
            shutil.copy2(dylib_path, dest_path)
            print("  Copied: {}".format(os.path.basename(dylib_path)))
            
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
    
    # Required libraries
    required_libs = ["libpqxx", "libpq", "libssl", "libcrypto"]
    
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
    
    for lib in required_libs:
        so_path = None
        for search_path in search_paths:
            candidate = os.path.join(search_path, lib + ".so")
            if os.path.exists(candidate):
                so_path = candidate
                break
            # Check for versioned libraries  
            versioned = glob.glob(os.path.join(search_path, lib + ".so.*"))
            if versioned:
                so_path = versioned[0]
                break
        
        if so_path:
            dest_path = os.path.join(libs_dir, os.path.basename(so_path))
            shutil.copy2(so_path, dest_path)
            os.chmod(dest_path, 0o755)
            print("  Copied: {}".format(os.path.basename(so_path)))
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
