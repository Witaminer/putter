# Putter

Putter is a lightweight multi-session editor for PuTTY on Windows.

It reads PuTTY sessions directly from:

`HKEY_CURRENT_USER\Software\SimonTatham\PuTTY\Sessions`

## Current version

**0.10**

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

Putter edits the current user's PuTTY session registry keys directly. Automatic full `.reg` backups are enabled by default before modifying operations; the backup location and automatic-backup behavior can be changed in **Options -> Settings...**.

## License

GNU General Public License v3.0.

### Keyboard behavior

While editing a cell, `Home` and `End` move the caret to the beginning or end of the field instead of being handled as DataGridView navigation commands.


## Version 0.8

- **File -> Export all sessions...** uses Windows reg.exe export.
- **File -> Export selected sessions...** exports only the selected PuTTY session keys into a Regedit-compatible .reg file.
- **File -> Import .reg...** validates that every registry section is inside the PuTTY Sessions tree before importing.
- **Options -> Settings...** controls automatic backups and the backup folder.
- **Help -> About Putter...** shows the version, build date in YYYY.MM.DD format, GPL license, backup status, backup folder, and a clickable GitHub link.
- **Export selected sessions...** is also available from the grid context menu.

The per-user configuration is stored in Putter.config.json next to the script and is intentionally ignored by Git.


## Version 0.9

- Press **Delete** in the session grid to delete the selected session or sessions. The normal Delete key behavior is preserved while editing text inside a cell.
- **Copy session...** in the right-click context menu duplicates one selected PuTTY session and asks for the new session name.
- Putter can remember the main window position and size between runs. This is controlled by **Options -> Settings...** and is stored in the local `Putter.config.json` file.


## Version 0.10

- Window geometry is restored only after the anchored controls have been created, so the session grid starts at the correct size immediately.
- Maximized window state is now remembered and restored in addition to the normal window position and size.
