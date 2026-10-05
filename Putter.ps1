Add-Type -AssemblyName System.Windows.Forms
Add-Type -AssemblyName System.Drawing

# ============================================================
# Putter 0.8
# A lightweight multi-session editor for PuTTY on Windows.
# Find it on https://github.com/Witaminer/putter
# ============================================================

Add-Type -TypeDefinition @'
using System;
using System.Windows.Forms;

public class PutterDataGridView : DataGridView
{
    protected override bool ProcessCmdKey(ref Message msg, Keys keyData)
    {
        TextBoxBase textBox = this.EditingControl as TextBoxBase;

        if (this.IsCurrentCellInEditMode && textBox != null)
        {
            Keys keyCode = keyData & Keys.KeyCode;
            Keys modifiers = keyData & Keys.Modifiers;

            // Copy: Ctrl+C / Ctrl+Insert
            if ((modifiers == Keys.Control && keyCode == Keys.C) ||
                (modifiers == Keys.Control && keyCode == Keys.Insert))
            {
                textBox.Copy();
                return true;
            }

            // Paste: Ctrl+V / Shift+Insert
            if ((modifiers == Keys.Control && keyCode == Keys.V) ||
                (modifiers == Keys.Shift && keyCode == Keys.Insert))
            {
                textBox.Paste();
                return true;
            }

            // Cut: Ctrl+X / Shift+Delete
            if ((modifiers == Keys.Control && keyCode == Keys.X) ||
                (modifiers == Keys.Shift && keyCode == Keys.Delete))
            {
                textBox.Cut();
                return true;
            }

            // Select all: Ctrl+A
            if (modifiers == Keys.Control && keyCode == Keys.A)
            {
                textBox.SelectAll();
                return true;
            }

            // Keep Home/End inside the editing control.
            // DataGridView otherwise treats them as navigation keys and may end the edit.
            if (modifiers == Keys.None && keyCode == Keys.Home)
            {
                textBox.SelectionStart = 0;
                textBox.SelectionLength = 0;
                return true;
            }

            if (modifiers == Keys.None && keyCode == Keys.End)
            {
                textBox.SelectionStart = textBox.TextLength;
                textBox.SelectionLength = 0;
                return true;
            }

            // Enter commits the current cell edit.
            if (modifiers == Keys.None && keyCode == Keys.Enter)
            {
                this.EndEdit();
                return true;
            }
        }

        return base.ProcessCmdKey(ref msg, keyData);
    }
}
'@ -ReferencedAssemblies 'System.Windows.Forms', 'System.Drawing' -WarningAction SilentlyContinue

$PutterVersion   = '0.8'
$PutterBuildDate = '2026.10.05'
$RepositoryUrl   = 'https://github.com/Witaminer/putter'

$SessionsPathPS   = 'HKCU:\Software\SimonTatham\PuTTY\Sessions'
$SessionsPathReg  = 'HKCU\Software\SimonTatham\PuTTY\Sessions'
$ConfigPath       = Join-Path $PSScriptRoot 'Putter.config.json'
$DefaultBackupDir = Join-Path $PSScriptRoot 'Backups'

$Config = [PSCustomObject]@{
    CreateBackups   = $true
    BackupDirectory = $DefaultBackupDir
}

if (Test-Path -LiteralPath $ConfigPath) {
    try {
        $loadedConfig = Get-Content -LiteralPath $ConfigPath -Raw | ConvertFrom-Json

        if ($null -ne $loadedConfig.CreateBackups) {
            $Config.CreateBackups = [bool]$loadedConfig.CreateBackups
        }

        if (-not [string]::IsNullOrWhiteSpace([string]$loadedConfig.BackupDirectory)) {
            $Config.BackupDirectory = [string]$loadedConfig.BackupDirectory
        }
    }
    catch {
        # Invalid local configuration is ignored and defaults are used.
    }
}

function Save-PutterConfig {
    $Config | ConvertTo-Json | Set-Content -LiteralPath $ConfigPath -Encoding UTF8
}

function ConvertFrom-PuttySessionName {
    param([string]$Name)

    try {
        return [System.Uri]::UnescapeDataString($Name)
    }
    catch {
        return $Name
    }
}

function ConvertTo-PuttySessionName {
    param([string]$Name)

    return [System.Uri]::EscapeDataString($Name)
}

function Backup-PuttySessions {
    if (-not $Config.CreateBackups) {
        return $null
    }

    $backupDir = [string]$Config.BackupDirectory

    if ([string]::IsNullOrWhiteSpace($backupDir)) {
        $backupDir = $DefaultBackupDir
    }

    if (-not (Test-Path -LiteralPath $backupDir)) {
        New-Item -ItemType Directory -Path $backupDir -Force | Out-Null
    }

    $timestamp = Get-Date -Format 'yyyyMMdd-HHmmss-fff'
    $backupFile = Join-Path $backupDir "PuTTY-Sessions-$timestamp.reg"

    & reg.exe export $SessionsPathReg $backupFile /y | Out-Null

    if ($LASTEXITCODE -ne 0) {
        throw 'Failed to back up the PuTTY sessions registry key.'
    }

    return $backupFile
}

function Get-BackupStatusSuffix {
    param([string]$BackupFile)

    if ([string]::IsNullOrWhiteSpace($BackupFile)) {
        return '    Automatic backup: disabled'
    }

    return "    Backup: $([IO.Path]::GetFileName($BackupFile))"
}

function Show-PutterError {
    param(
        [string]$Message,
        [string]$Title = 'Putter'
    )

    [System.Windows.Forms.MessageBox]::Show(
        $Message,
        $Title,
        [System.Windows.Forms.MessageBoxButtons]::OK,
        [System.Windows.Forms.MessageBoxIcon]::Error
    ) | Out-Null
}

# ============================================================
# Main window
# ============================================================

$form = New-Object System.Windows.Forms.Form
$form.Text = "Putter $PutterVersion"
$form.Width = 1250
$form.Height = 750
$form.StartPosition = 'CenterScreen'

