@echo off
REM Diagnostic tool to check Windows DLL dependencies and loading issues

echo ================================================================
echo PostgreSQL Godot Plugin - Windows Dependency Checker
echo ================================================================
echo.

REM Check if we're in the right directory
if not exist "Demo\bin\PostgreAdapter" (
    echo [ERROR] Demo\bin\PostgreAdapter directory not found
    echo         Run this from the plugin root directory after building
    pause
    exit /b 1
)

set PLUGIN_DIR=Demo\bin\PostgreAdapter

echo [INFO] Checking plugin directory: %PLUGIN_DIR%
echo.

echo ================================================================
echo FILES IN PLUGIN DIRECTORY:
echo ================================================================
dir "%PLUGIN_DIR%" /B
echo.

echo ================================================================
echo DLL FILES WITH SIZES:
echo ================================================================
for %%f in ("%PLUGIN_DIR%\*.dll") do (
    echo %%~nxf
    for /f "tokens=3" %%s in ('dir "%%f" ^| find "%%~nxf"') do echo   Size: %%s bytes
    echo.
)

echo ================================================================
echo CHECKING PLUGIN DLL DEPENDENCIES:
echo ================================================================

REM Find the main plugin DLL
set PLUGIN_DLL=
for %%f in ("%PLUGIN_DIR%\libpostgreadapter.windows.template_debug.x86_64.dll") do (
    if exist "%%f" (
        set PLUGIN_DLL=%%f
        echo [OK] Found plugin DLL: %%~nxf
    )
)

if not defined PLUGIN_DLL (
    echo [ERROR] Main plugin DLL not found
    echo         Expected: libpostgreadapter.windows.template_debug.x86_64.dll
    pause
    exit /b 1
)

echo.
echo [INFO] Analyzing DLL dependencies using Windows tools...
echo.

REM Check if we have dumpbin (Visual Studio tool)
where dumpbin >nul 2>nul
if %errorlevel% equ 0 (
    echo Using dumpbin to analyze dependencies:
    echo ----------------------------------------
    dumpbin /dependents "%PLUGIN_DLL%" | findstr /i ".dll"
    echo.
) else (
    echo [WARNING] dumpbin not available ^(Visual Studio tools not in PATH^)
    echo           Using basic checks instead...
    echo.
)

echo ================================================================
echo CHECKING REQUIRED DEPENDENCIES:
echo ================================================================

set REQUIRED_DLLS=pqxx.dll libpq.dll libcrypto-3-x64.dll libssl-3-x64.dll

for %%d in (%REQUIRED_DLLS%) do (
    if exist "%PLUGIN_DIR%\%%d" (
        echo [OK] Found: %%d
    ) else (
        echo [MISSING] %%d
    )
)

echo.
echo ================================================================
echo ARCHITECTURE CHECK:
echo ================================================================

REM Check architecture using file command if available
where file >nul 2>nul
if %errorlevel% equ 0 (
    echo Using file command to check architectures:
    for %%f in ("%PLUGIN_DIR%\*.dll") do (
        echo %%~nxf:
        file "%%f" | findstr /i "x86-64\|PE32+\|AMD64"
        echo.
    )
) else (
    echo [INFO] 'file' command not available
    echo        All DLLs should be 64-bit ^(x86-64^) architecture
)

echo.
echo ================================================================
echo GODOT LOADING TEST:
echo ================================================================

echo [INFO] Testing if Windows can load the DLL...
echo.

REM Try to use PowerShell to test DLL loading
where powershell >nul 2>nul
if %errorlevel% equ 0 (
    echo Using PowerShell to test DLL loading:
    powershell -Command "try { Add-Type -TypeDefinition 'using System; using System.Runtime.InteropServices; public class DllTest { [DllImport(\"kernel32.dll\")] public static extern IntPtr LoadLibrary(string lpFileName); }'; $result = [DllTest]::LoadLibrary('%CD%\%PLUGIN_DLL%'); if ($result -ne [IntPtr]::Zero) { Write-Host '[OK] DLL can be loaded by Windows' } else { Write-Host '[ERROR] DLL cannot be loaded - missing dependencies' } } catch { Write-Host '[ERROR] PowerShell test failed:' $_.Exception.Message }"
    echo.
) else (
    echo [WARNING] PowerShell not available for DLL loading test
)

echo ================================================================
echo PATH ENVIRONMENT CHECK:
echo ================================================================

echo Current working directory: %CD%
echo.
echo PATH includes these potentially relevant directories:
echo %PATH% | findstr /i "postgres\|vcpkg\|openssl"
echo.

echo ================================================================
echo VCPKG CHECK:
echo ================================================================

if defined VCPKG_ROOT (
    echo [OK] VCPKG_ROOT is set: %VCPKG_ROOT%
    if exist "%VCPKG_ROOT%\installed\x64-windows\bin" (
        echo [OK] vcpkg bin directory exists
        echo.
        echo vcpkg DLLs available:
        dir "%VCPKG_ROOT%\installed\x64-windows\bin\*.dll" /B 2>nul | findstr /i "pq\|ssl\|crypto" || echo   No PostgreSQL/SSL DLLs found in vcpkg bin
    ) else (
        echo [WARNING] vcpkg bin directory not found
    )
) else (
    echo [WARNING] VCPKG_ROOT not set
)

echo.
echo ================================================================
echo RECOMMENDATIONS:
echo ================================================================
echo.

REM Count how many required DLLs are missing
set MISSING_COUNT=0
for %%d in (%REQUIRED_DLLS%) do (
    if not exist "%PLUGIN_DIR%\%%d" (
        set /a MISSING_COUNT+=1
    )
)

if %MISSING_COUNT% gtr 0 (
    echo [ACTION NEEDED] %MISSING_COUNT% required DLLs are missing from plugin directory
    echo.
    echo TO FIX:
    echo   1. The build process may not have copied dependencies correctly
    echo   2. Try rebuilding with: .\build_for_distribution.bat
    echo   3. Or manually copy missing DLLs from vcpkg or PostgreSQL installation
    echo.
    if defined VCPKG_ROOT (
        echo   Manual copy from vcpkg:
        echo   copy "%VCPKG_ROOT%\installed\x64-windows\bin\*.dll" "%PLUGIN_DIR%"
    )
) else (
    echo [INVESTIGATE] All required DLLs appear to be present
    echo.
    echo POSSIBLE CAUSES:
    echo   1. Architecture mismatch ^(32-bit vs 64-bit^)
    echo   2. Visual C++ runtime dependencies missing
    echo   3. DLL dependencies not in same directory as plugin
    echo   4. Corrupted DLL files
    echo.
    echo NEXT STEPS:
    echo   1. Install Visual C++ Redistributable 2022 x64
    echo   2. Use Dependency Walker to analyze missing dependencies
    echo   3. Check Windows Event Viewer for detailed error messages
)

echo.
echo ================================================================
echo DIAGNOSTIC COMPLETE
echo ================================================================
pause