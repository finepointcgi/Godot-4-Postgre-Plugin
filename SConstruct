#!/usr/bin/env python
import os
import sys
os.environ['GODOT_CPP_PATH'] = '/Users/finepointcgi/Documents/GitHub/PostgrePlugin/godot-cpp'

env = SConscript("godot-cpp/SConstruct")
env.Append(CPPPATH=[
    os.environ['GODOT_CPP_PATH'] + "/include",
    os.environ['GODOT_CPP_PATH'] + "/gen/include",
    "/opt/homebrew/opt/libpqxx/include"
])
env.Append(LIBPATH=["/opt/homebrew/opt/libpqxx/lib", "/opt/homebrew/opt/libpq/lib"])
env.Append(LIBS=["pqxx", "pq"]) # Link against libpqxx and libpq

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
env.Append(CXXFLAGS=['-fexceptions'])

if env["platform"] == "macos":
    library = env.SharedLibrary(
        "demo/bin/libpostgreadapter.{}.{}.framework/libpostgreadapter.{}.{}".format(
            env["platform"], env["target"], env["platform"], env["target"]
        ),
        source=sources,
    )
elif env["platform"] == "ios":
    if env["ios_simulator"]:
        library = env.StaticLibrary(
            "demo/bin/libpostgreadapter.{}.{}.simulator.a".format(env["platform"], env["target"]),
            source=sources,
        )
    else:
        library = env.StaticLibrary(
            "demo/bin/libpostgreadapter.{}.{}.a".format(env["platform"], env["target"]),
            source=sources,
        )
else:
    library = env.SharedLibrary(
        "demo/bin/libpostgreadapter{}{}".format(env["suffix"], env["SHLIBSUFFIX"]),
        source=sources,
    )

Default(library)