$filterLabel = New-Object System.Windows.Forms.Label
$filterLabel.Text = 'Filter:'
$filterLabel.AutoSize = $true
$filterLabel.Left = 10
$filterLabel.Top = 39

$filterBox = New-Object System.Windows.Forms.TextBox
$filterBox.Left = 60
$filterBox.Top = 34
$filterBox.Width = 500
$filterBox.ShortcutsEnabled = $true

$grid = New-Object PutterDataGridView
$grid.Left = 10
$grid.Top = 69
$grid.Width = 1210
$grid.Height = 596
$grid.Anchor = 'Top,Bottom,Left,Right'
$grid.AllowUserToAddRows = $false
$grid.AllowUserToDeleteRows = $false
$grid.AllowUserToOrderColumns = $true
$grid.SelectionMode = 'FullRowSelect'
$grid.MultiSelect = $true
$grid.AutoSizeColumnsMode = 'Fill'
$grid.EditMode = 'EditProgrammatically'

$statusLabel = New-Object System.Windows.Forms.Label
$statusLabel.Left = 10
$statusLabel.Top = 680
$statusLabel.Width = 1150
$statusLabel.Height = 25
$statusLabel.Anchor = 'Bottom,Left,Right'

# ============================================================
# Data model
# ============================================================

$table = New-Object System.Data.DataTable
[void]$table.Columns.Add('Session')
[void]$table.Columns.Add('HostName')

$portColumn = New-Object System.Data.DataColumn
$portColumn.ColumnName = 'PortNumber'
$portColumn.DataType = [int]
[void]$table.Columns.Add($portColumn)

[void]$table.Columns.Add('UserName')
[void]$table.Columns.Add('PublicKeyFile')
[void]$table.Columns.Add('RegistryName')

$view = New-Object System.Data.DataView($table)
$grid.DataSource = $view

function Update-Status {
    $statusLabel.Text = "Sessions: $($table.Rows.Count)    Selected: $($grid.SelectedRows.Count)"
}

function Load-PuttySessions {
    $table.Clear()

    if (-not (Test-Path -LiteralPath $SessionsPathPS)) {
        $statusLabel.Text = 'PuTTY Sessions registry key not found.'
        return
    }

    foreach ($sessionKey in Get-ChildItem -LiteralPath $SessionsPathPS) {
        $p = Get-ItemProperty -LiteralPath $sessionKey.PSPath
        $row = $table.NewRow()

        $row.Session = ConvertFrom-PuttySessionName $sessionKey.PSChildName
        $row.RegistryName = $sessionKey.PSChildName
        $row.HostName = [string]$p.HostName

        if ($null -ne $p.PortNumber) {
            $row.PortNumber = [int]$p.PortNumber
        }
        else {
            $row.PortNumber = 22
        }

        $row.UserName = [string]$p.UserName
        $row.PublicKeyFile = [string]$p.PublicKeyFile

        $table.Rows.Add($row)
    }

    Update-Status
}

$grid.Add_DataBindingComplete({
    if ($grid.Columns.Contains('RegistryName')) {
        $grid.Columns['RegistryName'].Visible = $false
    }
})

Load-PuttySessions

# ============================================================
# Filtering and selection
# ============================================================

$filterBox.Add_TextChanged({
    $text = $filterBox.Text.Replace("'", "''")

    if ([string]::IsNullOrWhiteSpace($text)) {
        $view.RowFilter = ''
    }
    else {
        $view.RowFilter =
            "Session LIKE '%$text%' OR " +
            "HostName LIKE '%$text%' OR " +
            "UserName LIKE '%$text%' OR " +
            "PublicKeyFile LIKE '%$text%'"
    }
})

$grid.Add_SelectionChanged({
    Update-Status
})

# ============================================================
# Inline editing
# ============================================================

$script:OriginalValue = $null

$grid.Add_CellDoubleClick({
    param($sender, $e)

    if ($e.RowIndex -lt 0 -or $e.ColumnIndex -lt 0) {
        return
    }

    $columnName = $grid.Columns[$e.ColumnIndex].Name

    if ($columnName -eq 'RegistryName') {
        return
    }

    $grid.CurrentCell = $grid.Rows[$e.RowIndex].Cells[$e.ColumnIndex]
    $grid.BeginEdit($true)
})

$grid.Add_CellBeginEdit({
    param($sender, $e)

    $script:OriginalValue = $grid.Rows[$e.RowIndex].Cells[$e.ColumnIndex].Value
})

$grid.Add_CellEndEdit({
    param($sender, $e)

    $row = $grid.Rows[$e.RowIndex]
    $columnName = $grid.Columns[$e.ColumnIndex].Name
    $newValue = $row.Cells[$e.ColumnIndex].Value
    $oldValue = $script:OriginalValue

    if ([string]$newValue -eq [string]$oldValue) {
        return
    }

    $registryName = [string]$row.Cells['RegistryName'].Value
    $registryPath = Join-Path $SessionsPathPS $registryName

    try {
        $backupFile = Backup-PuttySessions

        if ($columnName -eq 'Session') {
            $humanName = [string]$newValue

            if ([string]::IsNullOrWhiteSpace($humanName)) {
                throw 'Session name cannot be empty.'
            }

            $newRegistryName = ConvertTo-PuttySessionName $humanName
            $newRegistryPath = Join-Path $SessionsPathPS $newRegistryName

            if (($newRegistryName -ne $registryName) -and (Test-Path -LiteralPath $newRegistryPath)) {
                throw "Session '$humanName' already exists."
            }

            Rename-Item -LiteralPath $registryPath -NewName $newRegistryName -ErrorAction Stop
            $row.Cells['RegistryName'].Value = $newRegistryName
        }
        elseif ($columnName -eq 'PortNumber') {
            $port = 0

            if (-not [int]::TryParse([string]$newValue, [ref]$port)) {
                throw 'PortNumber must be a number.'
            }

            if ($port -lt 1 -or $port -gt 65535) {
                throw 'PortNumber must be in the range 1-65535.'
            }

            Set-ItemProperty -LiteralPath $registryPath -Name 'PortNumber' -Value $port -ErrorAction Stop
        }
        elseif ($columnName -in @('HostName', 'UserName', 'PublicKeyFile')) {
            Set-ItemProperty -LiteralPath $registryPath -Name $columnName -Value ([string]$newValue) -ErrorAction Stop
        }
        else {
            throw "Unsupported column: $columnName"
        }

        $statusLabel.Text = "Saved: $columnName$(Get-BackupStatusSuffix $backupFile)"
    }
    catch {
        $row.Cells[$e.ColumnIndex].Value = $oldValue
        Show-PutterError $_.Exception.Message 'Putter - Save failed'
    }
})

