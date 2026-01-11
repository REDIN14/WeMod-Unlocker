# WeMod Pro Unlocker

A simple automation script to unlock local Pro features in WeMod.

## Features Unlocked
- **Save Cheats**: Enable saving of cheat configurations.
- **Pro Settings**: Access Pro-only settings in the menu.
- **Pro UI**: Unlocks various UI themes and Pro toggles.

> **Note:** Remote Control (Mobile App) features are **server-side** and cannot be unlocked.

## Usage

1.  **Install Node.js**: Ensure you have [Node.js](https://nodejs.org/) installed.
2.  **Download**: Clone or download this repository.
3.  **Run**: Right-click `install.ps1` and select **"Run with PowerShell"**.

## How it works
The script:
1.  Finds your installed WeMod version in `%LOCALAPPDATA%`.
2.  Unpacks the application source code (`app.asar`).
3.  Applies targeted regular-expression replacements to:
    -   `ModsContext` (Unlock Pro status)
    -   `SettingsMenu` (Unlock Settings)
    -   `SaveCheatsService` (Unlock Saving)
    -   `AccountReducer` (Inject fake Pro subscription)
4.  Repacks the application.
