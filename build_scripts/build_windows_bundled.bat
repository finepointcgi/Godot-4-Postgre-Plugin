@echo off
REM Enhanced Windows build script with dependency bundling
REM This script builds the PostgreSQL Godot plugin with bundled dependencies
setlocal enabledelayedexpansion

echo ============================================================
echo PostgreSQL GDExtension - Windows Build with Bundled Dependencies
echo ============================================================
echo.

REM Parse command line arguments
set BUILD_TYPE=both
set BUNDLE_METHOD=auto
set VERBOSE=false

:parse_args
if "%1"=="" goto args_done
if "%1"=="--help" goto show_help
if "%1"=="-h" goto show_help
if "%1"=="--debug" set BUILD_TYPE=debug
if "%1"=="--release" set BUILD_TYPE=release
if "%1"=="--static" set BUNDLE_METHOD=static
if "%1"=="--dynamic" set BUNDLE_METHOD=dynamic
if "%1"=="--verbose" set VERBOSE=true
if "%1"=="-v" set VERBOSE=true
shift
goto parse_args

:show_help
echo USAGE:
echo   %~nx0 [OPTIONS]
echo.
echo OPTIONS:
echo   --help, -h      Show this help message
echo   --debug         Build debug version only
echo   --release       Build release version only  
echo   --static        Force static linking (no DLL dependencies)
echo   --dynamic       Force dynamic linking with DLL bundling
echo   --verbose, -v   Verbose output
echo.
echo DESCRIPTION:
echo   Builds the PostgreSQL Godot plugin with bundled dependencies.
echo   By default, attempts static linking first, falls back to dynamic bundling.
echo.
echo EXAMPLES:
echo   %~nx0                    # Build both debug and release with auto bundling
echo   %~nx0 --debug --static   # Build debug only with static linking
echo   %~nx0 --release --dynamic # Build release only with DLL bundling
echo.
exit /b 0

:args_done

echo Build configuration:
echo   Build type: %BUILD_TYPE%
echo   Bundle method: %BUNDLE_METHOD%  
echo   Verbose: %VERBOSE%
echo.

REM Check for required tools
echo Checking build dependencies...

REM Check for Visual Studio Build Tools
where cl >nul 2>nul
if %errorlevel% neq 0 (
    echo [ERROR] Visual Studio Build Tools not found in PATH
    echo         Please run this from a Visual Studio Developer Command Prompt
    echo         or install Visual Studio Build Tools
    exit /b 1
)

REM Check for SCons
where scons >nul 2>nul
if %errorlevel% neq 0 (
    echo [ERROR] SCons not found. Install with:
    echo         pip install scons
    exit /b 1
)

REM Check for PostgreSQL or vcpkg
set FOUND_POSTGRES=false
set FOUND_VCPKG=false

REM Check vcpkg first (preferred for static linking)
if defined VCPKG_ROOT (
    if exist "%VCPKG_ROOT%\installed\x64-windows\include\pqxx" (
        set FOUND_VCPKG=true
        echo [OK] Found vcpkg PostgreSQL at: %VCPKG_ROOT%
    )
)

REM Check standard PostgreSQL installation
if not defined POSTGRESQL_PATH (
    for /d %%i in ("C:\Program Files\PostgreSQL\*") do (
        if exist "%%i\include\libpq-fe.h" (
            set POSTGRESQL_PATH=%%i
            set FOUND_POSTGRES=true
            echo [OK] Found PostgreSQL at: %%i
            goto found_postgres
        )
    )
    :found_postgres
) else (
    if exist "%POSTGRESQL_PATH%\include\libpq-fe.h" (
        set FOUND_POSTGRES=true
        echo [OK] Using PostgreSQL at: %POSTGRESQL_PATH%
    )
)

if "%FOUND_VCPKG%"=="false" and "%FOUND_POSTGRES%"=="false" (
    echo [ERROR] PostgreSQL not found. Please:
    echo         1. Install PostgreSQL from https://www.postgresql.org/download/windows/
    echo         2. Or install via vcpkg: vcpkg install libpqxx:x64-windows
    echo         3. Or set POSTGRESQL_PATH environment variable
    exit /b 1
)

