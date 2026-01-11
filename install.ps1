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

// Configuration
const defaultPath = path.join(process.env.LOCALAPPDATA, 'Wand', 'app-12.6.0', 'resources', 'app_unpacked');
const TARGET_DIR = process.argv[2] || defaultPath;

console.log(`Scanning directory: ${TARGET_DIR}`);

if (!fs.existsSync(TARGET_DIR)) {
    console.error(`Error: Directory not found: ${TARGET_DIR}`);
    console.error("Please make sure WeMod is installed and you are pointing to the correct version folder.");
    process.exit(1);
}

function getFiles(dir, fileList = []) {
    const files = fs.readdirSync(dir);
    for (const file of files) {
        const filePath = path.join(dir, file);
        const stat = fs.statSync(filePath);
        if (stat.isDirectory()) {
            getFiles(filePath, fileList);
        } else {
            if (file.endsWith('.bundle.js')) {
                fileList.push(filePath);
            }
        }
    }
    return fileList;
}

const jsFiles = getFiles(TARGET_DIR);
console.log(`Found ${jsFiles.length} JS bundle files.`);

let patchesApplied = 0;

jsFiles.forEach(file => {
    const fileName = path.basename(file);
    const lowerName = fileName.toLowerCase();
    
    // Debug Log
    // console.log(`Checking: ${fileName}`);

    // CRITICAL: Skip 'overlay' bundles.
    if (lowerName.includes('overlay')) {
        console.log(`[i] Skipping excluded file: ${fileName}`);
        return;
    }

    let content = fs.readFileSync(file, 'utf8');
    let originalContent = content;
    let modified = false;

    // --- Patch 1: Unlock Pro in Trainer ---
    // Exact string from manual session audit
    const isProTarget = 'get isPro(){return!!this.host?.account?.subscription}';
    if (content.includes(isProTarget)) {
        console.log(`[Patch 1] Found 'isPro' check in ${path.basename(file)}`);
        content = content.replace(isProTarget, 'get isPro(){return!0}');
        modified = true;
    }

    // --- Patch 2: Show Pro-Only Settings ---
    // Exact string from manual session audit
    // Note: The variable 't' was observed in 'app-9aed85ed...'. 
    // If variable names change per file, this might be fragile, but it worked when we did it manually.
    // 't.proOnly&&!this.subscription'
    const settingsTarget = '.proOnly&&!this.subscription'; // Removed 't' to be slightly more robust but still simple string match
    // Actually, replacing '.proOnly&&!this.subscription' with '.proOnly&&!1' works regardless of variable name
    if (content.includes(settingsTarget)) {
        console.log(`[Patch 2] Found 'proOnly' settings filter in ${path.basename(file)}`);
        content = content.replace(settingsTarget, '.proOnly&&!1');
        modified = true;
    }

    // --- Patch 3: Enable Save Cheats ---
    // Exact string from manual session audit
    const saveCheatsTarget = 'get canUse(){return this.account&&!!this.account.subscription}';
    if (content.includes(saveCheatsTarget)) {
        console.log(`[Patch 3] Found 'SaveCheats' check in ${path.basename(file)}`);
        content = content.replace(saveCheatsTarget, 'get canUse(){return!0}');
        modified = true;
    }
    
    // --- Patch 4: Account Reducer ---
    // Re-enabled with SAFE CLONING strategy.
    // We match the exact string, which guarantees variables are 'e' and 't'.
    // We prepend logic to clone 't' and add the subscription, avoiding mutation of frozen objects.
    const accountReducerTarget = 'return e.account&&JSON.stringify(t)===JSON.stringify(e.account)?e:{...e,account:t}';
    
    if (content.includes(accountReducerTarget)) {
        console.log('[Patch 4] Found Account Reducer in ' + path.basename(file));
        
        // Safe injection with cloning
        const injection = 'if(t){t={...t,subscription:{id:"pro_unlock",plan:"yearly",status:"active",startedAt:"2022-01-01T00:00:00.000Z",currentPeriodEnd:"2099-01-01T00:00:00.000Z",remoteChannel:t.remoteChannel||null}}};' + accountReducerTarget;
        
        content = content.replace(accountReducerTarget, injection);
        modified = true;
    }
    if (content !== originalContent) {
        fs.writeFileSync(file, content, 'utf8');
        console.log('> Applied patches to ' + path.basename(file));
        patchesApplied++;
    }
});

if (patchesApplied === 0) {
    console.log("No patches were applied. Logic might have changed or files are already patched.");
} else {
    console.log("Success! Patches applied. Please restart WeMod.");
}
'@

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
$resourcesDir = Join-Path $latestApp.FullName "resources"
$asarPath = Join-Path $resourcesDir "app.asar"
$unpackedDir = Join-Path $resourcesDir "app_unpacked"
Write-Color "[+] Found WeMod version: $($latestApp.Name)" "Green"

# 3. Unpack ASAR
Write-Color "[*] Unpacking app.asar... (This may take a moment)" "Cyan"
# Restore backup if exists to ensure clean slate
if (Test-Path "$asarPath.bak") {
    Write-Color "[i] Found backup. Restoring original app.asar to ensure clean patch..." "Yellow"
    Copy-Item -Path "$asarPath.bak" -Destination "$asarPath" -Force
}
else {
    Write-Color "[+] Creating backup at app.asar.bak" "Gray"
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
    cmd /c "npx -y asar extract app.asar app_unpacked"
}
catch {
    Write-Color "[!] Failed to unpack asar: $_" "Red"
    Pause
    exit 1
}

# 4. Run JS Patcher (Embedded)
Write-Color "[*] Applying Pro patches..." "Cyan"
$tempJsPath = Join-Path $env:TEMP "wemod_patcher_temp.js"
try {
    Set-Content -Path $tempJsPath -Value $patcherJsContent -Encoding UTF8
    node $tempJsPath "$unpackedDir"
}
catch {
    Write-Color "[!] Patch script execution failed: $_" "Red"
}
finally {
    if (Test-Path $tempJsPath) { Remove-Item $tempJsPath }
}

# 5. Repack ASAR
Write-Color "[*] Repacking app.asar..." "Cyan"
try {
    cmd /c "npx -y asar pack app_unpacked app.asar"
}
catch {
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
