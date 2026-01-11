# WeMod Pro Unlocker - One-Line Installer
# Usage: iex "& { $(irm https://raw.githubusercontent.com/REDIN14/WeMod-Unlocker/main/install.ps1) }"

$ErrorActionPreference = "Stop"

function Write-Color($text, $color) {
    Write-Host $text -ForegroundColor $color
}

# --- Embedded JS Patcher Content ---
$patcherJsContent = @'
const fs = require('fs');
const path = require('path');

// Get target directory from command line or use default
const TARGET_DIR = process.argv[2];

if (!TARGET_DIR) {
    console.error('Error: No target directory provided');
    process.exit(1);
}

console.log('Scanning directory: ' + TARGET_DIR);

if (!fs.existsSync(TARGET_DIR)) {
    console.error('Error: Directory not found: ' + TARGET_DIR);
    process.exit(1);
}

function getFiles(dir, fileList = []) {
    const files = fs.readdirSync(dir);
    for (const file of files) {
        const filePath = path.join(dir, file);
        const stat = fs.statSync(filePath);
        if (stat.isDirectory()) {
            getFiles(filePath, fileList);
        } else if (file.endsWith('.bundle.js')) {
            fileList.push(filePath);
        }
    }
    return fileList;
}

const jsFiles = getFiles(TARGET_DIR);
console.log('Found ' + jsFiles.length + ' JS bundle files.');

let patchesApplied = 0;

jsFiles.forEach(file => {
    const fileName = path.basename(file);
    const lowerName = fileName.toLowerCase();

    // Skip 'overlay' bundles to prevent crashes
    if (lowerName.includes('overlay')) {
        console.log('[i] Skipping ' + fileName);
        return;
    }

    let content = fs.readFileSync(file, 'utf8');
    let originalContent = content;
    let modified = false;

    // --- Patch 1: Unlock Pro in Trainer ---
    const isProTarget = 'get isPro(){return!!this.host?.account?.subscription}';
    if (content.includes(isProTarget)) {
        console.log('[Patch 1] Found isPro check in ' + fileName);
        content = content.replace(isProTarget, 'get isPro(){return!0}');
        modified = true;
    }

    // --- Patch 2: Show Pro-Only Settings ---
    const settingsTarget = '.proOnly&&!this.subscription';
    if (content.includes(settingsTarget)) {
        console.log('[Patch 2] Found proOnly settings filter in ' + fileName);
        content = content.replace(settingsTarget, '.proOnly&&!1');
        modified = true;
    }

    // --- Patch 3: Enable Save Cheats ---
    const saveCheatsTarget = 'get canUse(){return this.account&&!!this.account.subscription}';
    if (content.includes(saveCheatsTarget)) {
        console.log('[Patch 3] Found SaveCheats check in ' + fileName);
        content = content.replace(saveCheatsTarget, 'get canUse(){return!0}');
        modified = true;
    }

    // --- Patch 4: Account Reducer (Subscription Injection) ---
    const accountReducerTarget = 'return e.account&&JSON.stringify(t)===JSON.stringify(e.account)?e:{...e,account:t}';
    if (content.includes(accountReducerTarget)) {
        console.log('[Patch 4] Found Account Reducer in ' + fileName);
        const injection = 'if(t){t={...t,subscription:{id:"pro_unlock",plan:"yearly",status:"active",startedAt:"2022-01-01T00:00:00.000Z",currentPeriodEnd:"2099-01-01T00:00:00.000Z",remoteChannel:t.remoteChannel||null}}};' + accountReducerTarget;
        content = content.replace(accountReducerTarget, injection);
        modified = true;
    }

    if (modified && content !== originalContent) {
        fs.writeFileSync(file, content, 'utf8');
        console.log('> Applied patches to ' + fileName);
        patchesApplied++;
    }
});

if (patchesApplied === 0) {
    console.log('[!] No patches applied. Files may already be patched or code structure changed.');
} else {
    console.log('[+] Success! ' + patchesApplied + ' file(s) patched.');
}
'@

# --- Fuse Patcher Function ---
function Patch-ElectronFuse {
    param(
        [string]$ExePath
    )

    $sentinel = "dL7pKGdnNz796PbbjQWNKmHXBZaB9tsX"
    $FUSE_WIRE_OFFSET = 32 + 2  # sentinel length + header (01 08)
    $ASAR_INTEGRITY_FUSE_INDEX = 4  # EnableEmbeddedAsarIntegrityValidation is at index 4

    Write-Color "[*] Patching Electron fuse in $ExePath..." "Cyan"

    if (-not (Test-Path $ExePath)) {
        Write-Color "[!] Executable not found: $ExePath" "Red"
        return $false
    }

    # Create backup
    $backupPath = "$ExePath.bak"
    if (-not (Test-Path $backupPath)) {
        Write-Color "[+] Creating Wand.exe backup..." "Gray"
        Copy-Item -Path $ExePath -Destination $backupPath -Force
    } else {
        Write-Color "[i] Wand.exe backup already exists" "Yellow"
    }

    try {
        # Read file as bytes
        $bytes = [System.IO.File]::ReadAllBytes($ExePath)
        $content = [System.Text.Encoding]::GetEncoding('iso-8859-1').GetString($bytes)

        # Find sentinel
        $sentinelIndex = $content.IndexOf($sentinel)
        if ($sentinelIndex -lt 0) {
            Write-Color "[!] Electron fuse sentinel not found in binary" "Red"
            return $false
        }

        Write-Color "[+] Found fuse sentinel at offset: 0x$($sentinelIndex.ToString('X'))" "Green"

        # Calculate fuse position
        # Fuse wire: sentinel(32) + header(2) + fuse_index
        $fuseOffset = $sentinelIndex + $FUSE_WIRE_OFFSET + $ASAR_INTEGRITY_FUSE_INDEX
        $currentByte = $bytes[$fuseOffset]

        Write-Color "[*] ASAR Integrity fuse at offset 0x$($fuseOffset.ToString('X')): 0x$($currentByte.ToString('X2'))" "Cyan"

        if ($currentByte -eq 0x31) {
            # Fuse is enabled ('1'), disable it
            Write-Color "[*] Fuse is ENABLED (0x31). Disabling..." "Yellow"
            $bytes[$fuseOffset] = 0x30
            [System.IO.File]::WriteAllBytes($ExePath, $bytes)
            Write-Color "[+] Successfully disabled ASAR integrity validation fuse" "Green"
            return $true
        }
        elseif ($currentByte -eq 0x30) {
            Write-Color "[i] Fuse is already DISABLED (0x30). No changes needed." "Green"
            return $true
        }
        else {
            Write-Color "[!] Unexpected byte value at fuse offset: 0x$($currentByte.ToString('X2'))" "Red"
            Write-Color "[!] Expected 0x30 ('0') or 0x31 ('1')" "Red"
            return $false
        }
    }
    catch {
        Write-Color "[!] Error patching fuse: $_" "Red"
        return $false
    }
}

