@echo off
REM Script to copy PostgreSQL DLLs for manual dependency management
setlocal enabledelayedexpansion

echo Copying PostgreSQL DLLs for Windows distribution...

REM Set default paths if not provided
if not defined POSTGRESQL_PATH (
    if exist "C:\Program Files\PostgreSQL\16" (
        set POSTGRESQL_PATH=C:\Program Files\PostgreSQL\16
    ) else if exist "C:\Program Files\PostgreSQL\15" (
        set POSTGRESQL_PATH=C:\Program Files\PostgreSQL\15
    ) else if exist "C:\Program Files\PostgreSQL\14" (
        set POSTGRESQL_PATH=C:\Program Files\PostgreSQL\14
    ) else (
        echo PostgreSQL installation not found. Please set POSTGRESQL_PATH environment variable.
        exit /b 1
    )
)

REM Define DLL list
set "DLL_LIST=pqxx.dll libpq.dll libcrypto-3-x64.dll libssl-3-x64.dll"

REM Define search paths
set "SEARCH_PATHS="
if defined VCPKG_ROOT (
    set "SEARCH_PATHS=!SEARCH_PATHS! "%VCPKG_ROOT%\installed\x64-windows\bin""
)
set "SEARCH_PATHS=!SEARCH_PATHS! "%POSTGRESQL_PATH%\bin" "%POSTGRESQL_PATH%\lib""

REM Define output directories
set "OUTPUT_DIRS=demo\bin\PostgreAdapter Demo\bin\PostgreAdapter"

echo Using PostgreSQL path: %POSTGRESQL_PATH%
if defined VCPKG_ROOT (
    echo Using vcpkg root: %VCPKG_ROOT%
)

REM Copy DLLs to each output directory
for %%O in (%OUTPUT_DIRS%) do (
    if not exist "%%O" (
        echo Creating directory: %%O
        mkdir "%%O" 2>nul
    )
    
    echo.
    echo Copying to %%O:
    
    for %%D in (%DLL_LIST%) do (
        set "DLL_FOUND="
        for %%P in (%SEARCH_PATHS%) do (
            if exist "%%~P\%%D" (
                copy "%%~P\%%D" "%%O\" >nul 2>&1
                if !errorlevel! equ 0 (
                    echo   ✓ Copied %%D from %%~P
                    set "DLL_FOUND=1"
                    goto :next_dll
                ) else (
                    echo   ✗ Failed to copy %%D from %%~P
                )
            )
        )
        
        :next_dll
        if not defined DLL_FOUND (
            echo   ⚠ Warning: Could not find %%D in any search path
        )
    )
)

echo.
echo DLL copy process completed.
echo.
echo Note: Make sure these DLLs are distributed alongside your GDExtension
echo for proper runtime dependency resolution.