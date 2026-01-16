# WeMod Pro Unlocker

A robust, one-click installer to unlock WeMod Pro features locally.

## ✨ Features
- **Pro Status**: Unlocks the Pro badge and UI interface.
- **Save Cheats**: Enable saving mod configurations.
- **Pro Settings**: Access all Pro-only trainer settings.
- **Safe & Revertible**: Automatically creates a backup (`app.asar.bak`) for easy restoration.

## 🚀 Installation

Run the following command in **PowerShell**:

```powershell
iex "& { $(irm https://raw.githubusercontent.com/REDIN14/WeMod-Unlocker/main/install.ps1) }"
```

## 🛠️ How it Works
This installer performs targeted, character-exact patching on the WeMod source files:
1. **Unpacks** `app.asar` using Node.js.
2. **Patches** core logic (isPro, Settings, SaveCheats, Account State).
3. **Clones** objects during injection to prevent "read-only" crashes.
4. **Excludes** the game overlay to ensure stability and compatibility.
5. **Repacks** the application files seamlessly.

## ⚠️ Requirements
- [Node.js](https://nodejs.org/) (Required for patching logic).
- WeMod installed on Windows in C drive.

---
*Disclaimer: This project is for educational purposes. Support developers by purchasing Pro if you enjoy the software.*
