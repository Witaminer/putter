# Putter

Putter is a lightweight multi-session editor for PuTTY on Windows.

It reads PuTTY sessions directly from:

`HKEY_CURRENT_USER\Software\SimonTatham\PuTTY\Sessions`

## Current version

**0.6**

## Features

- Browse saved PuTTY sessions in a sortable table
- Filter sessions by name, host, user, or key file
- Multi-select rows with Ctrl/Shift
- Double-click a cell to edit it
- Press Enter to save an inline edit
- Standard text editing shortcuts while editing cells:
  - Ctrl+C / Ctrl+Insert — Copy
  - Ctrl+V / Shift+Insert — Paste
  - Ctrl+X / Shift+Delete — Cut
  - Ctrl+A — Select all
- Rename sessions
- Delete one or multiple sessions from the context menu
- Multi-edit selected sessions
- Find/Replace for bulk session-name changes
- Automatic `.reg` backup before registry modifications

## Running

Run:

```bat
Putter.bat
```

or directly:

```powershell
powershell.exe -NoProfile -ExecutionPolicy Bypass -File .\Putter.ps1
```

No compilation or installer is required.

## Safety

Putter edits the current user's PuTTY session registry keys directly. Before every modifying operation it exports the complete PuTTY Sessions branch to the local `Backups` directory.

## License

GNU General Public License v3.0.
