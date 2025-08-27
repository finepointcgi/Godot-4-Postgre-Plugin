# PostgreSQL Godot Plugin - Windows Dependencies Setup Script
# This script helps locate and copy required PostgreSQL DLLs for the Godot plugin

param(
    [string]$PostgreSQLPath = "",
    [switch]$Help
)

if ($Help) {
    Write-Host @"
PostgreSQL Godot Plugin - Windows Dependencies Setup

USAGE:
    .\setup_windows_dependencies.ps1 [-PostgreSQLPath <path>]

PARAMETERS:
    -PostgreSQLPath    Optional path to PostgreSQL installation
                      If not provided, script will search common locations

EXAMPLES:
    .\setup_windows_dependencies.ps1
    .\setup_windows_dependencies.ps1 -PostgreSQLPath "C:\Program Files\PostgreSQL\15"

DESCRIPTION:
    This script locates PostgreSQL DLL dependencies and copies them to the
    correct location for the Godot PostgreSQL plugin to function on Windows.

    Required DLLs:
    - pqxx.dll (libpqxx library)
    - libpq.dll (PostgreSQL client library)
    - libcrypto-3-x64.dll (OpenSSL crypto)
    - libssl-3-x64.dll (OpenSSL SSL)
"@
    exit 0
}

$ErrorActionPreference = "Stop"

# Define the target directory
$TargetDir = Join-Path $PSScriptRoot "Demo\bin\PostgreAdapter"
$RequiredDLLs = @("libpq.dll", "libcrypto-3-x64.dll", "libssl-3-x64.dll")
$OptionalDLLs = @("pqxx.dll")

Write-Host "PostgreSQL Godot Plugin - Windows Dependencies Setup" -ForegroundColor Cyan
Write-Host "======================================================" -ForegroundColor Cyan
Write-Host ""

# Create target directory if it doesn't exist
if (-not (Test-Path $TargetDir)) {
    Write-Host "Creating target directory: $TargetDir" -ForegroundColor Yellow
    New-Item -ItemType Directory -Path $TargetDir -Force | Out-Null
}

# Function to search for PostgreSQL installations
function Find-PostgreSQLInstallations {
    $CommonPaths = @(
        "${env:ProgramFiles}\PostgreSQL\*\bin",
        "${env:ProgramFiles(x86)}\PostgreSQL\*\bin",
        "${env:LOCALAPPDATA}\Programs\PostgreSQL\*\bin",
        "C:\PostgreSQL\*\bin"
    )
    
    $FoundPaths = @()
    foreach ($PathPattern in $CommonPaths) {
        $Paths = Get-ChildItem -Path $PathPattern -ErrorAction SilentlyContinue
        if ($Paths) {
            $FoundPaths += $Paths.FullName
        }
    }
    
    return $FoundPaths
}

# Function to check if a directory contains required DLLs
function Test-PostgreSQLBinDirectory {
    param([string]$Path)
    
    $FoundCount = 0
    foreach ($DLL in $RequiredDLLs) {
        if (Test-Path (Join-Path $Path $DLL)) {
            $FoundCount++
        }
    }
    return $FoundCount
}

# Determine PostgreSQL installation path
$PostgreSQLBinPaths = @()

if ($PostgreSQLPath) {
    if (Test-Path $PostgreSQLPath) {
        $BinPath = if ($PostgreSQLPath.EndsWith("bin")) { $PostgreSQLPath } else { Join-Path $PostgreSQLPath "bin" }
        if (Test-Path $BinPath) {
            $PostgreSQLBinPaths += $BinPath
        }
    } else {
        Write-Warning "Specified PostgreSQL path does not exist: $PostgreSQLPath"
    }
}

if ($PostgreSQLBinPaths.Count -eq 0) {
    Write-Host "Searching for PostgreSQL installations..." -ForegroundColor Yellow
    $PostgreSQLBinPaths = Find-PostgreSQLInstallations
}

if ($PostgreSQLBinPaths.Count -eq 0) {
    Write-Host "No PostgreSQL installations found!" -ForegroundColor Red
    Write-Host ""
    Write-Host "MANUAL INSTALLATION REQUIRED:" -ForegroundColor Yellow
    Write-Host "1. Install PostgreSQL from: https://www.postgresql.org/download/windows/"
    Write-Host "2. Run this script again, or"
    Write-Host "3. Manually copy these DLLs to $TargetDir:" -ForegroundColor Yellow
    foreach ($DLL in $RequiredDLLs) {
        Write-Host "   - $DLL" -ForegroundColor White
    }
    foreach ($DLL in $OptionalDLLs) {
        Write-Host "   - $DLL (optional)" -ForegroundColor Gray
    }
    exit 1
}

# Find the best PostgreSQL installation
$BestPath = $null
$BestScore = 0

foreach ($Path in $PostgreSQLBinPaths) {
    $Score = Test-PostgreSQLBinDirectory -Path $Path
    Write-Host "Found PostgreSQL at: $Path (contains $Score/$($RequiredDLLs.Count) required DLLs)" -ForegroundColor Green
    
    if ($Score -gt $BestScore) {
        $BestScore = $Score
        $BestPath = $Path
    }
}

if (-not $BestPath -or $BestScore -eq 0) {
    Write-Host "No suitable PostgreSQL installation found with required DLLs!" -ForegroundColor Red
    exit 1
}

Write-Host ""
Write-Host "Using PostgreSQL installation: $BestPath" -ForegroundColor Green
Write-Host "Copying DLLs to: $TargetDir" -ForegroundColor Green
Write-Host ""

# Copy DLLs
$CopiedCount = 0
$MissingDLLs = @()

foreach ($DLL in ($RequiredDLLs + $OptionalDLLs)) {
    $SourcePath = Join-Path $BestPath $DLL
    $TargetPath = Join-Path $TargetDir $DLL
    
    if (Test-Path $SourcePath) {
        Copy-Item $SourcePath $TargetPath -Force
        Write-Host "✓ Copied: $DLL" -ForegroundColor Green
        $CopiedCount++
    } else {
        if ($DLL -in $RequiredDLLs) {
            Write-Host "✗ Missing required DLL: $DLL" -ForegroundColor Red
            $MissingDLLs += $DLL
        } else {
            Write-Host "- Optional DLL not found: $DLL" -ForegroundColor Yellow
        }
    }
}

Write-Host ""

if ($MissingDLLs.Count -eq 0) {
    Write-Host "SUCCESS! All required dependencies have been copied." -ForegroundColor Green
    Write-Host "The PostgreSQL Godot plugin should now work correctly." -ForegroundColor Green
    Write-Host ""
    Write-Host "NEXT STEPS:" -ForegroundColor Cyan
    Write-Host "1. Open your Godot project"
    Write-Host "2. Check that the plugin loads without Error 126"
    Write-Host "3. Configure your PostgreSQL connection string in the demo"
} else {
    Write-Host "WARNING: Some required DLLs are still missing:" -ForegroundColor Red
    foreach ($DLL in $MissingDLLs) {
        Write-Host "  - $DLL" -ForegroundColor Red
    }
    Write-Host ""
    Write-Host "You may need to:" -ForegroundColor Yellow
    Write-Host "1. Install a complete PostgreSQL distribution"
    Write-Host "2. Install libpqxx separately"
    Write-Host "3. Manually locate and copy the missing DLLs"
}

Write-Host ""
Write-Host "Files in target directory:" -ForegroundColor Gray
Get-ChildItem $TargetDir | ForEach-Object {
    Write-Host "  $($_.Name)" -ForegroundColor Gray
}