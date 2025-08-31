# PowerShell script to download and copy PostgreSQL DLLs
param(
    [string]$OutputDir = "Demo\bin\PostgreAdapter"
)

$ErrorActionPreference = "Stop"

# Required DLLs
$requiredDlls = @(
    "pqxx.dll",
    "libpq.dll", 
    "libcrypto-3-x64.dll",
    "libssl-3-x64.dll"
)

Write-Host "Downloading PostgreSQL DLLs for Windows distribution..." -ForegroundColor Green
Write-Host "Output directory: $OutputDir" -ForegroundColor Yellow

# Create output directory if it doesn't exist
if (-not (Test-Path $OutputDir)) {
    Write-Host "Creating directory: $OutputDir" -ForegroundColor Yellow
    New-Item -Path $OutputDir -ItemType Directory -Force | Out-Null
}

# Function to download file
function Download-File {
    param(
        [string]$Url,
        [string]$OutputPath
    )
    
    try {
        Write-Host "Downloading $(Split-Path $OutputPath -Leaf)..." -ForegroundColor Cyan
        $webClient = New-Object System.Net.WebClient
        $webClient.DownloadFile($Url, $OutputPath)
        Write-Host "  Successfully downloaded to $OutputPath" -ForegroundColor Green
        return $true
    }
    catch {
        Write-Host "  Failed to download from $Url" -ForegroundColor Red
        Write-Host "  Error: $($_.Exception.Message)" -ForegroundColor Red
        return $false
    }
}

# Alternative: Try to find DLLs in common locations first
$searchPaths = @(
    "$env:VCPKG_ROOT\installed\x64-windows\bin",
    "$env:POSTGRESQL_PATH\bin",
    "$env:POSTGRESQL_PATH\lib", 
    "C:\Program Files\PostgreSQL\16\bin",
    "C:\Program Files\PostgreSQL\15\bin", 
    "C:\Program Files\PostgreSQL\14\bin",
    "C:\Program Files\OpenSSL-Win64\bin",
    "C:\OpenSSL-Win64\bin",
    "C:\tools\vcpkg\installed\x64-windows\bin",
    "$env:SystemRoot\System32"
)

Write-Host "Searching for DLLs in common locations..." -ForegroundColor Yellow

foreach ($dll in $requiredDlls) {
    $found = $false
    
    foreach ($path in $searchPaths) {
        if ($path -and (Test-Path $path)) {
            $dllPath = Join-Path $path $dll
            if (Test-Path $dllPath) {
                $outputPath = Join-Path $OutputDir $dll
                try {
                    Copy-Item $dllPath $outputPath -Force
                    Write-Host "  Found and copied: $dll from $path" -ForegroundColor Green
                    $found = $true
                    break
                }
                catch {
                    Write-Host "  Failed to copy $dll from $path" -ForegroundColor Red
                }
            }
        }
    }
    
    if (-not $found) {
        Write-Host "  Could not find $dll in any search path" -ForegroundColor Red
    }
}

# Download PostgreSQL portable binaries if DLLs not found locally
$missingDlls = @()
foreach ($dll in $requiredDlls) {
    $dllPath = Join-Path $OutputDir $dll
    if (-not (Test-Path $dllPath) -or (Get-Item $dllPath).Length -lt 1000) {
        $missingDlls += $dll
    }
}

