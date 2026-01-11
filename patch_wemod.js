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

// Helper to recurse files
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
    let content = fs.readFileSync(file, 'utf8');
    let originalContent = content;
    let modified = false;

    // --- Patch 1: Unlock Pro in Trainer (ModsContext) ---
    // Target: get isPro(){return!!this.host?.account?.subscription}
    // Regex allows for optional spaces or minor minification differences
    const proRegex = /get isPro\(\)\{return!!this\.host\?\.account\?\.subscription\}/g;
    if (proRegex.test(content)) {
        console.log(`[Patch 1] Found 'isPro' check in ${path.basename(file)}`);
        content = content.replace(proRegex, 'get isPro(){return!0}'); // !0 is true
        modified = true;
    }

    // --- Patch 2: Show Pro-Only Settings (SettingsMenu) ---
    // Target: t.proOnly&&!this.subscription
    // Capture 't' variable name blindly
    const settingsRegex = /(\w+)\.proOnly&&!this\.subscription/g;
    if (settingsRegex.test(content)) {
        console.log(`[Patch 2] Found 'proOnly' settings filter in ${path.basename(file)}`);
        content = content.replace(settingsRegex, '$1.proOnly&&!1'); // !1 is false
        modified = true;
    }

    // --- Patch 3: Enable Save Cheats (SaveCheatsService) ---
    // Target: get canUse(){return this.account&&!!this.account.subscription}
    const saveCheatsRegex = /get canUse\(\)\{return this\.account&&!!this\.account\.subscription\}/g;
    if (saveCheatsRegex.test(content)) {
        console.log(`[Patch 3] Found 'SaveCheats' check in ${path.basename(file)}`);
        content = content.replace(saveCheatsRegex, 'get canUse(){return!0}'); // true
        modified = true;
    }

    // --- Patch 4: Inject Fake Pro Subscription (Account Reducer) ---
    // Target: return e.account && JSON.stringify(t) === JSON.stringify(e.account) ? e : { ...e, account: t }
    // We match the return structure to find where to inject the subscription.
    // $1 = state var (e), $2 = payload var (t)
    const accountReducerRegex = /return (\w+)\.account&&JSON\.stringify\((\w+)\)===JSON\.stringify\(\1\.account\)\?\1:{\.\.\.\1,account:\2}/g;
    if (accountReducerRegex.test(content)) {
        console.log(`[Patch 4] Found 'Account Reducer' in ${path.basename(file)}`);
        // We inject the subscription assignment BEFORE the return.
        // Since we are replacing a 'return ...', we replace it with 't.subscription={...}; return ...'
        // But we likely need to wrap it in a block if it's an arrow function implied return, 
        // however, the reducer signature 'function(e,t){...}' usually has a body. 
        // The regex matches the specific return line.

        // Subscription Object
        const subObj = '{id:"pro_unlock",plan:"yearly",status:"active",startedAt:"2022-01-01T00:00:00.000Z",currentPeriodEnd:"2099-01-01T00:00:00.000Z",remoteChannel:$2.remoteChannel}';

        content = content.replace(accountReducerRegex, (match, stateVar, payloadVar) => {
            return `${payloadVar}.subscription=${subObj};return ${match}`;
        });
        modified = true;
    }

    if (modified) {
        if (content !== originalContent) {
            fs.writeFileSync(file, content, 'utf8');
            console.log(`> Applied patches to ${path.basename(file)}`);
            patchesApplied++;
        }
    }
});

if (patchesApplied === 0) {
    console.log("No patches were applied. Logic might have changed or files are already patched.");
} else {
    console.log("Success! Patches applied. Please restart WeMod.");
}