# --- Script Logic ---

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
$appDir = $latestApp.FullName
$resourcesDir = Join-Path $appDir "resources"
$asarPath = Join-Path $resourcesDir "app.asar"
$unpackedDir = Join-Path $resourcesDir "app_unpacked"
$wandExePath = Join-Path $appDir "Wand.exe"

Write-Color "[+] Found WeMod version: $($latestApp.Name)" "Green"

# 3. Patch Electron Fuse (CRITICAL - must be done before ASAR modification)
Write-Color "`n=== STEP 1: Patching Electron Fuse ===" "Magenta"
$fuseResult = Patch-ElectronFuse -ExePath $wandExePath
if (-not $fuseResult) {
    Write-Color "[!] Fuse patching failed. The app may not start after ASAR modification." "Red"
    Write-Color "[?] Continue anyway? (y/n)" "Yellow"
    $continue = Read-Host
    if ($continue -ne 'y') {
        Pause
        exit 1
    }
}

# 4. Unpack ASAR
Write-Color "`n=== STEP 2: Unpacking app.asar ===" "Magenta"
# Restore backup if exists to ensure clean slate
if (Test-Path "$asarPath.bak") {
    Write-Color "[i] Found ASAR backup. Restoring original to ensure clean patch..." "Yellow"
    Copy-Item -Path "$asarPath.bak" -Destination "$asarPath" -Force
}
else {
    Write-Color "[+] Creating ASAR backup at app.asar.bak" "Gray"
    Copy-Item -Path "$asarPath" -Destination "$asarPath.bak"
}

if (Test-Path $unpackedDir) {
    Write-Color "[-] Cleaning up previous unpacked folder..." "Yellow"
    Remove-Item -Path $unpackedDir -Recurse -Force
}

Set-Location $resourcesDir
try {
    if (-not (Get-Command npx -ErrorAction SilentlyContinue)) {
        Write-Color "[!] npx not found. Make sure Node.js is installed correctly." "Red"
        Pause
        exit 1
    }
    Write-Color "[*] Unpacking app.asar... (This may take a moment)" "Cyan"
    $null = cmd /c "npx -y asar extract app.asar app_unpacked 2>&1"
    if (-not (Test-Path $unpackedDir)) {
        throw "Unpacking failed - directory not created"
    }
}
catch {
    Write-Color "[!] Failed to unpack asar: $_" "Red"
    Pause
    exit 1
}

# 5. Run JS Patcher (Embedded)
Write-Color "`n=== STEP 3: Applying Pro patches ===" "Magenta"
$tempJsPath = Join-Path $env:TEMP "wemod_patcher_temp.js"
try {
    Set-Content -Path $tempJsPath -Value $patcherJsContent -Encoding UTF8
    node $tempJsPath "$unpackedDir"
}
catch {
    Write-Color "[!] Patch script execution failed: $_" "Red"
}
finally {
    if (Test-Path $tempJsPath) { Remove-Item $tempJsPath -Force }
}

# 6. Repack ASAR
Write-Color "`n=== STEP 4: Repacking app.asar ===" "Magenta"
try {
    Write-Color "[*] Repacking app.asar..." "Cyan"
    $null = cmd /c "npx -y asar pack app_unpacked app.asar 2>&1"
    if (-not (Test-Path $asarPath)) {
        throw "Repacking failed - asar not created"
    }
}
catch {
    Write-Color "[!] Failed to repack asar. Restoring backup..." "Red"
    if (Test-Path "$asarPath.bak") {
        Copy-Item "$asarPath.bak" $asarPath -Force
    }
    Pause
    exit 1
}

# 7. Cleanup
Write-Color "`n=== STEP 5: Cleanup ===" "Magenta"
if (Test-Path $unpackedDir) {
    Write-Color "[*] Removing unpacked directory..." "Cyan"
    Remove-Item -Path $unpackedDir -Recurse -Force
}

Write-Color "`n========================================" "Green"
Write-Color "[SUCCESS] WeMod has been patched!" "Green"
Write-Color "========================================" "Green"
Write-Color "You may now launch WeMod." "White"
Write-Color "`nPress any key to exit..." "Gray"
$null = $Host.UI.RawUI.ReadKey("NoEcho,IncludeKeyDown")