# ============================================================
# Delete sessions
# ============================================================

function Remove-PutterSessions {
    param(
        [System.Windows.Forms.DataGridViewRow[]]$Rows
    )

    if ($null -eq $Rows -or $Rows.Count -eq 0) {
        return
    }

    $names = @()

    foreach ($row in $Rows) {
        $names += [string]$row.Cells['Session'].Value
    }

    if ($Rows.Count -eq 1) {
        $message = "Are you sure you want to delete this session?" +
            [Environment]::NewLine + [Environment]::NewLine +
            $names[0]
    }
    else {
        $preview = ($names | Select-Object -First 10) -join [Environment]::NewLine

        if ($Rows.Count -gt 10) {
            $preview += [Environment]::NewLine + "... +$($Rows.Count - 10) more"
        }

        $message = "Are you sure you want to delete $($Rows.Count) selected sessions?" +
            [Environment]::NewLine + [Environment]::NewLine +
            $preview
    }

    $answer = [System.Windows.Forms.MessageBox]::Show(
        $message,
        'Putter - Confirm deletion',
        [System.Windows.Forms.MessageBoxButtons]::YesNo,
        [System.Windows.Forms.MessageBoxIcon]::Warning,
        [System.Windows.Forms.MessageBoxDefaultButton]::Button2
    )

    if ($answer -ne [System.Windows.Forms.DialogResult]::Yes) {
        return
    }

    try {
        $backupFile = Backup-PuttySessions

        foreach ($row in $Rows) {
            $registryName = [string]$row.Cells['RegistryName'].Value
            $registryPath = Join-Path $SessionsPathPS $registryName

            Remove-Item -LiteralPath $registryPath -Recurse -Force -ErrorAction Stop
        }

        Load-PuttySessions
        $statusLabel.Text = "Deleted: $($Rows.Count)$(Get-BackupStatusSuffix $backupFile)"
    }
    catch {
        Show-PutterError $_.Exception.Message 'Putter - Delete failed'
    }
}

# ============================================================
# Multi-edit dialog
# ============================================================

