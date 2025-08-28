@echo off
REM Fix DLL dependencies for existing build output
REM This copies required PostgreSQL DLLs to make the extension work in Godot

setlocal enabledelayedexpansion

echo ================================================================
echo PostgreSQL GDExtension - DLL Dependency Fixer
echo ================================================================
echo.
echo This will copy required DLLs to make your extension work in Godot
echo.

REM Check if plugin directory exists
set PLUGIN_DIR=Demo\bin\PostgreAdapter
if not exist "%PLUGIN_DIR%" (
    echo [ERROR] Plugin directory not found: %PLUGIN_DIR%
    echo         Run this from the project root directory
    pause
    exit /b 1
)

echo [INFO] Plugin directory: %PLUGIN_DIR%
echo.

REM Check if main DLL exists
set MAIN_DLL=
for %%f in ("%PLUGIN_DIR%\libpostgreadapter.windows.*.dll") do (
    set MAIN_DLL=%%f
    echo [OK] Found plugin DLL: %%~nxf
)

if not defined MAIN_DLL (
    echo [ERROR] No plugin DLL found in %PLUGIN_DIR%
    echo         Build the project first using one of:
    echo           - setup_build_environment.bat
    echo           - build_scripts\build_windows_bundled.bat
    pause
    exit /b 1
)

echo.
echo [INFO] Searching for PostgreSQL dependencies...

REM Required DLLs that must be found
set REQUIRED_DLLS=libpq.dll

REM Important DLLs (C++ wrapper)
set IMPORTANT_DLLS=pqxx.dll libpqxx.dll

REM SSL/Crypto DLLs (multiple versions supported)
set SSL_DLLS=libcrypto-3-x64.dll libssl-3-x64.dll libcrypto-1_1-x64.dll libssl-1_1-x64.dll

REM Build comprehensive search path list
set SEARCH_PATHS=

REM Check vcpkg first
if defined VCPKG_ROOT (
    if exist "%VCPKG_ROOT%\installed\x64-windows\bin" (
        set SEARCH_PATHS=!SEARCH_PATHS! "%VCPKG_ROOT%\installed\x64-windows\bin"
        echo [OK] vcpkg bin found: %VCPKG_ROOT%\installed\x64-windows\bin
    )
)

REM Check PostgreSQL installations
for /d %%i in ("C:\Program Files\PostgreSQL\*") do (
    if exist "%%i\bin" (
        set SEARCH_PATHS=!SEARCH_PATHS! "%%i\bin"
        echo [OK] PostgreSQL bin found: %%i\bin
    )
)

REM Add system paths
set SEARCH_PATHS=!SEARCH_PATHS! "C:\Windows\System32"

if "%SEARCH_PATHS%"=="" (
    echo [ERROR] No PostgreSQL installations found!
    echo.
    echo SOLUTIONS:
    echo 1. Install PostgreSQL from: https://www.postgresql.org/download/windows/
    echo 2. OR setup vcpkg:
    echo    git clone https://github.com/Microsoft/vcpkg.git
    echo    cd vcpkg
    echo    .\bootstrap-vcpkg.bat
    echo    .\vcpkg install libpqxx:x64-windows
    echo    set VCPKG_ROOT=C:\path\to\vcpkg
    pause
    exit /b 1
)

echo.
echo [INFO] Copying dependencies...

set COPIED_COUNT=0
set MISSING_REQUIRED=0

REM Copy required DLLs
for %%d in (%REQUIRED_DLLS%) do (
    set FOUND=false
    for %%p in (%SEARCH_PATHS%) do (
        if exist "%%~p\%%d" (
            copy "%%~p\%%d" "%PLUGIN_DIR%\" >nul 2>&1
            if !errorlevel! equ 0 (
                echo [OK] Copied required: %%d
                set FOUND=true
                set /a COPIED_COUNT+=1
                goto next_required
            )
        )
    )
    :next_required
    if "!FOUND!"=="false" (
        echo [MISSING] Required DLL not found: %%d
        set /a MISSING_REQUIRED+=1
    )
)

REM Copy C++ wrapper DLL (try to find one)
set CPP_FOUND=false
for %%d in (%IMPORTANT_DLLS%) do (
    if "!CPP_FOUND!"=="false" (
        for %%p in (%SEARCH_PATHS%) do (
            if exist "%%~p\%%d" (
                copy "%%~p\%%d" "%PLUGIN_DIR%\" >nul 2>&1
                if !errorlevel! equ 0 (
                    echo [OK] Copied C++ wrapper: %%d
                    set CPP_FOUND=true
                    set /a COPIED_COUNT+=1
                    goto next_cpp
                )
            )
        )
    )
)
:next_cpp

REM Copy SSL/Crypto DLLs (try to get at least one pair)
set CRYPTO_FOUND=false
set SSL_FOUND=false
for %%d in (%SSL_DLLS%) do (
    for %%p in (%SEARCH_PATHS%) do (
        if exist "%%~p\%%d" (
            copy "%%~p\%%d" "%PLUGIN_DIR%\" >nul 2>&1
            if !errorlevel! equ 0 (
                echo [OK] Copied SSL/crypto: %%d
                set /a COPIED_COUNT+=1
                if "%%d" == "libcrypto-3-x64.dll" set CRYPTO_FOUND=true
                if "%%d" == "libssl-3-x64.dll" set SSL_FOUND=true
                if "%%d" == "libcrypto-1_1-x64.dll" set CRYPTO_FOUND=true
                if "%%d" == "libssl-1_1-x64.dll" set SSL_FOUND=true
            )
        )
    )
)

echo.
echo ================================================================
echo DEPENDENCY COPY COMPLETE
echo ================================================================
echo.
echo Summary: Copied %COPIED_COUNT% DLL files

REM Show what's in the directory now
echo.
echo Plugin directory contents:
dir "%PLUGIN_DIR%\*.dll" /b

echo.
if %MISSING_REQUIRED% gtr 0 (
    echo [WARNING] %MISSING_REQUIRED% required DLLs are still missing
    echo           The plugin may not work correctly
) else (
    echo [SUCCESS] All required DLLs found and copied
)

if not "%CPP_FOUND%"=="true" (
    echo [WARNING] No C++ wrapper DLL found (pqxx.dll)
    echo           Plugin may have limited functionality
)

echo.
echo NEXT STEPS:
echo 1. Open your Godot project
echo 2. Try loading the PostgreSQL extension
echo 3. If still getting Error 126, run: check_windows_dependencies.bat
echo.
pause