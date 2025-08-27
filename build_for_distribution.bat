@echo off
REM Simple build script for creating distributable PostgreSQL Godot plugin
REM This bundles all dependencies so end users don't need PostgreSQL installed

setlocal enabledelayedexpansion

echo ================================================================
echo PostgreSQL Godot Plugin - Distribution Build
echo ================================================================
echo.
echo This will create a complete plugin package with all dependencies
echo included. Your users will NOT need PostgreSQL installed.
echo.

REM Check for Visual Studio Build Tools
where cl >nul 2>nul
if %errorlevel% neq 0 (
    echo [ERROR] Visual Studio Build Tools not found in PATH
    echo         Please run this from a Visual Studio Developer Command Prompt
    echo         or install Visual Studio Build Tools
    pause
    exit /b 1
)

REM Check for SCons
where scons >nul 2>nul
if %errorlevel% neq 0 (
    echo [ERROR] SCons not found. Install with:
    echo         pip install scons
    pause
    exit /b 1
)

echo [INFO] Build tools found
echo.

REM Try to find PostgreSQL or vcpkg installation
set FOUND_SETUP=false

REM Check vcpkg first (preferred)
if defined VCPKG_ROOT (
    if exist "%VCPKG_ROOT%\installed\x64-windows\include\pqxx" (
        echo [OK] Found vcpkg PostgreSQL installation
        set FOUND_SETUP=true
    )
)

REM Check standard PostgreSQL installations
if "%FOUND_SETUP%"=="false" (
    for /d %%i in ("C:\Program Files\PostgreSQL\*") do (
        if exist "%%i\include\libpq-fe.h" (
            set POSTGRESQL_PATH=%%i
            echo [OK] Found PostgreSQL at: %%i
            set FOUND_SETUP=true
            goto found_pg
        )
    )
    :found_pg
)

if "%FOUND_SETUP%"=="false" (
    echo.
    echo [ERROR] PostgreSQL development libraries not found!
    echo.
    echo QUICK SETUP OPTIONS:
    echo.
    echo Option 1 - Install PostgreSQL ^(Recommended^):
    echo   1. Download from: https://www.postgresql.org/download/windows/
    echo   2. Run installer and include development libraries
    echo   3. Run this script again
    echo.
    echo Option 2 - Use vcpkg:
    echo   1. git clone https://github.com/Microsoft/vcpkg.git
    echo   2. cd vcpkg ^&^& .\bootstrap-vcpkg.bat
    echo   3. .\vcpkg install libpqxx:x64-windows
    echo   4. set VCPKG_ROOT=C:\path\to\vcpkg
    echo   5. Run this script again
    echo.
    pause
    exit /b 1
)

echo.
echo [INFO] Starting build process...
echo.

REM Build godot-cpp first
echo ================================
echo Building godot-cpp...
echo ================================
cd godot-cpp

echo Building debug version...
scons platform=windows target=template_debug arch=x86_64 -j%NUMBER_OF_PROCESSORS%
if %errorlevel% neq 0 (
    echo [ERROR] Failed to build godot-cpp debug
    pause
    exit /b %errorlevel%
)

echo Building release version...
scons platform=windows target=template_release arch=x86_64 -j%NUMBER_OF_PROCESSORS%
if %errorlevel% neq 0 (
    echo [ERROR] Failed to build godot-cpp release
    pause
    exit /b %errorlevel%
)

cd ..

REM Build the extension
echo.
echo ================================
echo Building PostgreSQL extension...
echo ================================

echo Building debug version...
scons platform=windows target=template_debug arch=x86_64 -j%NUMBER_OF_PROCESSORS%
if %errorlevel% neq 0 (
    echo [ERROR] Failed to build extension debug
    pause
    exit /b %errorlevel%
)

echo Building release version...
scons platform=windows target=template_release arch=x86_64 -j%NUMBER_OF_PROCESSORS%
if %errorlevel% neq 0 (
    echo [ERROR] Failed to build extension release
    pause
    exit /b %errorlevel%
)

echo.
echo ================================================================
echo BUILD COMPLETED SUCCESSFULLY!
echo ================================================================
echo.

REM Show what was built
echo Distribution files created:
echo.
for %%f in ("Demo\bin\PostgreAdapter\*.dll") do (
    echo   %%f
    for /f %%s in ('powershell -command "'{0:N2} MB' -f ((Get-Item '%%f').Length / 1MB)"') do echo     Size: %%s
)

echo.
echo Dependencies bundled:
for %%f in ("Demo\bin\PostgreAdapter\*.dll") do (
    if not "%%~nxf"=="libpostgreadapter.windows.template_debug.x86_64.dll" (
        if not "%%~nxf"=="libpostgreadapter.windows.template_release.x86_64.dll" (
            echo   %%~nxf
        )
    )
)

echo.
echo ================================================================
echo DISTRIBUTION PACKAGE READY!
echo ================================================================
echo.
echo Your plugin is ready for distribution. To share with users:
echo.
echo 1. Copy the entire folder: Demo\bin\PostgreAdapter\
echo 2. Users just need to copy this folder to their Godot project
echo 3. No PostgreSQL installation required for end users!
echo.
echo The plugin includes all required dependencies:
echo   - PostgreSQL client libraries
echo   - SSL/crypto libraries  
echo   - C++ runtime libraries
echo.
echo Location: %CD%\Demo\bin\PostgreAdapter\
echo.
pause