function Show-MultiEditDialog {
    $selectedRows = @($grid.SelectedRows | Sort-Object Index)

    if ($selectedRows.Count -eq 0) {
        return
    }

    $dlg = New-Object System.Windows.Forms.Form
    $dlg.Text = "Putter - Multi-edit ($($selectedRows.Count) sessions)"
    $dlg.Width = 680
    $dlg.Height = 440
    $dlg.StartPosition = 'CenterParent'
    $dlg.FormBorderStyle = 'FixedDialog'
    $dlg.MaximizeBox = $false
    $dlg.MinimizeBox = $false

    $info = New-Object System.Windows.Forms.Label
    $info.Left = 15
    $info.Top = 15
    $info.Width = 630
    $info.Height = 35
    $info.Text = "$($selectedRows.Count) sessions selected. Check the fields you want to change."
    $dlg.Controls.Add($info)

    function Add-EditLine {
        param(
            [string]$Caption,
            [int]$Top
        )

        $check = New-Object System.Windows.Forms.CheckBox
        $check.Text = $Caption
        $check.Left = 15
        $check.Top = $Top
        $check.Width = 130

        $text = New-Object System.Windows.Forms.TextBox
        $text.Left = 155
        $text.Top = ($Top - 2)
        $text.Width = 475
        $text.Enabled = $false
        $text.ShortcutsEnabled = $true

        $check.Tag = $text

        $check.Add_CheckedChanged({
            $textBox = $this.Tag
            $textBox.Enabled = $this.Checked

            if ($this.Checked) {
                $textBox.Focus()
            }
        })

        $dlg.Controls.Add($check)
        $dlg.Controls.Add($text)

        return [PSCustomObject]@{
            Check = $check
            Text  = $text
        }
    }

    $hostEdit = Add-EditLine 'HostName' 65
    $portEdit = Add-EditLine 'PortNumber' 100
    $userEdit = Add-EditLine 'UserName' 135
    $keyEdit = Add-EditLine 'PublicKeyFile' 170

    $sessionCheck = New-Object System.Windows.Forms.CheckBox
    $sessionCheck.Text = 'Session name'
    $sessionCheck.Left = 15
    $sessionCheck.Top = 215
    $sessionCheck.Width = 130

    $findLabel = New-Object System.Windows.Forms.Label
    $findLabel.Text = 'Find:'
    $findLabel.Left = 155
    $findLabel.Top = 216
    $findLabel.AutoSize = $true

    $findBox = New-Object System.Windows.Forms.TextBox
    $findBox.Left = 200
    $findBox.Top = 212
    $findBox.Width = 180
    $findBox.Enabled = $false
    $findBox.ShortcutsEnabled = $true

    $replaceLabel = New-Object System.Windows.Forms.Label
    $replaceLabel.Text = 'Replace:'
    $replaceLabel.Left = 390
    $replaceLabel.Top = 216
    $replaceLabel.AutoSize = $true

    $replaceBox = New-Object System.Windows.Forms.TextBox
    $replaceBox.Left = 455
    $replaceBox.Top = 212
    $replaceBox.Width = 175
    $replaceBox.Enabled = $false
    $replaceBox.ShortcutsEnabled = $true

    $sessionCheck.Tag = [PSCustomObject]@{
        Find    = $findBox
        Replace = $replaceBox
    }

    $sessionCheck.Add_CheckedChanged({
        $controls = $this.Tag
        $controls.Find.Enabled = $this.Checked
        $controls.Replace.Enabled = $this.Checked

        if ($this.Checked) {
            $controls.Find.Focus()
        }
    })

    $dlg.Controls.Add($sessionCheck)
    $dlg.Controls.Add($findLabel)
    $dlg.Controls.Add($findBox)
    $dlg.Controls.Add($replaceLabel)
    $dlg.Controls.Add($replaceBox)

    $hint = New-Object System.Windows.Forms.Label
    $hint.Left = 155
    $hint.Top = 245
    $hint.Width = 475
    $hint.Height = 35
    $hint.Text = 'Session name uses Find/Replace so each session keeps a unique name.'
    $dlg.Controls.Add($hint)

    $applyButton = New-Object System.Windows.Forms.Button
    $applyButton.Text = 'Apply'
    $applyButton.Left = 450
    $applyButton.Top = 325
    $applyButton.Width = 85

    $cancelButton = New-Object System.Windows.Forms.Button
    $cancelButton.Text = 'Cancel'
    $cancelButton.Left = 545
    $cancelButton.Top = 325
    $cancelButton.Width = 85

    $cancelButton.Add_Click({
        $dlg.Close()
    })

    $applyButton.Add_Click({
        $anything =
            $hostEdit.Check.Checked -or
            $portEdit.Check.Checked -or
            $userEdit.Check.Checked -or
            $keyEdit.Check.Checked -or
            $sessionCheck.Checked

        if (-not $anything) {
            [System.Windows.Forms.MessageBox]::Show(
                'No fields were selected for editing.',
                'Putter',
                [System.Windows.Forms.MessageBoxButtons]::OK,
                [System.Windows.Forms.MessageBoxIcon]::Information
            ) | Out-Null
            return
        }

        $port = $null

        if ($portEdit.Check.Checked) {
            $parsedPort = 0

            if (-not [int]::TryParse($portEdit.Text.Text, [ref]$parsedPort)) {
                Show-PutterError 'PortNumber must be a number.'
                return
            }

            if ($parsedPort -lt 1 -or $parsedPort -gt 65535) {
                Show-PutterError 'PortNumber must be in the range 1-65535.'
                return
            }

            $port = $parsedPort
        }

        if ($sessionCheck.Checked -and [string]::IsNullOrEmpty($findBox.Text)) {
            Show-PutterError 'Find cannot be empty when editing session names.'
            return
        }

        $renamePlan = @()

        if ($sessionCheck.Checked) {
            foreach ($row in $selectedRows) {
                $oldHuman = [string]$row.Cells['Session'].Value
                $newHuman = $oldHuman.Replace($findBox.Text, $replaceBox.Text)
                $oldRegistry = [string]$row.Cells['RegistryName'].Value
                $newRegistry = ConvertTo-PuttySessionName $newHuman

                $renamePlan += [PSCustomObject]@{
                    OldHuman    = $oldHuman
                    NewHuman    = $newHuman
                    OldRegistry = $oldRegistry
                    NewRegistry = $newRegistry
                }
            }

            $duplicates = $renamePlan | Group-Object NewRegistry | Where-Object { $_.Count -gt 1 }

            if ($duplicates) {
                Show-PutterError 'Find/Replace would create duplicate session names.'
                return
            }

            $sourceNames = @{}

            foreach ($item in $renamePlan) {
                $sourceNames[$item.OldRegistry] = $true
            }

            foreach ($item in $renamePlan) {
                if ($item.OldRegistry -eq $item.NewRegistry) {
                    continue
                }

                $targetPath = Join-Path $SessionsPathPS $item.NewRegistry

                if ((Test-Path -LiteralPath $targetPath) -and (-not $sourceNames.ContainsKey($item.NewRegistry))) {
                    Show-PutterError ("Target session already exists:" + [Environment]::NewLine + [Environment]::NewLine + $item.NewHuman)
                    return
                }
            }
        }

        $changes = @()

        if ($hostEdit.Check.Checked) {
            $changes += "HostName = $($hostEdit.Text.Text)"
        }

        if ($portEdit.Check.Checked) {
            $changes += "PortNumber = $port"
        }

        if ($userEdit.Check.Checked) {
            $changes += "UserName = $($userEdit.Text.Text)"
        }

        if ($keyEdit.Check.Checked) {
            $changes += "PublicKeyFile = $($keyEdit.Text.Text)"
        }

        if ($sessionCheck.Checked) {
            $changes += "Session: '$($findBox.Text)' -> '$($replaceBox.Text)'"
        }

        $message = "Apply changes to $($selectedRows.Count) selected sessions?" +
            [Environment]::NewLine + [Environment]::NewLine +
            ($changes -join [Environment]::NewLine)

        $answer = [System.Windows.Forms.MessageBox]::Show(
            $message,
            'Putter - Multi-edit',
            [System.Windows.Forms.MessageBoxButtons]::YesNo,
            [System.Windows.Forms.MessageBoxIcon]::Question,
            [System.Windows.Forms.MessageBoxDefaultButton]::Button2
        )

        if ($answer -ne [System.Windows.Forms.DialogResult]::Yes) {
            return
        }

        try {
            $backupFile = Backup-PuttySessions

            foreach ($row in $selectedRows) {
                $registryName = [string]$row.Cells['RegistryName'].Value
                $registryPath = Join-Path $SessionsPathPS $registryName

                if ($hostEdit.Check.Checked) {
                    Set-ItemProperty -LiteralPath $registryPath -Name 'HostName' -Value $hostEdit.Text.Text -ErrorAction Stop
                }

                if ($portEdit.Check.Checked) {
                    Set-ItemProperty -LiteralPath $registryPath -Name 'PortNumber' -Value $port -ErrorAction Stop
                }

                if ($userEdit.Check.Checked) {
                    Set-ItemProperty -LiteralPath $registryPath -Name 'UserName' -Value $userEdit.Text.Text -ErrorAction Stop
                }

                if ($keyEdit.Check.Checked) {
                    Set-ItemProperty -LiteralPath $registryPath -Name 'PublicKeyFile' -Value $keyEdit.Text.Text -ErrorAction Stop
                }
            }

            # Use temporary names so chained renames do not collide.
            if ($sessionCheck.Checked) {
                $tempPlan = @()

                foreach ($item in $renamePlan) {
                    if ($item.OldRegistry -eq $item.NewRegistry) {
                        continue
                    }

                    do {
                        $tempRegistry = '__PUTTER_TEMP_' + [guid]::NewGuid().ToString('N')
                        $tempPath = Join-Path $SessionsPathPS $tempRegistry
                    }
                    while (Test-Path -LiteralPath $tempPath)

                    $oldPath = Join-Path $SessionsPathPS $item.OldRegistry
                    Rename-Item -LiteralPath $oldPath -NewName $tempRegistry -ErrorAction Stop

                    $tempPlan += [PSCustomObject]@{
                        TempRegistry = $tempRegistry
                        NewRegistry  = $item.NewRegistry
                    }
                }

                foreach ($item in $tempPlan) {
                    $tempPath = Join-Path $SessionsPathPS $item.TempRegistry
                    Rename-Item -LiteralPath $tempPath -NewName $item.NewRegistry -ErrorAction Stop
                }
            }

            $dlg.Close()
            Load-PuttySessions

            $statusLabel.Text = "Multi-edit: $($selectedRows.Count)$(Get-BackupStatusSuffix $backupFile)"
        }
        catch {
            Show-PutterError $_.Exception.Message 'Putter - Multi-edit failed'
        }
    })

    $dlg.Controls.Add($applyButton)
    $dlg.Controls.Add($cancelButton)
    $dlg.AcceptButton = $applyButton
    $dlg.CancelButton = $cancelButton

    [void]$dlg.ShowDialog($form)
}

