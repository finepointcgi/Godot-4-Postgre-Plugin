# Manual DLL copying script for Windows PostgreSQL plugin
# Run this if the automatic bundling didn't work

param(
    [switch]$Help
)

if ($Help) {
    Write-Host @"
PostgreSQL Godot Plugin - Manual DLL Fix

USAGE:
    .\fix_windows_dlls.ps1

DESCRIPTION:
    This script manually copies required PostgreSQL DLLs to the plugin directory.
    Run this if you're still getting "Error 126: The specified module could not be found"

    The script will:
    1. Find your vcpkg or PostgreSQL installation
    2. Copy all required DLLs to Demo\bin\PostgreAdapter\
    3. Verify the plugin directory is complete

EXAMPLES:
    .\fix_windows_dlls.ps1
"@
    exit 0
}

$ErrorActionPreference = "Continue"

Write-Host "==========================================================" -ForegroundColor Cyan
Write-Host "PostgreSQL Godot Plugin - Manual DLL Fix" -ForegroundColor Cyan
Write-Host "==========================================================" -ForegroundColor Cyan
Write-Host ""

# Check if we're in the right directory
if (-not (Test-Path "Demo\bin\PostgreAdapter")) {
    Write-Host "[ERROR] Demo\bin\PostgreAdapter directory not found" -ForegroundColor Red
    Write-Host "        Run this from the plugin root directory after building" -ForegroundColor Red
    exit 1
}

$PluginDir = "Demo\bin\PostgreAdapter"
Write-Host "[INFO] Plugin directory: $PluginDir" -ForegroundColor Blue
Write-Host ""

# Required DLLs
$RequiredDLLs = @(
    "libpq.dll"
)

$ImportantDLLs = @(
    "pqxx.dll",
    "libpqxx.dll"
)

$SSLDLLs = @(
    "libcrypto-3-x64.dll",
    "libssl-3-x64.dll",
    "libcrypto-1_1-x64.dll", 
    "libssl-1_1-x64.dll",
    "libeay32.dll",
    "ssleay32.dll"
)

$RuntimeDLLs = @(
    "msvcp140.dll",
    "vcruntime140.dll",
    "vcruntime140_1.dll"
)

# Find source directories
$SourceDirs = @()

# Check vcpkg
if ($env:VCPKG_ROOT -and (Test-Path $env:VCPKG_ROOT)) {
    $VcpkgBin = Join-Path $env:VCPKG_ROOT "installed\x64-windows\bin"
    if (Test-Path $VcpkgBin) {
        $SourceDirs += $VcpkgBin
        Write-Host "[OK] Found vcpkg bin: $VcpkgBin" -ForegroundColor Green
    }
}

# Check PostgreSQL installations
$PgPaths = @(
    "C:\Program Files\PostgreSQL\16\bin",
    "C:\Program Files\PostgreSQL\15\bin", 
    "C:\Program Files\PostgreSQL\14\bin"
)

foreach ($PgPath in $PgPaths) {
    if (Test-Path $PgPath) {
        $SourceDirs += $PgPath
        Write-Host "[OK] Found PostgreSQL bin: $PgPath" -ForegroundColor Green
    }
}

# Check system paths
$SystemPaths = @(
    "C:\Windows\System32"
)

foreach ($SysPath in $SystemPaths) {
    if (Test-Path $SysPath) {
        $SourceDirs += $SysPath
    }
}

if ($SourceDirs.Count -eq 0) {
    Write-Host "[ERROR] No PostgreSQL or vcpkg installations found!" -ForegroundColor Red
    Write-Host "        Please install PostgreSQL or set up vcpkg first" -ForegroundColor Red
    exit 1
}

Write-Host ""
Write-Host "Searching in $($SourceDirs.Count) source directories..." -ForegroundColor Blue
Write-Host ""

# Function to copy DLL if found
function Copy-DLLIfFound {
    param($DLLName, $SourceDirs, $TargetDir, $Label)
    
    foreach ($SourceDir in $SourceDirs) {
        $SourcePath = Join-Path $SourceDir $DLLName
        if (Test-Path $SourcePath) {
            $TargetPath = Join-Path $TargetDir $DLLName
            try {
                Copy-Item $SourcePath $TargetPath -Force
                Write-Host "  ✓ Copied $Label`: $DLLName" -ForegroundColor Green
                return $true
            }
            catch {
                Write-Host "  ✗ Failed to copy ${DLLName}: $($_.Exception.Message)" -ForegroundColor Red
            }
        }
    }
    return $false
}

