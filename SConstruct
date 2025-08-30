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
    
    # PostgreSQL DLLs that need to be bundled with Windows builds
    postgresql_dlls = [
        "pqxx.dll",
        "libpq.dll",
        "libcrypto-3-x64.dll",
        "libssl-3-x64.dll"
    ]
    
    if platform == "macos":
        # macOS with Homebrew
        homebrew_prefix = "/opt/homebrew"
        if not os.path.exists(homebrew_prefix):
            # Intel Mac or custom Homebrew installation
            homebrew_prefix = "/usr/local"
        
        env.Append(CPPPATH=[
            os.path.join(homebrew_prefix, "opt", "libpqxx", "include"),
            os.path.join(homebrew_prefix, "opt", "libpq", "include")
        ])
        env.Append(LIBPATH=[
            os.path.join(homebrew_prefix, "opt", "libpqxx", "lib"),
            os.path.join(homebrew_prefix, "opt", "libpq", "lib")
        ])
        
    elif platform == "linux":
        # Linux - try to find PostgreSQL via pkg-config
        try:
            # Get libpqxx flags
            pqxx_cflags = subprocess.check_output(["pkg-config", "--cflags", "libpqxx"], universal_newlines=True).strip()
            pqxx_libs = subprocess.check_output(["pkg-config", "--libs", "libpqxx"], universal_newlines=True).strip()
            
            # Parse flags
            env.ParseFlags(pqxx_cflags)
            env.ParseFlags(pqxx_libs)
            
        except subprocess.CalledProcessError:
            # Fallback to standard paths
            env.Append(CPPPATH=["/usr/include/pqxx", "/usr/include/postgresql"])
            env.Append(LIBPATH=["/usr/lib/x86_64-linux-gnu", "/usr/lib"])
            
    elif platform == "windows":
        # Windows - use vcpkg installed libraries
        pg_path = os.environ.get("POSTGRESQL_PATH", "C:\\Program Files\\PostgreSQL\\16")
        vcpkg_root = os.environ.get("VCPKG_ROOT", "")
        
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
        
        # Windows library names for libpqxx and libpq
        env.Append(LIBS=["pqxx", "libpq", "ws2_32", "advapi32"])
        
        # Copy PostgreSQL DLLs to output directory
        def copy_postgresql_dlls(target, source, env):
            import shutil
            
            target_dir = os.path.dirname(str(target[0]))
            print("Copying PostgreSQL DLLs to: {}".format(target_dir))
            
            # Search paths for DLLs
            dll_search_paths = []
            if vcpkg_root:
                dll_search_paths.append(os.path.join(vcpkg_root, "installed", "x64-windows", "bin"))
            dll_search_paths.extend([
                os.path.join(pg_path, "bin"),
                os.path.join(pg_path, "lib"),
            ])
            
            for dll_name in postgresql_dlls:
                dll_found = False
                for search_path in dll_search_paths:
                    dll_path = os.path.join(search_path, dll_name)
                    if os.path.exists(dll_path):
                        dst_path = os.path.join(target_dir, dll_name)
                        try:
                            shutil.copy2(dll_path, dst_path)
                            print("Copied {} to {}".format(dll_path, dst_path))
                            dll_found = True
                            break
                        except Exception as e:
                            print("Failed to copy {}: {}".format(dll_path, e))
                
                if not dll_found:
                    print("Warning: Could not find DLL: {} in search paths: {}".format(dll_name, dll_search_paths))
        
        # Register the DLL copy action
        env.AddPostAction("$TARGET", copy_postgresql_dlls)
        
        return  # Skip the common libs addition below
    
    # Common library names for Unix-like systems
    env.Append(LIBS=["pqxx", "pq"])

# Configure PostgreSQL libraries based on platform
configure_postgresql_libs(env)

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

Default(library)