if ($missingDlls.Count -gt 0) {
    Write-Host "`nAttempting to download missing DLLs..." -ForegroundColor Yellow
    
    # Create temp directory
    $tempDir = Join-Path $env:TEMP "postgres_dlls"
    if (Test-Path $tempDir) {
        Remove-Item $tempDir -Recurse -Force
    }
    New-Item -Path $tempDir -ItemType Directory -Force | Out-Null
    
    # Download PostgreSQL portable
    $postgresUrl = "https://get.enterprisedb.com/postgresql/postgresql-16.4-1-windows-x64-binaries.zip"
    $postgresZip = Join-Path $tempDir "postgresql.zip"
    
    Write-Host "Downloading PostgreSQL binaries..." -ForegroundColor Cyan
    try {
        $webClient = New-Object System.Net.WebClient
        $webClient.DownloadFile($postgresUrl, $postgresZip)
        
        # Extract PostgreSQL
        Write-Host "Extracting PostgreSQL binaries..." -ForegroundColor Cyan
        Add-Type -AssemblyName System.IO.Compression.FileSystem
        [System.IO.Compression.ZipFile]::ExtractToDirectory($postgresZip, $tempDir)
        
        # Find and copy libpq.dll
        $libpqPath = Get-ChildItem -Path $tempDir -Name "libpq.dll" -Recurse | Select-Object -First 1
        if ($libpqPath) {
            $sourcePath = Join-Path $tempDir $libpqPath
            $destPath = Join-Path $OutputDir "libpq.dll"
            Copy-Item $sourcePath $destPath -Force
            Write-Host "  Downloaded and copied: libpq.dll" -ForegroundColor Green
        }
        
        # Look for other PostgreSQL DLLs
        $pgDlls = Get-ChildItem -Path $tempDir -Name "*.dll" -Recurse
        foreach ($pgDll in $pgDlls) {
            $dllName = Split-Path $pgDll -Leaf
            if ($requiredDlls -contains $dllName) {
                $sourcePath = Join-Path $tempDir $pgDll
                $destPath = Join-Path $OutputDir $dllName
                Copy-Item $sourcePath $destPath -Force
                Write-Host "  Downloaded and copied: $dllName" -ForegroundColor Green
            }
        }
    }
    catch {
        Write-Host "Failed to download PostgreSQL binaries: $($_.Exception.Message)" -ForegroundColor Red
    }
    
    # Download OpenSSL DLLs
    Write-Host "Downloading OpenSSL DLLs..." -ForegroundColor Cyan
    $opensslDlls = @{
        "libcrypto-3-x64.dll" = "https://download.firedaemon.com/FireDaemon-OpenSSL/openssl-3.0.15/openssl-x64.zip"
        "libssl-3-x64.dll" = "https://download.firedaemon.com/FireDaemon-OpenSSL/openssl-3.0.15/openssl-x64.zip"
    }
    
    foreach ($dllName in @("libcrypto-3-x64.dll", "libssl-3-x64.dll")) {
        $dllPath = Join-Path $OutputDir $dllName
        if (-not (Test-Path $dllPath) -or (Get-Item $dllPath).Length -lt 1000) {
            try {
                $opensslZip = Join-Path $tempDir "openssl.zip"
                if (-not (Test-Path $opensslZip)) {
                    $webClient = New-Object System.Net.WebClient
                    $webClient.DownloadFile($opensslDlls[$dllName], $opensslZip)
                }
                
                # Extract and find DLL
                $opensslDir = Join-Path $tempDir "openssl"
                if (-not (Test-Path $opensslDir)) {
                    [System.IO.Compression.ZipFile]::ExtractToDirectory($opensslZip, $opensslDir)
                }
                
                $sslDllPath = Get-ChildItem -Path $opensslDir -Name $dllName -Recurse | Select-Object -First 1
                if ($sslDllPath) {
                    $sourcePath = Join-Path $opensslDir $sslDllPath
                    Copy-Item $sourcePath $dllPath -Force
                    Write-Host "  Downloaded and copied: $dllName" -ForegroundColor Green
                }
            }
            catch {
                Write-Host "Failed to download $dllName`: $($_.Exception.Message)" -ForegroundColor Red
            }
        }
    }
    
    # Clean up temp directory
    Remove-Item $tempDir -Recurse -Force -ErrorAction SilentlyContinue
}

# Final verification
Write-Host "`nFinal verification:" -ForegroundColor Yellow
foreach ($dll in $requiredDlls) {
    $dllPath = Join-Path $OutputDir $dll
    if (Test-Path $dllPath) {
        $size = (Get-Item $dllPath).Length
        if ($size -gt 1000) {
            Write-Host "  Found: $dll ($size bytes)" -ForegroundColor Green
        } else {
            Write-Host "  Stub: $dll ($size bytes) - needs real DLL" -ForegroundColor Yellow
        }
    }
    else {
        Write-Host "  Missing: $dll" -ForegroundColor Red
    }
}

Write-Host "`nDLL copy process completed." -ForegroundColor Green
Write-Host "Note: Make sure these DLLs are distributed alongside your GDExtension for proper runtime dependency resolution." -ForegroundColor Yellow