# WeMod Pro Unlocker - Automation Script
# Usage: Right-click > Run with PowerShell

$ErrorActionPreference = "Stop"

function Write-Color($text, $color) {
    Write-Host $text -ForegroundColor $color
}

# 1. Check Dependencies
Write-Color "[*] Checking for Node.js..." "Cyan"
if (-not (Get-Command node -ErrorAction SilentlyContinue)) {
    Write-Color "[!] Node.js is not installed. Please install it from https://nodejs.org/" "Red"
    Pause
    exit 1
}

# 2. Find WeMod Installation
Write-Color "[*] Locating WeMod..." "Cyan"
$localAppData = $env:LOCALAPPDATA
$wandDir = Join-Path $localAppData "Wand"

if (-not (Test-Path $wandDir)) {
    Write-Color "[!] WeMod (Wand) directory not found at $wandDir" "Red"
    Pause
    exit 1
}

# Get latest app version folder
$appDirs = Get-ChildItem -Path $wandDir -Directory -Filter "app-*" | Sort-Object Name -Descending
if ($appDirs.Count -eq 0) {
    Write-Color "[!] No WeMod app-* folders found." "Red"
    Pause
    exit 1
}

$latestApp = $appDirs[0]
$resourcesDir = Join-Path $latestApp.FullName "resources"
$asarPath = Join-Path $resourcesDir "app.asar"
$unpackedDir = Join-Path $resourcesDir "app_unpacked"

Write-Color "[+] Found WeMod version: $($latestApp.Name)" "Green"

# 3. Unpack ASAR
Write-Color "[*] Unpacking app.asar... (This may take a moment)" "Cyan"
if (Test-Path $unpackedDir) {
    Write-Color "[-] Cleaning up previous unpacked folder..." "Yellow"
    Remove-Item -Path $unpackedDir -Recurse -Force
}

Set-Location $resourcesDir
try {
    # check if npx is available
    if (-not (Get-Command npx -ErrorAction SilentlyContinue)) {
         Write-Color "[!] npx not found. Make sure standard Node.js installation is complete." "Red"
         Pause
         exit 1
    }
    # Using npx to run asar without global install
    cmd /c "npx -y asar extract app.asar app_unpacked"
} catch {
    Write-Color "[!] Failed to unpack asar: $_" "Red"
    Pause
    exit 1
}

# 4. Run Patcher
Write-Color "[*] Applying Pro patches..." "Cyan"
$scriptPath = Join-Path $PSScriptRoot "patch_wemod.js"
if (-not (Test-Path $scriptPath)) {
    Write-Color "[!] patch_wemod.js not found in working directory!" "Red"
    Pause
    exit 1
}

try {
    node $scriptPath "$unpackedDir"
} catch {
    Write-Color "[!] Patch script failed: $_" "Red"
    Pause
    exit 1
}

# 5. Repack ASAR
Write-Color "[*] Repacking app.asar..." "Cyan"
try {
    # Backup original
    if (-not (Test-Path "$asarPath.bak")) {
        Move-Item $asarPath "$asarPath.bak"
        Write-Color "[+] Backup created at app.asar.bak" "Gray"
    }
    
    cmd /c "npx -y asar pack app_unpacked app.asar"
} catch {
    Write-Color "[!] Failed to repack asar. Restoring backup..." "Red"
    if (Test-Path "$asarPath.bak") {
        Move-Item "$asarPath.bak" $asarPath -Force
    }
    Pause
    exit 1
}

# 6. Cleanup
Write-Color "[*] Cleaning up..." "Cyan"
if (Test-Path $unpackedDir) {
    Remove-Item -Path $unpackedDir -Recurse -Force
}

Write-Color "[SUCCESS] WeMod has been patched! You may now launch the app." "Green"
Write-Color "Press any key to exit..." "Gray"
$null = $Host.UI.RawUI.ReadKey("NoEcho,IncludeKeyDown")