# ============================================================
# Export / import / options / about
# ============================================================

function Export-AllSessions {
    $dialog = New-Object System.Windows.Forms.SaveFileDialog
    $dialog.Title = 'Export all PuTTY sessions'
    $dialog.Filter = 'Registry files (*.reg)|*.reg|All files (*.*)|*.*'
    $dialog.DefaultExt = 'reg'
    $dialog.AddExtension = $true
    $dialog.FileName = "PuTTY-Sessions-$(Get-Date -Format 'yyyyMMdd-HHmmss').reg"

    if ($dialog.ShowDialog($form) -ne [System.Windows.Forms.DialogResult]::OK) {
        return
    }

    & reg.exe export $SessionsPathReg $dialog.FileName /y | Out-Null

    if ($LASTEXITCODE -ne 0) {
        Show-PutterError 'Failed to export PuTTY sessions.' 'Putter - Export failed'
        return
    }

    $statusLabel.Text = "Exported all sessions to: $($dialog.FileName)"
}

function Export-SelectedSessions {
    $selectedRows = @($grid.SelectedRows | Sort-Object Index)

    if ($selectedRows.Count -eq 0) {
        [System.Windows.Forms.MessageBox]::Show(
            'No sessions are selected.',
            'Putter',
            [System.Windows.Forms.MessageBoxButtons]::OK,
            [System.Windows.Forms.MessageBoxIcon]::Information
        ) | Out-Null
        return
    }

    $dialog = New-Object System.Windows.Forms.SaveFileDialog
    $dialog.Title = 'Export selected PuTTY sessions'
    $dialog.Filter = 'Registry files (*.reg)|*.reg|All files (*.*)|*.*'
    $dialog.DefaultExt = 'reg'
    $dialog.AddExtension = $true
    $dialog.FileName = "PuTTY-Selected-Sessions-$(Get-Date -Format 'yyyyMMdd-HHmmss').reg"

    if ($dialog.ShowDialog($form) -ne [System.Windows.Forms.DialogResult]::OK) {
        return
    }

    $tempFiles = @()

    try {
        $outputLines = New-Object System.Collections.Generic.List[string]
        $outputLines.Add('Windows Registry Editor Version 5.00')
        $outputLines.Add('')

        foreach ($row in $selectedRows) {
            $registryName = [string]$row.Cells['RegistryName'].Value
            $registryPathReg = "$SessionsPathReg\$registryName"
            $tempFile = Join-Path ([IO.Path]::GetTempPath()) ("Putter-" + [guid]::NewGuid().ToString('N') + '.reg')
            $tempFiles += $tempFile

            & reg.exe export $registryPathReg $tempFile /y | Out-Null

            if ($LASTEXITCODE -ne 0) {
                throw "Failed to export session '$([string]$row.Cells['Session'].Value)'."
            }

            $lines = Get-Content -LiteralPath $tempFile

            foreach ($line in $lines) {
                if ($line -eq 'Windows Registry Editor Version 5.00') {
                    continue
                }

                if ($outputLines.Count -gt 0 -and
                    [string]::IsNullOrWhiteSpace($line) -and
                    [string]::IsNullOrWhiteSpace($outputLines[$outputLines.Count - 1])) {
                    continue
                }

                $outputLines.Add($line)
            }

            if ($outputLines.Count -eq 0 -or
                -not [string]::IsNullOrWhiteSpace($outputLines[$outputLines.Count - 1])) {
                $outputLines.Add('')
            }
        }

        $outputLines | Set-Content -LiteralPath $dialog.FileName -Encoding Unicode
        $statusLabel.Text = "Exported $($selectedRows.Count) selected sessions to: $($dialog.FileName)"
    }
    catch {
        Show-PutterError $_.Exception.Message 'Putter - Export failed'
    }
    finally {
        foreach ($tempFile in $tempFiles) {
            Remove-Item -LiteralPath $tempFile -Force -ErrorAction SilentlyContinue
        }
    }
}

