@echo off
REM Setup script for Windows build environment
REM This will help resolve the "Error 126: The specified module could not be found" issue

echo ================================================================
echo PostgreSQL Godot Plugin - Build Environment Setup
echo ================================================================
echo.

REM Check if we're already in a developer command prompt
where cl >nul 2>nul
if %errorlevel% equ 0 (
    echo [OK] Visual Studio tools found in PATH
    goto check_postgres
)

REM Try to find and setup Visual Studio tools
echo [INFO] Looking for Visual Studio installations...

REM Try VS 2022
if exist "C:\Program Files\Microsoft Visual Studio\2022\Community\VC\Auxiliary\Build\vcvars64.bat" (
    echo [OK] Found Visual Studio 2022 Community
    call "C:\Program Files\Microsoft Visual Studio\2022\Community\VC\Auxiliary\Build\vcvars64.bat"
    goto check_postgres
)

if exist "C:\Program Files\Microsoft Visual Studio\2022\Professional\VC\Auxiliary\Build\vcvars64.bat" (
    echo [OK] Found Visual Studio 2022 Professional
    call "C:\Program Files\Microsoft Visual Studio\2022\Professional\VC\Auxiliary\Build\vcvars64.bat"
    goto check_postgres
)

REM Try VS 2019
if exist "C:\Program Files (x86)\Microsoft Visual Studio\2019\Community\VC\Auxiliary\Build\vcvars64.bat" (
    echo [OK] Found Visual Studio 2019 Community
    call "C:\Program Files (x86)\Microsoft Visual Studio\2019\Community\VC\Auxiliary\Build\vcvars64.bat"
    goto check_postgres
)

REM Try Build Tools
if exist "C:\Program Files (x86)\Microsoft Visual Studio\2019\BuildTools\VC\Auxiliary\Build\vcvars64.bat" (
    echo [OK] Found Visual Studio 2019 Build Tools
    call "C:\Program Files (x86)\Microsoft Visual Studio\2019\BuildTools\VC\Auxiliary\Build\vcvars64.bat"
    goto check_postgres
)

echo [ERROR] Visual Studio not found. Please install:
echo   - Visual Studio 2019/2022 Community (free)
echo   - OR Visual Studio Build Tools
echo.
echo Download from: https://visualstudio.microsoft.com/downloads/
pause
exit /b 1

:check_postgres
echo.
echo [INFO] Checking PostgreSQL dependencies...

REM Check for vcpkg (preferred)
if defined VCPKG_ROOT (
    if exist "%VCPKG_ROOT%\installed\x64-windows\include\pqxx" (
        echo [OK] vcpkg with libpqxx found
        goto build_ready
    )
)

REM Check for PostgreSQL installation
set FOUND_PG=false
for /d %%i in ("C:\Program Files\PostgreSQL\*") do (
    if exist "%%i\include\libpq-fe.h" (
        echo [OK] Found PostgreSQL at: %%i
        set POSTGRESQL_PATH=%%i
        set FOUND_PG=true
        goto pg_found
    )
)
:pg_found

if "%FOUND_PG%"=="false" (
    echo.
    echo [SETUP NEEDED] PostgreSQL development libraries not found
    echo.
    echo RECOMMENDED APPROACH - vcpkg (easier):
    echo   1. git clone https://github.com/Microsoft/vcpkg.git C:\vcpkg
    echo   2. cd C:\vcpkg
    echo   3. .\bootstrap-vcpkg.bat
    echo   4. .\vcpkg install libpqxx:x64-windows
    echo   5. set VCPKG_ROOT=C:\vcpkg
    echo.
    echo ALTERNATIVE - Direct PostgreSQL installation:
    echo   Download from: https://www.postgresql.org/download/windows/
    echo.
    set /p choice="Would you like to setup vcpkg automatically? (y/n): "
    if /i "%choice%"=="y" goto setup_vcpkg
    pause
    exit /b 1
)

:build_ready
echo.
echo ================================================================
echo BUILD ENVIRONMENT READY!
echo ================================================================
echo.
echo You can now run:
echo   build_scripts\build_windows_bundled.bat
echo.
echo Or for distribution build:
echo   build_for_distribution.bat
echo.
pause
exit /b 0

:setup_vcpkg
echo.
echo [INFO] Setting up vcpkg automatically...
cd /d C:\
if exist vcpkg (
    echo [INFO] vcpkg directory exists, updating...
    cd vcpkg
    git pull
) else (
    echo [INFO] Cloning vcpkg...
    git clone https://github.com/Microsoft/vcpkg.git
    cd vcpkg
)

echo [INFO] Bootstrapping vcpkg...
.\bootstrap-vcpkg.bat

echo [INFO] Installing libpqxx...
.\vcpkg install libpqxx:x64-windows

echo [INFO] Setting environment variables...
setx VCPKG_ROOT "C:\vcpkg"
set VCPKG_ROOT=C:\vcpkg

echo.
echo [SUCCESS] vcpkg setup complete!
goto build_ready