REM Determine bundling strategy
set BUNDLE_DEPENDENCIES=true
if "%BUNDLE_METHOD%"=="static" (
    echo [INFO] Forcing static linking
    set BUNDLE_DEPENDENCIES=true
) else if "%BUNDLE_METHOD%"=="dynamic" (
    echo [INFO] Forcing dynamic linking with DLL bundling
    set BUNDLE_DEPENDENCIES=true
) else (
    if "%FOUND_VCPKG%"=="true" (
        echo [INFO] Using vcpkg - attempting static linking
        set BUNDLE_DEPENDENCIES=true
    ) else (
        echo [INFO] Using standard PostgreSQL - will bundle DLLs
        set BUNDLE_DEPENDENCIES=true
    )
)

echo.
echo Building godot-cpp...
cd godot-cpp

if "%BUILD_TYPE%"=="both" or "%BUILD_TYPE%"=="debug" (
    echo   Building godot-cpp debug...
    scons platform=windows target=template_debug arch=x86_64 %VERBOSE_FLAG%
    if !errorlevel! neq 0 (
        echo [ERROR] Failed to build godot-cpp debug
        exit /b !errorlevel!
    )
)

if "%BUILD_TYPE%"=="both" or "%BUILD_TYPE%"=="release" (
    echo   Building godot-cpp release...  
    scons platform=windows target=template_release arch=x86_64 %VERBOSE_FLAG%
    if !errorlevel! neq 0 (
        echo [ERROR] Failed to build godot-cpp release
        exit /b !errorlevel!
    )
)

cd ..

echo.
echo Building PostgreSQL extension...

REM Set environment variables for the build
set BUNDLE_DEPENDENCIES=%BUNDLE_DEPENDENCIES%
if "%VERBOSE%"=="true" set VERBOSE_FLAG=--debug=explain

if "%BUILD_TYPE%"=="both" or "%BUILD_TYPE%"=="debug" (
    echo   Building extension debug...
    scons platform=windows target=template_debug arch=x86_64 %VERBOSE_FLAG%
    if !errorlevel! neq 0 (
        echo [ERROR] Failed to build PostgreSQL extension debug
        exit /b !errorlevel!
    )
    echo   [SUCCESS] Debug build completed
)

if "%BUILD_TYPE%"=="both" or "%BUILD_TYPE%"=="release" (
    echo   Building extension release...
    scons platform=windows target=template_release arch=x86_64 %VERBOSE_FLAG%
    if !errorlevel! neq 0 (
        echo [ERROR] Failed to build PostgreSQL extension release  
        exit /b !errorlevel!
    )
    echo   [SUCCESS] Release build completed
)

echo.
echo ============================================================
echo BUILD COMPLETED SUCCESSFULLY!
echo ============================================================

REM Show build outputs
echo Built files:
for %%f in ("demo\bin\PostgreAdapter\*.dll") do (
    echo   %%f
)
for %%f in ("demo\bin\PostgreAdapter\*.dll") do (
    echo   - File size: 
    dir "%%f" | find "%%~nxf"
)

echo.
echo Dependencies in output directory:
dir "demo\bin\PostgreAdapter\" | find ".dll"

echo.
echo NEXT STEPS:
echo   1. Open your Godot project
echo   2. The plugin should now load without dependency errors
echo   3. Configure your PostgreSQL connection string
echo   4. Test the plugin functionality

if "%FOUND_VCPKG%"=="true" and "%BUNDLE_METHOD%"=="auto" (
    echo.
    echo NOTE: Built with vcpkg - dependencies should be statically linked
    echo       The plugin DLL should be self-contained
) else (
    echo.
    echo NOTE: Built with dynamic PostgreSQL installation
    echo       Required DLLs have been copied to the plugin directory
)

echo.
echo For distribution, include all files in: demo\bin\PostgreAdapter\