$CopiedCount = 0
$MissingRequired = @()

# Copy required DLLs
Write-Host "Copying required DLLs:" -ForegroundColor Yellow
foreach ($DLL in $RequiredDLLs) {
    if (Copy-DLLIfFound $DLL $SourceDirs $PluginDir "required") {
        $CopiedCount++
    } else {
        Write-Host "  ✗ Required DLL not found: $DLL" -ForegroundColor Red
        $MissingRequired += $DLL
    }
}

# Copy important DLLs (C++ wrapper)
Write-Host "`nCopying C++ wrapper DLLs:" -ForegroundColor Yellow
$CppWrapperFound = $false
foreach ($DLL in $ImportantDLLs) {
    if (Copy-DLLIfFound $DLL $SourceDirs $PluginDir "C++ wrapper") {
        $CopiedCount++
        $CppWrapperFound = $true
        break  # Only need one
    }
}

if (-not $CppWrapperFound) {
    Write-Host "  ⚠ Warning: No C++ wrapper DLL found (pqxx.dll or libpqxx.dll)" -ForegroundColor Yellow
}

# Copy SSL DLLs
Write-Host "`nCopying SSL/crypto DLLs:" -ForegroundColor Yellow
$CryptoFound = $false
$SSLFound = $false
foreach ($DLL in $SSLDLLs) {
    if (Copy-DLLIfFound $DLL $SourceDirs $PluginDir "SSL/crypto") {
        $CopiedCount++
        if ($DLL -match "crypto") { $CryptoFound = $true }
        if ($DLL -match "ssl") { $SSLFound = $true }
    }
}

if (-not $CryptoFound) {
    Write-Host "  ⚠ Warning: No crypto library found" -ForegroundColor Yellow
}
if (-not $SSLFound) {
    Write-Host "  ⚠ Warning: No SSL library found" -ForegroundColor Yellow
}

# Copy runtime DLLs
Write-Host "`nCopying runtime DLLs:" -ForegroundColor Yellow
$RuntimeFound = $false
foreach ($DLL in $RuntimeDLLs) {
    if (Copy-DLLIfFound $DLL $SourceDirs $PluginDir "runtime") {
        $CopiedCount++
        $RuntimeFound = $true
        break  # Only need one set
    }
}

Write-Host ""
Write-Host "==========================================================" -ForegroundColor Cyan
Write-Host "COPY COMPLETE" -ForegroundColor Cyan  
Write-Host "==========================================================" -ForegroundColor Cyan
Write-Host ""

Write-Host "Summary:" -ForegroundColor Blue
Write-Host "  Copied $CopiedCount DLL files" -ForegroundColor Green

if ($MissingRequired.Count -gt 0) {
    Write-Host "  ✗ Missing required DLLs: $($MissingRequired -join ', ')" -ForegroundColor Red
}

# Show final directory contents
$FinalDLLs = Get-ChildItem $PluginDir -Filter "*.dll" | ForEach-Object { $_.Name }
Write-Host "  Final DLLs in plugin directory:" -ForegroundColor Blue
foreach ($DLL in $FinalDLLs) {
    Write-Host "    $DLL" -ForegroundColor Gray
}

Write-Host ""
if ($MissingRequired.Count -eq 0) {
    Write-Host "✓ Plugin should now load correctly in Godot!" -ForegroundColor Green
    Write-Host "" 
    Write-Host "Next steps:" -ForegroundColor Blue
    Write-Host "  1. Open your Godot project" -ForegroundColor White
    Write-Host "  2. Check that the plugin loads without Error 126" -ForegroundColor White
    Write-Host "  3. Test PostgreSQL connection functionality" -ForegroundColor White
} else {
    Write-Host "✗ Some required DLLs are still missing" -ForegroundColor Red
    Write-Host "" 
    Write-Host "Try these solutions:" -ForegroundColor Blue
    Write-Host "  1. Install Visual C++ Redistributable 2022 x64" -ForegroundColor White
    Write-Host "  2. Set up vcpkg with: .\setup_vcpkg_windows.bat" -ForegroundColor White
    Write-Host "  3. Check Windows Event Viewer for detailed error messages" -ForegroundColor White
}

Write-Host ""