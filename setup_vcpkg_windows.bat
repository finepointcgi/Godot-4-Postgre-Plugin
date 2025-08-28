@echo off
REM Quick vcpkg setup script for PostgreSQL Godot plugin on Windows
REM This installs vcpkg and the required PostgreSQL C++ libraries

echo ================================================================
echo PostgreSQL Godot Plugin - vcpkg Setup for Windows
echo ================================================================
echo.
echo This script will:
echo   1. Install vcpkg package manager
echo   2. Install PostgreSQL C++ libraries ^(libpqxx^)
echo   3. Set up environment for building
echo.
echo This is a one-time setup. After this, you can build with:
echo   .\build_for_distribution.bat
echo.
pause

REM Check if we're in the right directory
if not exist "SConstruct" (
    echo [ERROR] This script must be run from the plugin root directory
    echo         ^(the directory containing SConstruct^)
    pause
    exit /b 1
)

REM Check if vcpkg already exists
if exist "vcpkg" (
    echo [INFO] vcpkg directory already exists
    if exist "vcpkg\vcpkg.exe" (
        echo [OK] vcpkg appears to be installed
        goto install_packages
    ) else (
        echo [WARNING] vcpkg directory exists but vcpkg.exe not found
        echo           Removing and reinstalling...
        rmdir /s /q vcpkg
    )
)

echo.
echo [INFO] Cloning vcpkg...
git clone https://github.com/Microsoft/vcpkg.git
if %errorlevel% neq 0 (
    echo [ERROR] Failed to clone vcpkg
    echo         Make sure git is installed and you have internet access
    pause
    exit /b 1
)

echo.
echo [INFO] Bootstrapping vcpkg...
cd vcpkg
call .\bootstrap-vcpkg.bat
if %errorlevel% neq 0 (
    echo [ERROR] Failed to bootstrap vcpkg
    pause
    exit /b 1
)

:install_packages
cd vcpkg 2>nul || (
    echo [ERROR] vcpkg directory not found
    pause
    exit /b 1
)

echo.
echo [INFO] Installing PostgreSQL C++ libraries...
echo        This may take 10-30 minutes depending on your system...
.\vcpkg install libpqxx:x64-windows
if %errorlevel% neq 0 (
    echo [ERROR] Failed to install libpqxx
    echo         Check the output above for specific errors
    pause
    exit /b 1
)

echo.
echo [INFO] Verifying installation...
if exist "installed\x64-windows\include\pqxx" (
    echo [OK] libpqxx C++ headers found
) else (
    echo [ERROR] libpqxx installation appears incomplete
    pause
    exit /b 1
)

if exist "installed\x64-windows\lib\pqxx.lib" (
    echo [OK] libpqxx library found
) else (
    echo [WARNING] libpqxx.lib not found, checking alternatives...
    if exist "installed\x64-windows\lib\libpqxx.lib" (
        echo [OK] libpqxx.lib found
    ) else (
        echo [ERROR] No libpqxx library files found
        pause
        exit /b 1
    )
)

cd ..

REM Set environment variable for current session
set VCPKG_ROOT=%CD%\vcpkg
echo.
echo [OK] Setting VCPKG_ROOT for current session: %VCPKG_ROOT%

REM Try to set permanent environment variable
echo [INFO] Attempting to set permanent VCPKG_ROOT environment variable...
setx VCPKG_ROOT "%VCPKG_ROOT%" >nul 2>nul
if %errorlevel% equ 0 (
    echo [OK] VCPKG_ROOT environment variable set permanently
) else (
    echo [WARNING] Could not set permanent environment variable
    echo           You may need to set VCPKG_ROOT manually:
    echo           set VCPKG_ROOT=%VCPKG_ROOT%
)

echo.
echo ================================================================
echo SETUP COMPLETED SUCCESSFULLY!
echo ================================================================
echo.
echo vcpkg is now installed with PostgreSQL C++ libraries.
echo.
echo NEXT STEPS:
echo   1. Close and reopen your command prompt ^(for environment variables^)
echo   2. Run: .\build_for_distribution.bat
echo   3. Your plugin will be built with all dependencies bundled!
echo.
echo WHAT WAS INSTALLED:
echo   - vcpkg package manager in .\vcpkg\
echo   - libpqxx C++ PostgreSQL library
echo   - libpq PostgreSQL client library  
echo   - OpenSSL libraries ^(dependencies^)
echo   - Environment variable: VCPKG_ROOT=%VCPKG_ROOT%
echo.
echo The plugin will now build self-contained packages that your users
echo can use without installing PostgreSQL!
echo.
pause