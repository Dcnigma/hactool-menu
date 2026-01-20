# Switch LayeredFS Mod Toolkit

A terminal-based toolkit for extracting Nintendo Switch NSP/XCI files and building **Atmosphère LayeredFS mods** using an interactive `dialog` UI.

This tool allows you to:
- Extract NSP/XCI containers
- Merge RomFS from base, patch, and DLC NCAs
- Browse and selectively stage RomFS / ExeFS files
- Manage mod profiles
- Export **properly structured Atmosphère ZIPs** ready for SD card use

---

## ✨ Features

- 📦 Extract NSP/XCI using `hactool`
- 🧩 Automatic RomFS merge (base → patch → DLC)
- 🗂 Interactive file selection via `dialog`
- 🧪 Staging area before committing to a mod profile
- 📁 Multiple mod profiles per game
- 🌌 Correct Atmosphère layout:
atmosphere/
contents/
<TITLEID>/
romfs/
exefs/


- 🧾 Persistent logging (even when dialogs hide errors)
- 🔒 Bulletproof ZIP creation (no nested paths, no `_ .zip` bugs)

## 📋 Requirements

### macOS (Homebrew)
```bash
brew install dialog zip rsync
Linux (Debian/Ubuntu)
bash
sudo apt install dialog zip rsync
External tools
hactool
Nintendo Switch prod.keys

Both must be placed next to the script:

./hactool
./prod.keys
```bash

## 🚀 Usage
Make the script executable:

chmod +x toolkit.sh
./toolkit.sh
You will be presented with a menu:

1 Extract NSP/XCI
2 Browse + Stage
3 Sync staging → profile
4 Export Atmosphère ZIP

## 🧱 Workflow Overview
1️⃣ Extract NSP/XCI
Extracts all NCAs

# Automatically categorizes them into:

base
patch
DLC

# Merges RomFS layers in correct priority order

## 2️⃣ Browse + Stage
Browse merged RomFS or individual ExeFS

Select files or folders

Copies them into a staging area

## 3️⃣ Sync staging → profile
Saves staged changes into a named mod profile

Profiles are stored in:

php-template
Code kopiëren
<game>_workspace/mods/<profile>/

## 4️⃣ Export Atmosphère ZIP
Detects TITLEID automatically (or asks)

Builds correct Atmosphère folder structure

Creates a ZIP with atmosphere/ as root

Output:

php-template
Code kopiëren
<game>_workspace/exports/<profile>.zip

## 🗃 Directory Structure
<game>_workspace/
├─ container/          # Extracted NSP/XCI contents
├─ ncas/
│  ├─ base/
│  ├─ patch/
│  └─ dlc/
├─ merged/romfs/       # Fully merged RomFS
├─ staging/
│  ├─ romfs/
│  └─ exefs/
├─ mods/
│  └─ <profile>/
│     ├─ romfs/
│     └─ exefs/
├─ exports/
│  └─ <profile>.zip
├─ info/
│  └─ titleid.txt
└─ toolkit.log

## 📝 Logging & Debugging
All operations are logged to:

<game>_workspace/toolkit.log
If ZIP creation fails, the tool:

Dumps the temporary directory tree

Shows a dialog pointing you to the log file

This makes debugging possible even when dialog hides stderr.

## ⚠️ Notes & Limitations
This tool does not patch binaries automatically — it only stages and packages files.

You are responsible for ensuring:

Correct TITLEID

Valid mod files

Compatibility with Atmosphère

## 🧠 Why this tool exists
Most Switch modding workflows are:

manual

error-prone

or rely on GUI tools with little transparency

This script is designed to be:

transparent
scriptable
reproducible
and hacker-friendly 🐧

## 📜 License
MIT License — do whatever you want, just don’t blame me if Nintendo knocks 😄

Happy modding 🌌