function Import-RegistryFile {
    $dialog = New-Object System.Windows.Forms.OpenFileDialog
    $dialog.Title = 'Import PuTTY sessions'
    $dialog.Filter = 'Registry files (*.reg)|*.reg|All files (*.*)|*.*'
    $dialog.Multiselect = $false

    if ($dialog.ShowDialog($form) -ne [System.Windows.Forms.DialogResult]::OK) {
        return
    }

    try {
        $lines = Get-Content -LiteralPath $dialog.FileName
        $sectionLines = @($lines | Where-Object { $_ -match '^\[-?HKEY_' })

        if ($sectionLines.Count -eq 0) {
            throw 'The selected file does not contain any registry sections.'
        }

        $allowedPrefix = 'HKEY_CURRENT_USER\Software\SimonTatham\PuTTY\Sessions'

        foreach ($line in $sectionLines) {
            if ($line -notmatch '^\[-?(?<path>HKEY_[^\]]+)\]

$contextMenu = New-Object System.Windows.Forms.ContextMenuStrip

$multiEditItem = New-Object System.Windows.Forms.ToolStripMenuItem
$multiEditItem.Text = 'Multi-edit selected...'

$exportSelectedItem = New-Object System.Windows.Forms.ToolStripMenuItem
$exportSelectedItem.Text = 'Export selected sessions...'

$separator = New-Object System.Windows.Forms.ToolStripSeparator

$deleteCurrentItem = New-Object System.Windows.Forms.ToolStripMenuItem
$deleteCurrentItem.Text = 'Delete this session...'

$deleteSelectedItem = New-Object System.Windows.Forms.ToolStripMenuItem
$deleteSelectedItem.Text = 'Delete selected...'

[void]$contextMenu.Items.Add($multiEditItem)
[void]$contextMenu.Items.Add($exportSelectedItem)
[void]$contextMenu.Items.Add($separator)
[void]$contextMenu.Items.Add($deleteCurrentItem)
[void]$contextMenu.Items.Add($deleteSelectedItem)

$grid.ContextMenuStrip = $contextMenu
$script:ContextRow = $null

$grid.Add_CellMouseDown({
    param($sender, $e)

    if ($e.Button -ne [System.Windows.Forms.MouseButtons]::Right) {
        return
    }

    if ($e.RowIndex -lt 0) {
        return
    }

    $script:ContextRow = $grid.Rows[$e.RowIndex]

    if (-not $script:ContextRow.Selected) {
        $grid.ClearSelection()
        $script:ContextRow.Selected = $true

        if ($e.ColumnIndex -ge 0) {
            $grid.CurrentCell = $script:ContextRow.Cells[$e.ColumnIndex]
        }
    }
})

$contextMenu.Add_Opening({
    $count = $grid.SelectedRows.Count

    $multiEditItem.Text = "Multi-edit selected ($count)..."
    $exportSelectedItem.Text = "Export selected sessions ($count)..."
    $deleteSelectedItem.Text = "Delete selected ($count)..."

    $multiEditItem.Enabled = ($count -gt 0)
    $exportSelectedItem.Enabled = ($count -gt 0)
    $deleteSelectedItem.Enabled = ($count -gt 0)
    $deleteCurrentItem.Enabled = ($null -ne $script:ContextRow)
})

$deleteCurrentItem.Add_Click({
    if ($null -ne $script:ContextRow) {
        Remove-PutterSessions -Rows @($script:ContextRow)
    }
})

$deleteSelectedItem.Add_Click({
    $rows = @($grid.SelectedRows)
    Remove-PutterSessions -Rows $rows
})

$multiEditItem.Add_Click({
    Show-MultiEditDialog
})

$exportSelectedItem.Add_Click({
    Export-SelectedSessions
})

# ============================================================
# Run
# ============================================================

$form.MainMenuStrip = $menuStrip
$form.Controls.Add($menuStrip)
$form.Controls.Add($filterLabel)
$form.Controls.Add($filterBox)
$form.Controls.Add($grid)
$form.Controls.Add($statusLabel)

[void]$form.ShowDialog()
) {
                throw "Unsupported registry section: $line"
            }

            $path = $Matches.path

            if ($path -ne $allowedPrefix -and
                -not $path.StartsWith($allowedPrefix + '\', [System.StringComparison]::OrdinalIgnoreCase)) {
                throw ('The file contains a registry section outside PuTTY Sessions:' +
                    [Environment]::NewLine + [Environment]::NewLine + $path)
            }
        }

        $answer = [System.Windows.Forms.MessageBox]::Show(
            ('Import this .reg file into PuTTY Sessions?' +
                [Environment]::NewLine + [Environment]::NewLine + $dialog.FileName),
            'Putter - Confirm import',
            [System.Windows.Forms.MessageBoxButtons]::YesNo,
            [System.Windows.Forms.MessageBoxIcon]::Question,
            [System.Windows.Forms.MessageBoxDefaultButton]::Button2
        )

        if ($answer -ne [System.Windows.Forms.DialogResult]::Yes) {
            return
        }

        $backupFile = Backup-PuttySessions

        & reg.exe import $dialog.FileName | Out-Null

        if ($LASTEXITCODE -ne 0) {
            throw 'reg.exe failed to import the selected file.'
        }

        Load-PuttySessions
        $statusLabel.Text = "Imported registry file$(Get-BackupStatusSuffix $backupFile)"
    }
    catch {
        Show-PutterError $_.Exception.Message 'Putter - Import failed'
    }
}

function Show-OptionsDialog {
    $dlg = New-Object System.Windows.Forms.Form
    $dlg.Text = 'Putter - Options'
    $dlg.Width = 650
    $dlg.Height = 245
    $dlg.StartPosition = 'CenterParent'
    $dlg.FormBorderStyle = 'FixedDialog'
    $dlg.MaximizeBox = $false
    $dlg.MinimizeBox = $false

    $backupCheck = New-Object System.Windows.Forms.CheckBox
    $backupCheck.Text = 'Create an automatic backup before changes'
    $backupCheck.Left = 15
    $backupCheck.Top = 20
    $backupCheck.Width = 350
    $backupCheck.Checked = [bool]$Config.CreateBackups

    $folderLabel = New-Object System.Windows.Forms.Label
    $folderLabel.Text = 'Backup folder:'
    $folderLabel.Left = 15
    $folderLabel.Top = 60
    $folderLabel.AutoSize = $true

    $folderBox = New-Object System.Windows.Forms.TextBox
    $folderBox.Left = 15
    $folderBox.Top = 80
    $folderBox.Width = 500
    $folderBox.Text = [string]$Config.BackupDirectory
    $folderBox.ShortcutsEnabled = $true

    $browseButton = New-Object System.Windows.Forms.Button
    $browseButton.Text = 'Browse...'
    $browseButton.Left = 525
    $browseButton.Top = 78
    $browseButton.Width = 90

    $openButton = New-Object System.Windows.Forms.Button
    $openButton.Text = 'Open folder'
    $openButton.Left = 15
    $openButton.Top = 115
    $openButton.Width = 100

    $okButton = New-Object System.Windows.Forms.Button
    $okButton.Text = 'OK'
    $okButton.Left = 430
    $okButton.Top = 155
    $okButton.Width = 85

    $cancelButton = New-Object System.Windows.Forms.Button
    $cancelButton.Text = 'Cancel'
    $cancelButton.Left = 525
    $cancelButton.Top = 155
    $cancelButton.Width = 90

    $backupCheck.Add_CheckedChanged({
        $folderBox.Enabled = $this.Checked
        $browseButton.Enabled = $this.Checked
        $openButton.Enabled = $this.Checked
    })

    $folderBox.Enabled = $backupCheck.Checked
    $browseButton.Enabled = $backupCheck.Checked
    $openButton.Enabled = $backupCheck.Checked

    $browseButton.Add_Click({
        $folderDialog = New-Object System.Windows.Forms.FolderBrowserDialog
        $folderDialog.Description = 'Select the folder for automatic PuTTY session backups.'

        if (Test-Path -LiteralPath $folderBox.Text) {
            $folderDialog.SelectedPath = $folderBox.Text
        }

        if ($folderDialog.ShowDialog($dlg) -eq [System.Windows.Forms.DialogResult]::OK) {
            $folderBox.Text = $folderDialog.SelectedPath
        }
    })

    $openButton.Add_Click({
        $path = $folderBox.Text

        if ([string]::IsNullOrWhiteSpace($path)) {
            return
        }

        if (-not (Test-Path -LiteralPath $path)) {
            New-Item -ItemType Directory -Path $path -Force | Out-Null
        }

        Start-Process explorer.exe -ArgumentList $path
    })

    $okButton.Add_Click({
        if ($backupCheck.Checked -and [string]::IsNullOrWhiteSpace($folderBox.Text)) {
            Show-PutterError 'Backup folder cannot be empty while automatic backups are enabled.'
            return
        }

        $Config.CreateBackups = $backupCheck.Checked
        $Config.BackupDirectory = $folderBox.Text
        Save-PutterConfig

        $dlg.DialogResult = [System.Windows.Forms.DialogResult]::OK
        $dlg.Close()
    })

    $cancelButton.Add_Click({
        $dlg.DialogResult = [System.Windows.Forms.DialogResult]::Cancel
        $dlg.Close()
    })

    $dlg.Controls.Add($backupCheck)
    $dlg.Controls.Add($folderLabel)
    $dlg.Controls.Add($folderBox)
    $dlg.Controls.Add($browseButton)
    $dlg.Controls.Add($openButton)
    $dlg.Controls.Add($okButton)
    $dlg.Controls.Add($cancelButton)
    $dlg.AcceptButton = $okButton
    $dlg.CancelButton = $cancelButton

    [void]$dlg.ShowDialog($form)
}

function Show-AboutDialog {
    $dlg = New-Object System.Windows.Forms.Form
    $dlg.Text = 'About Putter'
    $dlg.Width = 520
    $dlg.Height = 300
    $dlg.StartPosition = 'CenterParent'
    $dlg.FormBorderStyle = 'FixedDialog'
    $dlg.MaximizeBox = $false
    $dlg.MinimizeBox = $false

    $title = New-Object System.Windows.Forms.Label
    $title.Text = "Putter $PutterVersion"
    $title.Left = 20
    $title.Top = 20
    $title.Width = 460
    $title.Height = 28
    $title.Font = New-Object System.Drawing.Font(
        $title.Font.FontFamily,
        14,
        [System.Drawing.FontStyle]::Bold
    )

    $description = New-Object System.Windows.Forms.Label
    $description.Text =
        "A lightweight multi-session editor for PuTTY on Windows." +
        [Environment]::NewLine + [Environment]::NewLine +
        "Build date: $PutterBuildDate" +
        [Environment]::NewLine +
        'License: GNU GPL v3.0'
    $description.Left = 20
    $description.Top = 60
    $description.Width = 460
    $description.Height = 85

    $link = New-Object System.Windows.Forms.LinkLabel
    $link.Text = $RepositoryUrl
    $link.Left = 20
    $link.Top = 150
    $link.Width = 460
    $link.Height = 25
    $link.Add_LinkClicked({
        Start-Process $RepositoryUrl
    })

    $backupInfo = New-Object System.Windows.Forms.Label
    $backupState = if ($Config.CreateBackups) { 'Enabled' } else { 'Disabled' }
    $backupInfo.Text =
        "Automatic backups: $backupState" +
        [Environment]::NewLine +
        "Backup folder: $($Config.BackupDirectory)"
    $backupInfo.Left = 20
    $backupInfo.Top = 180
    $backupInfo.Width = 460
    $backupInfo.Height = 45

    $closeButton = New-Object System.Windows.Forms.Button
    $closeButton.Text = 'Close'
    $closeButton.Left = 395
    $closeButton.Top = 225
    $closeButton.Width = 85
    $closeButton.Add_Click({
        $dlg.Close()
    })

    $dlg.Controls.Add($title)
    $dlg.Controls.Add($description)
    $dlg.Controls.Add($link)
    $dlg.Controls.Add($backupInfo)
    $dlg.Controls.Add($closeButton)
    $dlg.AcceptButton = $closeButton

    [void]$dlg.ShowDialog($form)
}

# ============================================================
# Main menu
# ============================================================

$menuStrip = New-Object System.Windows.Forms.MenuStrip

$fileMenu = New-Object System.Windows.Forms.ToolStripMenuItem
$fileMenu.Text = 'File'

$exportAllItem = New-Object System.Windows.Forms.ToolStripMenuItem
$exportAllItem.Text = 'Export all sessions...'
$exportAllItem.Add_Click({
    Export-AllSessions
})

$exportSelectedFileItem = New-Object System.Windows.Forms.ToolStripMenuItem
$exportSelectedFileItem.Text = 'Export selected sessions...'
$exportSelectedFileItem.Add_Click({
    Export-SelectedSessions
})

$importItem = New-Object System.Windows.Forms.ToolStripMenuItem
$importItem.Text = 'Import .reg...'
$importItem.Add_Click({
    Import-RegistryFile
})

$fileSeparator1 = New-Object System.Windows.Forms.ToolStripSeparator
$fileSeparator2 = New-Object System.Windows.Forms.ToolStripSeparator

$exitItem = New-Object System.Windows.Forms.ToolStripMenuItem
$exitItem.Text = 'Exit'
$exitItem.Add_Click({
    $form.Close()
})

[void]$fileMenu.DropDownItems.Add($exportAllItem)
[void]$fileMenu.DropDownItems.Add($exportSelectedFileItem)
[void]$fileMenu.DropDownItems.Add($fileSeparator1)
[void]$fileMenu.DropDownItems.Add($importItem)
[void]$fileMenu.DropDownItems.Add($fileSeparator2)
[void]$fileMenu.DropDownItems.Add($exitItem)

$optionsMenu = New-Object System.Windows.Forms.ToolStripMenuItem
$optionsMenu.Text = 'Options'

$settingsItem = New-Object System.Windows.Forms.ToolStripMenuItem
$settingsItem.Text = 'Settings...'
$settingsItem.Add_Click({
    Show-OptionsDialog
})
[void]$optionsMenu.DropDownItems.Add($settingsItem)

$helpMenu = New-Object System.Windows.Forms.ToolStripMenuItem
$helpMenu.Text = 'Help'

$aboutItem = New-Object System.Windows.Forms.ToolStripMenuItem
$aboutItem.Text = 'About Putter...'
$aboutItem.Add_Click({
    Show-AboutDialog
})
[void]$helpMenu.DropDownItems.Add($aboutItem)

[void]$menuStrip.Items.Add($fileMenu)
[void]$menuStrip.Items.Add($optionsMenu)
[void]$menuStrip.Items.Add($helpMenu)

$fileMenu.Add_DropDownOpening({
    $exportSelectedFileItem.Enabled = ($grid.SelectedRows.Count -gt 0)
})

# ============================================================
# Context menu
# ============================================================

$contextMenu = New-Object System.Windows.Forms.ContextMenuStrip

$multiEditItem = New-Object System.Windows.Forms.ToolStripMenuItem
$multiEditItem.Text = 'Multi-edit selected...'

$separator = New-Object System.Windows.Forms.ToolStripSeparator

$deleteCurrentItem = New-Object System.Windows.Forms.ToolStripMenuItem
$deleteCurrentItem.Text = 'Delete this session...'

$deleteSelectedItem = New-Object System.Windows.Forms.ToolStripMenuItem
$deleteSelectedItem.Text = 'Delete selected...'

[void]$contextMenu.Items.Add($multiEditItem)
[void]$contextMenu.Items.Add($separator)
[void]$contextMenu.Items.Add($deleteCurrentItem)
[void]$contextMenu.Items.Add($deleteSelectedItem)

$grid.ContextMenuStrip = $contextMenu
$script:ContextRow = $null

$grid.Add_CellMouseDown({
    param($sender, $e)

    if ($e.Button -ne [System.Windows.Forms.MouseButtons]::Right) {
        return
    }

    if ($e.RowIndex -lt 0) {
        return
    }

    $script:ContextRow = $grid.Rows[$e.RowIndex]

    if (-not $script:ContextRow.Selected) {
        $grid.ClearSelection()
        $script:ContextRow.Selected = $true

        if ($e.ColumnIndex -ge 0) {
            $grid.CurrentCell = $script:ContextRow.Cells[$e.ColumnIndex]
        }
    }
})

$contextMenu.Add_Opening({
    $count = $grid.SelectedRows.Count

    $multiEditItem.Text = "Multi-edit selected ($count)..."
    $deleteSelectedItem.Text = "Delete selected ($count)..."

    $multiEditItem.Enabled = ($count -gt 0)
    $deleteSelectedItem.Enabled = ($count -gt 0)
    $deleteCurrentItem.Enabled = ($null -ne $script:ContextRow)
})

$deleteCurrentItem.Add_Click({
    if ($null -ne $script:ContextRow) {
        Remove-PutterSessions -Rows @($script:ContextRow)
    }
})

$deleteSelectedItem.Add_Click({
    $rows = @($grid.SelectedRows)
    Remove-PutterSessions -Rows $rows
})

$multiEditItem.Add_Click({
    Show-MultiEditDialog
})

# ============================================================
# Run
# ============================================================

$form.Controls.Add($filterLabel)
$form.Controls.Add($filterBox)
$form.Controls.Add($grid)
$form.Controls.Add($statusLabel)

[void]$form.ShowDialog()
