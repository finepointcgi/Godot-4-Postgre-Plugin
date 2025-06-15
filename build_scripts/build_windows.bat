@echo off
REM Build script for Windows platforms
setlocal enabledelayedexpansion

echo Building PostgreSQL GDExtension for Windows...

REM Check for required dependencies
echo Checking dependencies...

REM Check for Visual Studio Build Tools
where cl >nul 2>nul
if %errorlevel% neq 0 (
    echo Visual Studio Build Tools not found in PATH
    echo    Please run this from a Visual Studio Developer Command Prompt
    echo    or install Visual Studio Build Tools
    exit /b 1
)

REM Check for SCons
where scons >nul 2>nul
if %errorlevel% neq 0 (
    echo SCons not found. Install with:
    echo    pip install scons
    exit /b 1
)

REM Check for PostgreSQL
if not defined POSTGRESQL_PATH (
    if exist "C:\Program Files\PostgreSQL\16" (
        set POSTGRESQL_PATH=C:\Program Files\PostgreSQL\16
    ) else if exist "C:\Program Files\PostgreSQL\15" (
        set POSTGRESQL_PATH=C:\Program Files\PostgreSQL\15
    ) else if exist "C:\Program Files\PostgreSQL\14" (
        set POSTGRESQL_PATH=C:\Program Files\PostgreSQL\14
    ) else (
        echo PostgreSQL not found. Please:
        echo    1. Install PostgreSQL from https://www.postgresql.org/download/windows/
        echo    2. Or set POSTGRESQL_PATH environment variable
        exit /b 1
    )
)

echo Dependencies found
echo Using PostgreSQL at: %POSTGRESQL_PATH%

REM Build godot-cpp first
echo Building godot-cpp for Windows...
cd godot-cpp
scons platform=windows target=template_debug arch=x86_64
if %errorlevel% neq 0 exit /b %errorlevel%

scons platform=windows target=template_release arch=x86_64
if %errorlevel% neq 0 exit /b %errorlevel%
cd ..

REM Build the extension
echo Building PostgreSQL extension for Windows...
scons platform=windows target=template_debug arch=x86_64
if %errorlevel% neq 0 exit /b %errorlevel%

scons platform=windows target=template_release arch=x86_64
if %errorlevel% neq 0 exit /b %errorlevel%

echo Windows build completed!
echo Debug library: bin\PostgreAdapter\build\libpostgreadapter.windows.template_debug.x86_64.dll
echo Release library: bin\PostgreAdapter\build\libpostgreadapter.windows.template_release.x86_64.dll