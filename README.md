# Putter

Putter is a lightweight multi-session editor for PuTTY on Windows.

It reads PuTTY sessions directly from:

`HKEY_CURRENT_USER\Software\SimonTatham\PuTTY\Sessions`

## Current version

**0.19**

## Features

- Browse saved PuTTY sessions in a sortable table
- Filter sessions by name, host, user, or key file
- Multi-select rows with Ctrl/Shift
- Double-click a cell to edit it
- Press Enter to save an inline edit
- Standard text editing shortcuts while editing cells:
  - Ctrl+C / Ctrl+Insert - Copy
  - Ctrl+V / Shift+Insert - Paste
  - Ctrl+X / Shift+Delete - Cut
  - Ctrl+A - Select all
- Rename sessions
- Delete one or multiple sessions from the context menu
- Multi-edit selected sessions
- Find/Replace for bulk session-name changes
- Automatic `.reg` backup before registry modifications

## Running

For the simplest ready-to-run option, download `Putter.exe` from the [latest release](https://github.com/Witaminer/putter/releases/latest) and run it directly.

To run Putter from source with automatic PowerShell selection, use:

```bat
Putter.bat
```

`Putter.bat` prefers PowerShell 7.x when `pwsh.exe` is available and falls back to Windows PowerShell 5.x.

To choose the PowerShell generation explicitly, use:

```bat
Putter5.bat
Putter7.bat
```

Or run the script directly:

```powershell
powershell.exe -NoProfile -ExecutionPolicy Bypass -File .\Putter.ps1
pwsh.exe -NoProfile -ExecutionPolicy Bypass -File .\Putter.ps1
```

Putter 0.19 has been tested with Windows PowerShell 5.1 and PowerShell 7.6.6 on Windows.

No installer is required. The EXE is ready to run, while the script version requires a compatible PowerShell installation.

## Distribution

Putter is intentionally available in both source and ready-to-run forms.

**Ready-to-run Windows executable:** [Download the latest release](https://github.com/Witaminer/putter/releases/latest)

- `Putter.ps1` is the complete source. It remains available so the program is transparent, inspectable, editable, and easy to audit.
- `Putter.bat` is the automatic launcher. It prefers PowerShell 7.x when `pwsh.exe` is available and falls back to Windows PowerShell 5.x.
- `Putter5.bat` explicitly runs the source with Windows PowerShell 5.x.
- `Putter7.bat` explicitly runs the source with PowerShell 7.x.
- `Putter.exe` is the ready-to-run build generated from the same `Putter.ps1` source with PS2EXE.

The EXE is provided for convenience, not to hide or replace the source. PS2EXE embeds the PowerShell script in a .NET executable and hosts the PowerShell engine through the .NET PowerShell API. The current PS2EXE build model targets PowerShell 5.1-compatible scripts and produces .NET Framework 4.x executables. It does not use the BAT launcher logic and does not automatically select PowerShell 7 when it is installed.

## Compatibility

Putter requires Windows PowerShell 5.1 or a compatible PowerShell 7.x installation.

- **Windows 10 and Windows 11:** Windows PowerShell 5.1 is included with the operating system, so Putter can run without installing a newer PowerShell.
- **Windows 7 SP1:** Putter can use Windows PowerShell 5.1 after installing Windows Management Framework (WMF) 5.1 and its required .NET Framework prerequisites.
- **Windows Server 2016 and newer:** Windows PowerShell 5.1 is included with the operating system.
- **Windows Server 2008 R2 SP1, 2012, and 2012 R2:** Windows PowerShell 5.1 can be provided by installing WMF 5.1 and its prerequisites.

Windows 7 and the older Windows Server versions above are compatibility targets based on their ability to run Windows PowerShell 5.1; they have not yet been tested with Putter. The currently tested environments are Windows PowerShell 5.1 and PowerShell 7.6.6 on Windows.

## Safety

Putter edits the current user's PuTTY session registry keys directly. Automatic full `.reg` backups are enabled by default before modifying operations; the backup location and automatic-backup behavior can be changed in **Options -> Settings...**.

## Security and privacy

Putter is designed as a local Windows utility. It does not upload, synchronize, or transmit PuTTY session data, configuration, registry contents, backup files, credentials, or usage information to any Putter-operated server or cloud service.

Putter has no telemetry, analytics, account system, background service, or remote database. Its own configuration and automatic backups are stored locally on the computer.

Network activity can still occur as a direct result of user actions. For example, Putter can launch PuTTY sessions configured by the user, and clicking the repository link in **Help -> About Putter...** opens GitHub in the default browser. Those actions are explicit and are not background data collection by Putter.

The complete PowerShell source is available in this repository so the program's behavior can be inspected directly.

## Code signing policy

For releases signed through the SignPath Foundation program:

**Free code signing provided by SignPath.io, certificate by SignPath Foundation.**

Project roles:

- Committer and reviewer: [Witaminer](https://github.com/Witaminer)
- Approver: [Witaminer](https://github.com/Witaminer)

Only Putter artifacts built from this repository's source code are eligible for signing. Signing requests are approved manually by the project maintainer.

Privacy policy for code signing purposes:

> This program will not transfer any information to other networked systems unless specifically requested by the user or the person installing or operating it.

Putter does not collect telemetry, analytics, usage statistics, credentials, PuTTY session data, registry contents, or other user data. Network access occurs only as a direct result of user-requested actions, such as launching a configured PuTTY session or opening the project link in a web browser.

## Disclaimer

Putter modifies PuTTY session data in the Windows Registry. Features such as rename, multi-edit, import, and delete can therefore make real changes to saved sessions.

Automatic backups are intended to reduce the risk of accidental changes, but they are not a substitute for reviewing what you are about to modify and maintaining your own backups where appropriate.

Putter is provided without warranty, as described by the GNU General Public License v3.0. The authors and contributors are not responsible for data loss, misconfiguration, interrupted access, or other damage resulting from use or misuse of the software. You are responsible for the changes you choose to apply.

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


## Version 0.11

- Added optional **Night mode** with a light-on-dark palette for the main window and Putter dialogs.
- Added a configurable **PuTTY launcher** in **Options -> Settings...**. The browse dialog prefers `.exe`, `.lnk`, `.bat`, and `.cmd`, while still allowing **All files (*.*)**.
- Added a configurable delay between launching multiple sessions.
- Right-click the session grid and choose **Open session** or **Open selected sessions (N)**.
- Press **Enter** outside inline editing to launch the selected session or sessions. Enter still commits an active cell edit.


## Version 0.12

- Fixed Night mode menu rendering with a dedicated dark ToolStrip renderer.
- Added configurable grid font size and a Normal/Bold choice in **Options -> Settings...**.
- Disabled manual row-height resizing in the session grid.
- Added a compact **>** button column to launch an individual session directly.


## Version 0.13

- Night mode now uses a custom ToolStrip renderer so menu backgrounds, hover states, text, separators, and dropdowns are drawn with the dark palette instead of Windows light-menu colors.
- User-resized grid column widths are now remembered between runs. Because the grid uses Fill mode, Putter stores each data column's FillWeight so the chosen proportions survive window resizing.


## Version 0.14

- Fixed restoring user-resized grid column proportions. Putter now temporarily disables Fill layout while applying all saved FillWeight values, then restores Fill mode so DataGridView cannot rebalance each value during the restore loop.
- Putter now remembers the last grid sort expression, including the selected column and ascending/descending direction.


## Version 0.15

- Fixed another DataGridView Fill-mode timing issue when restoring column proportions. Saved FillWeight values are now applied only after the form is shown and the grid has completed its initial layout, preventing the first WinForms Fill calculation from overwriting the restored proportions.


## Version 0.16

- Replaced the compact > session launcher with a standard WinForms **Open** button.
- Added a custom Putter application icon based on the mirrored-t monogram.
- The ICO is embedded directly in Putter.ps1 as Base64, so no additional icon file is required.
- The embedded icon contains 16x16, 32x32, and 48x48 sizes and keeps the PowerShell source ASCII-safe.


## Version 0.17

- Enabled native Windows visual styles for WinForms controls.
- The per-row **Open** launcher now uses the native Windows button renderer.
- Added a bottom action bar with **Refresh**, **Open**, **Rename**, **Copy**, and **Delete** buttons.
- **Open** and **Delete** are enabled for one or more selected sessions.
- **Rename** and **Copy** are enabled only when exactly one session is selected.
- **Refresh** is always available and reloads the PuTTY session list.


## Version 0.18

- Added one-script compatibility logic for both Windows PowerShell 5.1 and PowerShell 7+.
- Windows PowerShell 5.1 keeps the original .NET Framework references.
- PowerShell 7+ resolves the loaded WinForms, Drawing, and ComponentModel assembly paths dynamically before compiling Putter's small C# helper classes.
- No separate PS5/PS7 script is required.


## Version 0.19

- Added PS2EXE-aware base-directory detection. Putter now resolves its local working directory from `$PSScriptRoot`, then `$ScriptRoot`, and finally `[AppDomain]::CurrentDomain.BaseDirectory`.
- `Putter.config.json` and the default `Backups` directory are now resolved relative to that detected Putter directory.
- **Help -> About Putter...** now shows the PowerShell version and edition used to run Putter.
