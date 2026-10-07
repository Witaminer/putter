Add-Type -AssemblyName System.Windows.Forms
Add-Type -AssemblyName System.Drawing

[System.Windows.Forms.Application]::EnableVisualStyles()

# Windows PowerShell 5.1 uses the .NET Framework reference model, while
# PowerShell 7+ uses modern .NET where WinForms and Drawing types are split
# across several assemblies. Keep one source file and select references here.
if ($PSVersionTable.PSEdition -eq 'Desktop') {
    $PutterCompilerReferences = @(
        'System.Windows.Forms',
        'System.Drawing'
    )
}
else {
    $PutterCompilerReferences = @(
        [System.Windows.Forms.Form].Assembly.Location,
        [System.Windows.Forms.Message].Assembly.Location,
        [System.Drawing.Color].Assembly.Location,
        [System.Drawing.SolidBrush].Assembly.Location,
        [System.ComponentModel.Component].Assembly.Location
    ) | Select-Object -Unique
}

# ============================================================
# Putter 0.20
# A lightweight multi-session editor for PuTTY on Windows.
# Find it on https://github.com/Witaminer/putter
# ============================================================

Add-Type -TypeDefinition @'
using System;
using System.Windows.Forms;

public class PutterDataGridView : DataGridView
{
    public event EventHandler SessionLaunchRequested;

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

        Keys outsideEditKeyCode = keyData & Keys.KeyCode;
        Keys outsideEditModifiers = keyData & Keys.Modifiers;

        if (!this.IsCurrentCellInEditMode &&
            outsideEditModifiers == Keys.None &&
            (outsideEditKeyCode == Keys.Home || outsideEditKeyCode == Keys.End))
        {
            if (this.Rows.Count > 0)
            {
                int targetRowIndex =
                    outsideEditKeyCode == Keys.Home ? 0 : this.Rows.Count - 1;
                int targetColumnIndex =
                    this.CurrentCell != null ? this.CurrentCell.ColumnIndex : 0;

                if (targetColumnIndex < 0 ||
                    targetColumnIndex >= this.Columns.Count ||
                    !this.Columns[targetColumnIndex].Visible)
                {
                    targetColumnIndex = this.Columns.GetFirstColumn(
                        DataGridViewElementStates.Visible
                    ).Index;
                }

                this.ClearSelection();
                this.CurrentCell = this.Rows[targetRowIndex].Cells[targetColumnIndex];
                this.Rows[targetRowIndex].Selected = true;
            }

            return true;
        }

        if (!this.IsCurrentCellInEditMode &&
            outsideEditModifiers == Keys.None &&
            outsideEditKeyCode == Keys.Enter)
        {
            if (SessionLaunchRequested != null)
            {
                SessionLaunchRequested(this, EventArgs.Empty);
            }

            return true;
        }

        return base.ProcessCmdKey(ref msg, keyData);
    }
}

public class PutterDarkColorTable : ProfessionalColorTable
{
    private readonly System.Drawing.Color back = System.Drawing.Color.FromArgb(32, 32, 32);
    private readonly System.Drawing.Color hover = System.Drawing.Color.FromArgb(62, 62, 66);
    private readonly System.Drawing.Color border = System.Drawing.Color.FromArgb(85, 85, 90);

    public override System.Drawing.Color ToolStripDropDownBackground { get { return back; } }
    public override System.Drawing.Color ImageMarginGradientBegin { get { return back; } }
    public override System.Drawing.Color ImageMarginGradientMiddle { get { return back; } }
    public override System.Drawing.Color ImageMarginGradientEnd { get { return back; } }
    public override System.Drawing.Color MenuItemSelected { get { return hover; } }
    public override System.Drawing.Color MenuItemBorder { get { return border; } }
    public override System.Drawing.Color MenuItemSelectedGradientBegin { get { return hover; } }
    public override System.Drawing.Color MenuItemSelectedGradientEnd { get { return hover; } }
    public override System.Drawing.Color MenuItemPressedGradientBegin { get { return hover; } }
    public override System.Drawing.Color MenuItemPressedGradientMiddle { get { return hover; } }
    public override System.Drawing.Color MenuItemPressedGradientEnd { get { return hover; } }
    public override System.Drawing.Color SeparatorDark { get { return border; } }
    public override System.Drawing.Color SeparatorLight { get { return border; } }
}

public class PutterDarkRenderer : ToolStripProfessionalRenderer
{
    private readonly System.Drawing.Color back = System.Drawing.Color.FromArgb(32, 32, 32);
    private readonly System.Drawing.Color hover = System.Drawing.Color.FromArgb(62, 62, 66);
    private readonly System.Drawing.Color border = System.Drawing.Color.FromArgb(85, 85, 90);
    private readonly System.Drawing.Color fore = System.Drawing.Color.FromArgb(232, 232, 232);
    private readonly System.Drawing.Color disabled = System.Drawing.Color.FromArgb(135, 135, 135);

    public PutterDarkRenderer() : base(new PutterDarkColorTable())
    {
        this.RoundedEdges = false;
    }

    protected override void OnRenderToolStripBackground(ToolStripRenderEventArgs e)
    {
        using (System.Drawing.SolidBrush brush = new System.Drawing.SolidBrush(back))
        {
            e.Graphics.FillRectangle(brush, e.AffectedBounds);
        }
    }

    protected override void OnRenderMenuItemBackground(ToolStripItemRenderEventArgs e)
    {
        System.Drawing.Rectangle bounds = new System.Drawing.Rectangle(System.Drawing.Point.Empty, e.Item.Size);
        System.Drawing.Color color = (e.Item.Selected || e.Item.Pressed) ? hover : back;

        using (System.Drawing.SolidBrush brush = new System.Drawing.SolidBrush(color))
        {
            e.Graphics.FillRectangle(brush, bounds);
        }
    }

    protected override void OnRenderItemText(ToolStripItemTextRenderEventArgs e)
    {
        e.TextColor = e.Item.Enabled ? fore : disabled;
        base.OnRenderItemText(e);
    }

    protected override void OnRenderSeparator(ToolStripSeparatorRenderEventArgs e)
    {
        int y = e.Item.Height / 2;

        using (System.Drawing.Pen pen = new System.Drawing.Pen(border))
        {
            e.Graphics.DrawLine(pen, 4, y, e.Item.Width - 4, y);
        }
    }

    protected override void OnRenderImageMargin(ToolStripRenderEventArgs e)
    {
        using (System.Drawing.SolidBrush brush = new System.Drawing.SolidBrush(back))
        {
            e.Graphics.FillRectangle(brush, e.AffectedBounds);
        }
    }

    protected override void OnRenderToolStripBorder(ToolStripRenderEventArgs e)
    {
        using (System.Drawing.Pen pen = new System.Drawing.Pen(border))
        {
            System.Drawing.Rectangle rect = new System.Drawing.Rectangle(
                0,
                0,
                e.ToolStrip.Width - 1,
                e.ToolStrip.Height - 1
            );

            e.Graphics.DrawRectangle(pen, rect);
        }
    }
}
'@ -ReferencedAssemblies $PutterCompilerReferences -WarningAction SilentlyContinue

$PutterVersion   = '0.21'
$PutterBuildDate = '2026.10.07'
$RepositoryUrl   = 'https://github.com/Witaminer/putter'

# Embedded application icon. The ICO contains 16x16, 32x32, and 48x48 images.
# Keeping it in the script makes Putter self-contained and ASCII-safe.
$PutterIconBase64 = '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'

function New-PutterIcon {
    $bytes = [Convert]::FromBase64String($PutterIconBase64)
    $stream = New-Object System.IO.MemoryStream(,$bytes)
    $sourceIcon = $null

    try {
        $sourceIcon = New-Object System.Drawing.Icon($stream)
        return $sourceIcon.Clone()
    }
    finally {
        if ($null -ne $sourceIcon) {
            $sourceIcon.Dispose()
        }

        $stream.Dispose()
    }
}

$SessionsPathPS   = 'HKCU:\Software\SimonTatham\PuTTY\Sessions'
$SessionsPathReg  = 'HKCU\Software\SimonTatham\PuTTY\Sessions'

# Resolve Putter's working directory for both the original script and PS2EXE builds.
$PutterRoot = if ($PSScriptRoot) {
    $PSScriptRoot
}
elseif ($ScriptRoot) {
    $ScriptRoot
}
else {
    [AppDomain]::CurrentDomain.BaseDirectory
}

$ConfigPath       = Join-Path $PutterRoot 'Putter.config.json'
$DefaultBackupDir = Join-Path $PutterRoot 'Backups'

$FilterHistoryLimit         = 20
$FilterHistorySeparatorText = '--------------------'
$FilterHistoryClearText     = 'Clear history'

function Normalize-PutterFilterHistory {
    param([object[]]$Items)

    $result = New-Object System.Collections.Generic.List[string]

    foreach ($item in @($Items)) {
        $text = [string]$item

        if ([string]::IsNullOrWhiteSpace($text) -or $text.Length -lt 2) {
            continue
        }

        $exists = $false

        foreach ($existing in $result) {
            if ([string]::Equals(
                    $existing,
                    $text,
                    [System.StringComparison]::OrdinalIgnoreCase)) {
                $exists = $true
                break
            }
        }

        if (-not $exists) {
            $result.Add($text)

            if ($result.Count -ge $FilterHistoryLimit) {
                break
            }
        }
    }

    return @($result)
}

$Config = [PSCustomObject]@{
    CreateBackups          = $true
    BackupDirectory        = $DefaultBackupDir
    RememberWindowGeometry = $true
    WindowX                = $null
    WindowY                = $null
    WindowWidth            = $null
    WindowHeight           = $null
    WindowState            = 'Normal'
    NightMode              = $false
    GridFontSize           = 9
    GridFontBold           = $false
    GridColumnFillWeights  = $null
    GridColumnOrder        = $null
    GridSort               = ''
    FilterHistory          = @()
    PuttyLauncher          = ''
    LaunchDelayMilliseconds = 1000
    CloseToTray            = $true
    MinimizeToTray         = $false
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

        if ($null -ne $loadedConfig.RememberWindowGeometry) {
            $Config.RememberWindowGeometry = [bool]$loadedConfig.RememberWindowGeometry
        }

        foreach ($propertyName in @('WindowX', 'WindowY', 'WindowWidth', 'WindowHeight')) {
            if ($null -ne $loadedConfig.$propertyName) {
                $Config.$propertyName = [int]$loadedConfig.$propertyName
            }
        }

        if (-not [string]::IsNullOrWhiteSpace([string]$loadedConfig.WindowState)) {
            $Config.WindowState = [string]$loadedConfig.WindowState
        }

        if ($null -ne $loadedConfig.NightMode) {
            $Config.NightMode = [bool]$loadedConfig.NightMode
        }

        if ($null -ne $loadedConfig.GridFontSize) {
            $Config.GridFontSize = [Math]::Min(24, [Math]::Max(7, [int]$loadedConfig.GridFontSize))
        }

        if ($null -ne $loadedConfig.GridFontBold) {
            $Config.GridFontBold = [bool]$loadedConfig.GridFontBold
        }

        if ($null -ne $loadedConfig.GridColumnFillWeights) {
            $Config.GridColumnFillWeights = $loadedConfig.GridColumnFillWeights
        }

        if ($null -ne $loadedConfig.GridColumnOrder) {
            $Config.GridColumnOrder = @($loadedConfig.GridColumnOrder)
        }

        if ($null -ne $loadedConfig.GridSort) {
            $Config.GridSort = [string]$loadedConfig.GridSort
        }

        if ($null -ne $loadedConfig.FilterHistory) {
            $Config.FilterHistory = Normalize-PutterFilterHistory -Items @($loadedConfig.FilterHistory)
        }

        if ($null -ne $loadedConfig.PuttyLauncher) {
            $Config.PuttyLauncher = [string]$loadedConfig.PuttyLauncher
        }

        if ($null -ne $loadedConfig.LaunchDelayMilliseconds) {
            $Config.LaunchDelayMilliseconds = [Math]::Max(0, [int]$loadedConfig.LaunchDelayMilliseconds)
        }

        if ($null -ne $loadedConfig.CloseToTray) {
            $Config.CloseToTray = [bool]$loadedConfig.CloseToTray
        }

        if ($null -ne $loadedConfig.MinimizeToTray) {
            $Config.MinimizeToTray = [bool]$loadedConfig.MinimizeToTray
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

function Restore-PutterWindowGeometry {
    param([System.Windows.Forms.Form]$Form)

    if (-not $Config.RememberWindowGeometry) {
        return
    }

    if ($null -eq $Config.WindowX -or
        $null -eq $Config.WindowY -or
        $null -eq $Config.WindowWidth -or
        $null -eq $Config.WindowHeight) {
        return
    }

    $width = [Math]::Max(700, [int]$Config.WindowWidth)
    $height = [Math]::Max(450, [int]$Config.WindowHeight)
    $bounds = New-Object System.Drawing.Rectangle(
        [int]$Config.WindowX,
        [int]$Config.WindowY,
        $width,
        $height
    )

    $isVisible = $false

    foreach ($screen in [System.Windows.Forms.Screen]::AllScreens) {
        if ($screen.WorkingArea.IntersectsWith($bounds)) {
            $isVisible = $true
            break
        }
    }

    if ($isVisible) {
        $Form.StartPosition = 'Manual'
        $Form.SetBounds($bounds.X, $bounds.Y, $bounds.Width, $bounds.Height)

        if ($Config.WindowState -eq 'Maximized') {
            $Form.WindowState = [System.Windows.Forms.FormWindowState]::Maximized
        }
    }
}

function Save-PutterWindowGeometry {
    param([System.Windows.Forms.Form]$Form)

    if (-not $Config.RememberWindowGeometry) {
        return
    }

    $bounds = if ($Form.WindowState -eq [System.Windows.Forms.FormWindowState]::Normal) {
        $Form.Bounds
    }
    else {
        $Form.RestoreBounds
    }

    $Config.WindowX = $bounds.X
    $Config.WindowY = $bounds.Y
    $Config.WindowWidth = $bounds.Width
    $Config.WindowHeight = $bounds.Height
    $Config.WindowState = if ($Form.WindowState -eq [System.Windows.Forms.FormWindowState]::Maximized) {
        'Maximized'
    }
    else {
        'Normal'
    }

    Save-PutterConfig
}

function Get-PutterTheme {
    if ($Config.NightMode) {
        return [PSCustomObject]@{
            BackColor          = [System.Drawing.Color]::FromArgb(32, 32, 32)
            ForeColor          = [System.Drawing.Color]::FromArgb(232, 232, 232)
            InputBackColor     = [System.Drawing.Color]::FromArgb(45, 45, 48)
            HeaderBackColor    = [System.Drawing.Color]::FromArgb(52, 52, 56)
            GridColor          = [System.Drawing.Color]::FromArgb(70, 70, 74)
            ButtonBackColor    = [System.Drawing.Color]::FromArgb(55, 55, 58)
            SelectionBackColor = [System.Drawing.SystemColors]::Highlight
            SelectionForeColor = [System.Drawing.SystemColors]::HighlightText
        }
    }

    return [PSCustomObject]@{
        BackColor          = [System.Drawing.SystemColors]::Control
        ForeColor          = [System.Drawing.SystemColors]::ControlText
        InputBackColor     = [System.Drawing.SystemColors]::Window
        HeaderBackColor    = [System.Drawing.SystemColors]::Control
        GridColor          = [System.Drawing.SystemColors]::ControlDark
        ButtonBackColor    = [System.Drawing.SystemColors]::Control
        SelectionBackColor = [System.Drawing.SystemColors]::Highlight
        SelectionForeColor = [System.Drawing.SystemColors]::HighlightText
    }
}

function Apply-PutterThemeToToolStripItems {
    param(
        [System.Windows.Forms.ToolStripItemCollection]$Items,
        $Theme
    )

    foreach ($item in $Items) {
        $item.BackColor = $Theme.BackColor
        $item.ForeColor = $Theme.ForeColor

        if ($item -is [System.Windows.Forms.ToolStripDropDownItem]) {
            $item.DropDown.BackColor = $Theme.BackColor
            $item.DropDown.ForeColor = $Theme.ForeColor
            Apply-PutterThemeToToolStripItems -Items $item.DropDownItems -Theme $Theme
        }
    }
}

function Apply-PutterTheme {
    param([System.Windows.Forms.Control]$Control)

    $theme = Get-PutterTheme

    if ($Control -is [System.Windows.Forms.DataGridView]) {
        $Control.BackgroundColor = $theme.InputBackColor
        $Control.GridColor = $theme.GridColor
        $Control.EnableHeadersVisualStyles = $false

        $Control.DefaultCellStyle.BackColor = $theme.InputBackColor
        $Control.DefaultCellStyle.ForeColor = $theme.ForeColor
        $Control.DefaultCellStyle.SelectionBackColor = $theme.SelectionBackColor
        $Control.DefaultCellStyle.SelectionForeColor = $theme.SelectionForeColor

        $Control.ColumnHeadersDefaultCellStyle.BackColor = $theme.HeaderBackColor
        $Control.ColumnHeadersDefaultCellStyle.ForeColor = $theme.ForeColor
        $Control.ColumnHeadersDefaultCellStyle.SelectionBackColor = $theme.HeaderBackColor
        $Control.ColumnHeadersDefaultCellStyle.SelectionForeColor = $theme.ForeColor

        $Control.RowHeadersDefaultCellStyle.BackColor = $theme.HeaderBackColor
        $Control.RowHeadersDefaultCellStyle.ForeColor = $theme.ForeColor
    }
    elseif ($Control -is [System.Windows.Forms.TextBoxBase] -or
            $Control -is [System.Windows.Forms.ComboBox] -or
            $Control -is [System.Windows.Forms.NumericUpDown]) {
        $Control.BackColor = $theme.InputBackColor
        $Control.ForeColor = $theme.ForeColor
    }
    elseif ($Control -is [System.Windows.Forms.Button]) {
        $Control.BackColor = $theme.ButtonBackColor
        $Control.ForeColor = $theme.ForeColor
        $Control.UseVisualStyleBackColor = -not $Config.NightMode
    }
    else {
        $Control.BackColor = $theme.BackColor
        $Control.ForeColor = $theme.ForeColor
    }

    foreach ($child in $Control.Controls) {
        Apply-PutterTheme -Control $child
    }
}

function Apply-PutterGridFont {
    $style = if ($Config.GridFontBold) {
        [System.Drawing.FontStyle]::Bold
    }
    else {
        [System.Drawing.FontStyle]::Regular
    }

    $font = New-Object System.Drawing.Font(
        $grid.Font.FontFamily,
        [single]$Config.GridFontSize,
        $style
    )

    $grid.Font = $font
    $grid.DefaultCellStyle.Font = $font
    $grid.ColumnHeadersDefaultCellStyle.Font = $font

    $rowHeight = [Math]::Max(22, $font.Height + 7)
    $grid.RowTemplate.Height = $rowHeight

    foreach ($row in $grid.Rows) {
        $row.Height = $rowHeight
    }
}

function Restore-PutterColumnWidths {
    if ($null -eq $Config.GridColumnFillWeights) {
        return
    }

    $originalMode = $grid.AutoSizeColumnsMode

    try {
        $grid.SuspendLayout()

        # Setting FillWeight one column at a time while Fill mode is active causes
        # DataGridView to rebalance the other columns after every assignment.
        # Temporarily disable Fill mode, apply all saved weights, then enable it again.
        $grid.AutoSizeColumnsMode = [System.Windows.Forms.DataGridViewAutoSizeColumnsMode]::None

        foreach ($columnName in @('Session', 'WinTitle', 'HostName', 'PortNumber', 'UserName', 'PublicKeyFile')) {
            if (-not $grid.Columns.Contains($columnName)) {
                continue
            }

            $property = $Config.GridColumnFillWeights.PSObject.Properties[$columnName]

            if ($null -eq $property) {
                continue
            }

            $fillWeight = [single]$property.Value

            if ($fillWeight -gt 0) {
                $grid.Columns[$columnName].FillWeight = $fillWeight
            }
        }
    }
    finally {
        $grid.AutoSizeColumnsMode = $originalMode
        $grid.ResumeLayout()
    }
}

function Save-PutterColumnWidths {
    $weights = [ordered]@{}

    foreach ($columnName in @('Session', 'WinTitle', 'HostName', 'PortNumber', 'UserName', 'PublicKeyFile')) {
        if ($grid.Columns.Contains($columnName)) {
            $weights[$columnName] = [Math]::Round(
                [double]$grid.Columns[$columnName].FillWeight,
                3
            )
        }
    }

    $Config.GridColumnFillWeights = $weights
    Save-PutterConfig
}

function Restore-PutterColumnOrder {
    $columnNames = @('Session', 'WinTitle', 'HostName', 'PortNumber', 'UserName', 'PublicKeyFile')
    $savedOrder = @(
        $Config.GridColumnOrder |
            Where-Object { $_ -in $columnNames }
    )

    if ($savedOrder.Count -eq 0) {
        $order = $columnNames
    }
    else {
        $order = @(
            $savedOrder
            $columnNames | Where-Object { $_ -notin $savedOrder }
        )
    }

    try {
        if ($grid.Columns.Contains('Start')) {
            $grid.Columns['Start'].DisplayIndex = 0
        }

        $displayIndex = 1

        foreach ($columnName in $order) {
            if ($grid.Columns.Contains($columnName)) {
                $grid.Columns[$columnName].DisplayIndex = $displayIndex
                $displayIndex++
            }
        }
    }
    catch {
        # Ignore stale or invalid column-order settings.
    }
}

function Save-PutterColumnOrder {
    $columnNames = @('Session', 'WinTitle', 'HostName', 'PortNumber', 'UserName', 'PublicKeyFile')

    $Config.GridColumnOrder = @(
        $grid.Columns |
            Where-Object { $_.Name -in $columnNames } |
            Sort-Object DisplayIndex |
            ForEach-Object { $_.Name }
    )

    Save-PutterConfig
}

function Restore-PutterSort {
    if ([string]::IsNullOrWhiteSpace([string]$Config.GridSort)) {
        return
    }

    try {
        $view.Sort = [string]$Config.GridSort
    }
    catch {
        # Ignore a stale sort expression if columns change in a future version.
    }
}

function Save-PutterSort {
    $Config.GridSort = [string]$view.Sort
    Save-PutterConfig
}

function Apply-PutterMainTheme {
    $theme = Get-PutterTheme

    Apply-PutterTheme -Control $form

    $menuStrip.BackColor = $theme.BackColor
    $menuStrip.ForeColor = $theme.ForeColor
    Apply-PutterThemeToToolStripItems -Items $menuStrip.Items -Theme $theme

    $contextMenu.BackColor = $theme.BackColor
    $contextMenu.ForeColor = $theme.ForeColor
    Apply-PutterThemeToToolStripItems -Items $contextMenu.Items -Theme $theme

    if ($Config.NightMode) {
        $darkRenderer = New-Object PutterDarkRenderer
        $menuStrip.Renderer = $darkRenderer
        $contextMenu.Renderer = $darkRenderer
    }
    else {
        $menuStrip.Renderer = New-Object System.Windows.Forms.ToolStripSystemRenderer
        $contextMenu.Renderer = New-Object System.Windows.Forms.ToolStripSystemRenderer
    }

    Apply-PutterGridFont
}

# ============================================================
# Main window
# ============================================================

$form = New-Object System.Windows.Forms.Form
$form.Text = "Putter $PutterVersion"
$form.Icon = New-PutterIcon
$form.Width = 1250
$form.Height = 750
$form.StartPosition = 'CenterScreen'

$filterLabel = New-Object System.Windows.Forms.Label
$filterLabel.Text = 'Filter:'
$filterLabel.AutoSize = $true
$filterLabel.Left = 10
$filterLabel.Top = 39

$filterBox = New-Object System.Windows.Forms.ComboBox
$filterBox.Left = 60
$filterBox.Top = 34
$filterBox.Width = 420
$filterBox.DropDownStyle = [System.Windows.Forms.ComboBoxStyle]::DropDown
$filterBox.MaxDropDownItems = 22

$filterHistoryTimer = New-Object System.Windows.Forms.Timer
$filterHistoryTimer.Interval = 2000

$clearFilterButton = New-Object System.Windows.Forms.Button
$clearFilterButton.Text = 'Clear'
$clearFilterButton.Left = 490
$clearFilterButton.Top = 33
$clearFilterButton.Width = 70
$clearFilterButton.Height = 24
$clearFilterButton.FlatStyle = [System.Windows.Forms.FlatStyle]::System

$script:UpdatingFilterHistory = $false
$script:FilterTextBeforeDropDown = ''

function Refresh-PutterFilterHistoryItems {
    $currentText = $filterBox.Text

    $script:UpdatingFilterHistory = $true

    try {
        $filterBox.BeginUpdate()
        $filterBox.Items.Clear()

        foreach ($entry in @($Config.FilterHistory)) {
            [void]$filterBox.Items.Add([string]$entry)
        }

        if (@($Config.FilterHistory).Count -gt 0) {
            [void]$filterBox.Items.Add($FilterHistorySeparatorText)
            [void]$filterBox.Items.Add($FilterHistoryClearText)
        }

        $filterBox.SelectedIndex = -1
        $filterBox.Text = $currentText
        $filterBox.SelectionStart = $filterBox.Text.Length
    }
    finally {
        $filterBox.EndUpdate()
        $script:UpdatingFilterHistory = $false
    }
}

function Add-PutterFilterHistoryEntry {
    param([string]$Text)

    if ([string]::IsNullOrWhiteSpace($Text) -or
        $Text.Length -lt 2 -or
        $null -eq $view -or
        $view.Count -eq 0) {
        return
    }

    $newHistory = New-Object System.Collections.Generic.List[string]
    $newHistory.Add($Text)

    foreach ($existing in @($Config.FilterHistory)) {
        if ([string]::Equals(
                [string]$existing,
                $Text,
                [System.StringComparison]::OrdinalIgnoreCase)) {
            continue
        }

        $newHistory.Add([string]$existing)

        if ($newHistory.Count -ge $FilterHistoryLimit) {
            break
        }
    }

    $Config.FilterHistory = @($newHistory)
    Save-PutterConfig
    Refresh-PutterFilterHistoryItems
}

function Clear-PutterFilterHistory {
    $Config.FilterHistory = @()
    Save-PutterConfig
    Refresh-PutterFilterHistoryItems
}

$grid = New-Object PutterDataGridView
$grid.Left = 10
$grid.Top = 69
$grid.Width = 1210
$grid.Height = 550
$grid.Anchor = 'Top,Bottom,Left,Right'
$grid.AllowUserToAddRows = $false
$grid.AllowUserToDeleteRows = $false
$grid.AllowUserToOrderColumns = $true
$grid.AllowUserToResizeRows = $false
$grid.SelectionMode = 'FullRowSelect'
$grid.MultiSelect = $true
$grid.AutoSizeColumnsMode = 'Fill'
$grid.EditMode = 'EditProgrammatically'

$refreshButton = New-Object System.Windows.Forms.Button
$refreshButton.Text = 'Refresh'
$refreshButton.Left = 10
$refreshButton.Top = 630
$refreshButton.Width = 100
$refreshButton.Height = 32
$refreshButton.Anchor = 'Bottom,Left'
$refreshButton.FlatStyle = [System.Windows.Forms.FlatStyle]::System

$openButtonMain = New-Object System.Windows.Forms.Button
$openButtonMain.Text = 'Open'
$openButtonMain.Left = 825
$openButtonMain.Top = 630
$openButtonMain.Width = 90
$openButtonMain.Height = 32
$openButtonMain.Anchor = 'Bottom,Right'
$openButtonMain.FlatStyle = [System.Windows.Forms.FlatStyle]::System

$renameButton = New-Object System.Windows.Forms.Button
$renameButton.Text = 'Rename'
$renameButton.Left = 920
$renameButton.Top = 630
$renameButton.Width = 90
$renameButton.Height = 32
$renameButton.Anchor = 'Bottom,Right'
$renameButton.FlatStyle = [System.Windows.Forms.FlatStyle]::System

$copyButtonMain = New-Object System.Windows.Forms.Button
$copyButtonMain.Text = 'Copy'
$copyButtonMain.Left = 1015
$copyButtonMain.Top = 630
$copyButtonMain.Width = 90
$copyButtonMain.Height = 32
$copyButtonMain.Anchor = 'Bottom,Right'
$copyButtonMain.FlatStyle = [System.Windows.Forms.FlatStyle]::System

$deleteButtonMain = New-Object System.Windows.Forms.Button
$deleteButtonMain.Text = 'Delete'
$deleteButtonMain.Left = 1110
$deleteButtonMain.Top = 630
$deleteButtonMain.Width = 90
$deleteButtonMain.Height = 32
$deleteButtonMain.Anchor = 'Bottom,Right'
$deleteButtonMain.FlatStyle = [System.Windows.Forms.FlatStyle]::System

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
[void]$table.Columns.Add('WinTitle')
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

$startColumn = New-Object System.Windows.Forms.DataGridViewButtonColumn
$startColumn.Name = 'Start'
$startColumn.HeaderText = ''
$startColumn.Text = 'Open'
$startColumn.UseColumnTextForButtonValue = $true
$startColumn.FlatStyle = [System.Windows.Forms.FlatStyle]::System
$startColumn.Width = 60
$startColumn.MinimumWidth = 60
$startColumn.AutoSizeMode = [System.Windows.Forms.DataGridViewAutoSizeColumnMode]::None
[void]$grid.Columns.Insert(0, $startColumn)

function Update-Status {
    $selectedCount = $grid.SelectedRows.Count
    $statusLabel.Text = "Sessions: $($table.Rows.Count)    Selected: $selectedCount"

    if ($null -ne $openButtonMain) {
        $openButtonMain.Enabled = ($selectedCount -gt 0)
        $renameButton.Enabled = ($selectedCount -eq 1)
        $copyButtonMain.Enabled = ($selectedCount -eq 1)
        $deleteButtonMain.Enabled = ($selectedCount -gt 0)
    }
}

function Get-PutterGridViewState {
    if ($grid.Rows.Count -eq 0) {
        return $null
    }

    $selectedRegistryNames = @(
        $grid.SelectedRows |
            ForEach-Object { [string]$_.Cells['RegistryName'].Value }
    )

    $currentRegistryName = $null
    $currentColumnName = $null
    $currentRowIndex = -1

    if ($null -ne $grid.CurrentRow) {
        $currentRegistryName = [string]$grid.CurrentRow.Cells['RegistryName'].Value
        $currentRowIndex = $grid.CurrentRow.Index
    }

    if ($null -ne $grid.CurrentCell) {
        $currentColumnName = $grid.Columns[$grid.CurrentCell.ColumnIndex].Name
    }

    $firstDisplayedIndex = -1
    $firstDisplayedRegistryName = $null

    try {
        $firstDisplayedIndex = $grid.FirstDisplayedScrollingRowIndex

        if ($firstDisplayedIndex -ge 0 -and $firstDisplayedIndex -lt $grid.Rows.Count) {
            $firstDisplayedRegistryName = [string]$grid.Rows[$firstDisplayedIndex].Cells['RegistryName'].Value
        }
    }
    catch {
    }

    return [PSCustomObject]@{
        SelectedRegistryNames       = $selectedRegistryNames
        CurrentRegistryName         = $currentRegistryName
        CurrentColumnName           = $currentColumnName
        CurrentRowIndex             = $currentRowIndex
        FirstDisplayedRegistryName  = $firstDisplayedRegistryName
        FirstDisplayedIndex         = $firstDisplayedIndex
    }
}

function Restore-PutterGridViewState {
    param($State)

    if ($null -eq $State -or $grid.Rows.Count -eq 0) {
        return
    }

    $rowsByRegistry = @{}

    foreach ($row in $grid.Rows) {
        $registryName = [string]$row.Cells['RegistryName'].Value

        if (-not [string]::IsNullOrEmpty($registryName)) {
            $rowsByRegistry[$registryName] = $row
        }
    }

    $currentRow = $null

    if (-not [string]::IsNullOrEmpty([string]$State.CurrentRegistryName) -and
        $rowsByRegistry.ContainsKey([string]$State.CurrentRegistryName)) {
        $currentRow = $rowsByRegistry[[string]$State.CurrentRegistryName]
    }

    if ($null -ne $currentRow) {
        $columnName = [string]$State.CurrentColumnName

        if ([string]::IsNullOrEmpty($columnName) -or
            -not $grid.Columns.Contains($columnName) -or
            -not $grid.Columns[$columnName].Visible) {
            $columnName = 'Session'
        }

        try {
            $grid.CurrentCell = $currentRow.Cells[$columnName]
        }
        catch {
        }
    }

    $grid.ClearSelection()
    $restoredSelection = $false

    foreach ($registryName in @($State.SelectedRegistryNames)) {
        if ($rowsByRegistry.ContainsKey([string]$registryName)) {
            $rowsByRegistry[[string]$registryName].Selected = $true
            $restoredSelection = $true
        }
    }

    if (-not $restoredSelection -and @($State.SelectedRegistryNames).Count -gt 0) {
        $fallbackIndex = [Math]::Min(
            [Math]::Max(0, [int]$State.CurrentRowIndex),
            $grid.Rows.Count - 1
        )
        $fallbackRow = $grid.Rows[$fallbackIndex]
        $fallbackRow.Selected = $true

        try {
            $grid.CurrentCell = $fallbackRow.Cells['Session']
        }
        catch {
        }
    }

    $firstDisplayedRow = $null

    if (-not [string]::IsNullOrEmpty([string]$State.FirstDisplayedRegistryName) -and
        $rowsByRegistry.ContainsKey([string]$State.FirstDisplayedRegistryName)) {
        $firstDisplayedRow = $rowsByRegistry[[string]$State.FirstDisplayedRegistryName]
    }

    $firstDisplayedIndex = if ($null -ne $firstDisplayedRow) {
        $firstDisplayedRow.Index
    }
    else {
        [Math]::Min(
            [Math]::Max(0, [int]$State.FirstDisplayedIndex),
            $grid.Rows.Count - 1
        )
    }

    try {
        $grid.FirstDisplayedScrollingRowIndex = $firstDisplayedIndex
    }
    catch {
    }
}

function Load-PuttySessions {
    $gridState = Get-PutterGridViewState
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
        $row.WinTitle = [string]$p.WinTitle
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

    Restore-PutterGridViewState -State $gridState
    Update-Status
}

$grid.Add_DataBindingComplete({
    if ($grid.Columns.Contains('RegistryName')) {
        $grid.Columns['RegistryName'].Visible = $false
    }

    $headers = [ordered]@{
        Session       = 'Session'
        WinTitle      = 'Title'
        HostName      = 'Host'
        PortNumber    = 'Port'
        UserName      = 'Login'
        PublicKeyFile = 'PublicKeyFile'
    }

    foreach ($columnName in $headers.Keys) {
        if ($grid.Columns.Contains($columnName)) {
            $grid.Columns[$columnName].HeaderText = $headers[$columnName]
        }
    }
})

Load-PuttySessions

# ============================================================
# Filtering and selection
# ============================================================

Refresh-PutterFilterHistoryItems

$filterHistoryTimer.Add_Tick({
    $filterHistoryTimer.Stop()
    Add-PutterFilterHistoryEntry -Text $filterBox.Text
})

$filterBox.Add_TextChanged({
    $filterHistoryTimer.Stop()

    if ($script:UpdatingFilterHistory) {
        return
    }

    if ($filterBox.Text -eq $FilterHistorySeparatorText -or
        $filterBox.Text -eq $FilterHistoryClearText) {
        return
    }

    $text = $filterBox.Text.Replace("'", "''")

    if ([string]::IsNullOrWhiteSpace($text)) {
        $view.RowFilter = ''
    }
    else {
        $view.RowFilter =
            "Session LIKE '%$text%' OR " +
            "WinTitle LIKE '%$text%' OR " +
            "HostName LIKE '%$text%' OR " +
            "UserName LIKE '%$text%' OR " +
            "PublicKeyFile LIKE '%$text%'"
    }

    if (-not [string]::IsNullOrWhiteSpace($filterBox.Text) -and
        $filterBox.Text.Length -ge 2 -and
        $view.Count -gt 0) {
        $filterHistoryTimer.Start()
    }
})

$filterBox.Add_DropDown({
    $filterHistoryTimer.Stop()
    $script:FilterTextBeforeDropDown = $filterBox.Text
    Refresh-PutterFilterHistoryItems
})

$filterBox.Add_SelectionChangeCommitted({
    $selected = [string]$filterBox.SelectedItem

    if ($selected -eq $FilterHistorySeparatorText) {
        $script:UpdatingFilterHistory = $true

        try {
            $filterBox.SelectedIndex = -1
            $filterBox.Text = $script:FilterTextBeforeDropDown
            $filterBox.SelectionStart = $filterBox.Text.Length
        }
        finally {
            $script:UpdatingFilterHistory = $false
        }

        return
    }

    if ($selected -eq $FilterHistoryClearText) {
        $script:UpdatingFilterHistory = $true

        try {
            $filterBox.SelectedIndex = -1
            $filterBox.Text = $script:FilterTextBeforeDropDown
            $filterBox.SelectionStart = $filterBox.Text.Length
        }
        finally {
            $script:UpdatingFilterHistory = $false
        }

        Clear-PutterFilterHistory
        return
    }

    if (-not [string]::IsNullOrWhiteSpace($selected)) {
        $filterBox.Text = $selected
        $filterBox.SelectionStart = $filterBox.Text.Length
        $filterHistoryTimer.Stop()
        Add-PutterFilterHistoryEntry -Text $selected
    }
})

$filterBox.Add_KeyDown({
    param($sender, $e)

    if ($e.KeyCode -eq [System.Windows.Forms.Keys]::Enter) {
        $filterHistoryTimer.Stop()
        Add-PutterFilterHistoryEntry -Text $filterBox.Text
        $e.Handled = $true
        $e.SuppressKeyPress = $true
    }
})

$filterBox.Add_Leave({
    $filterHistoryTimer.Stop()
    Add-PutterFilterHistoryEntry -Text $filterBox.Text
})

$clearFilterButton.Add_Click({
    $filterHistoryTimer.Stop()
    Add-PutterFilterHistoryEntry -Text $filterBox.Text
    $filterBox.Text = ''
    $filterBox.Focus()
})

$grid.Add_CellContentClick({
    param($sender, $e)

    if ($e.RowIndex -ge 0 -and
        $e.ColumnIndex -ge 0 -and
        $grid.Columns[$e.ColumnIndex].Name -eq 'Start') {
        Start-PutterSessionRows -Rows @($grid.Rows[$e.RowIndex])
    }
})

$grid.Add_SelectionChanged({
    Update-Status
})

$refreshButton.Add_Click({
    Load-PuttySessions
})

$openButtonMain.Add_Click({
    Start-PutterSessions
})

$renameButton.Add_Click({
    $rows = @($grid.SelectedRows)

    if ($rows.Count -eq 1) {
        $grid.CurrentCell = $rows[0].Cells['Session']
        $grid.BeginEdit($true)
    }
})

$copyButtonMain.Add_Click({
    $rows = @($grid.SelectedRows)

    if ($rows.Count -eq 1) {
        Copy-PutterSession -Row $rows[0]
    }
})

$deleteButtonMain.Add_Click({
    $rows = @($grid.SelectedRows)

    if ($rows.Count -gt 0) {
        Remove-PutterSessions -Rows $rows
    }
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

    if ($columnName -eq 'RegistryName' -or $columnName -eq 'Start') {
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
        elseif ($columnName -in @('WinTitle', 'HostName', 'UserName', 'PublicKeyFile')) {
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

function Copy-PutterSession {
    param([System.Windows.Forms.DataGridViewRow]$Row)

    if ($null -eq $Row) {
        return
    }

    $sourceHumanName = [string]$Row.Cells['Session'].Value
    $sourceRegistryName = [string]$Row.Cells['RegistryName'].Value
    $sourceRegistryPath = Join-Path $SessionsPathPS $sourceRegistryName

    $dlg = New-Object System.Windows.Forms.Form
    $dlg.Text = 'Putter - Copy session'
    $dlg.Width = 520
    $dlg.Height = 180
    $dlg.StartPosition = 'CenterParent'
    $dlg.FormBorderStyle = 'FixedDialog'
    $dlg.MaximizeBox = $false
    $dlg.MinimizeBox = $false

    $label = New-Object System.Windows.Forms.Label
    $label.Text = 'New session name:'
    $label.Left = 15
    $label.Top = 20
    $label.AutoSize = $true

    $nameBox = New-Object System.Windows.Forms.TextBox
    $nameBox.Left = 15
    $nameBox.Top = 45
    $nameBox.Width = 475
    $nameBox.Text = "$sourceHumanName - Copy"
    $nameBox.ShortcutsEnabled = $true

    $copyButton = New-Object System.Windows.Forms.Button
    $copyButton.Text = 'Copy'
    $copyButton.Left = 310
    $copyButton.Top = 85
    $copyButton.Width = 85

    $cancelButton = New-Object System.Windows.Forms.Button
    $cancelButton.Text = 'Cancel'
    $cancelButton.Left = 405
    $cancelButton.Top = 85
    $cancelButton.Width = 85

    $copyButton.Add_Click({
        $newHumanName = $nameBox.Text.Trim()

        if ([string]::IsNullOrWhiteSpace($newHumanName)) {
            Show-PutterError 'Session name cannot be empty.'
            return
        }

        $newRegistryName = ConvertTo-PuttySessionName $newHumanName
        $newRegistryPath = Join-Path $SessionsPathPS $newRegistryName

        if (Test-Path -LiteralPath $newRegistryPath) {
            Show-PutterError "Session '$newHumanName' already exists."
            return
        }

        try {
            $backupFile = Backup-PuttySessions

            Copy-Item -LiteralPath $sourceRegistryPath -Destination $newRegistryPath -Recurse -ErrorAction Stop

            $dlg.Close()
            Load-PuttySessions

            foreach ($gridRow in $grid.Rows) {
                if ([string]$gridRow.Cells['RegistryName'].Value -eq $newRegistryName) {
                    $grid.ClearSelection()
                    $gridRow.Selected = $true
                    $grid.CurrentCell = $gridRow.Cells['Session']
                    break
                }
            }

            $statusLabel.Text = "Copied session: $sourceHumanName -> $newHumanName$(Get-BackupStatusSuffix $backupFile)"
        }
        catch {
            Show-PutterError $_.Exception.Message 'Putter - Copy failed'
        }
    })

    $cancelButton.Add_Click({
        $dlg.Close()
    })

    $dlg.Controls.Add($label)
    $dlg.Controls.Add($nameBox)
    $dlg.Controls.Add($copyButton)
    $dlg.Controls.Add($cancelButton)
    $dlg.AcceptButton = $copyButton
    $dlg.CancelButton = $cancelButton

    $dlg.Add_Shown({
        $nameBox.Focus()
        $nameBox.SelectAll()
    })

    Apply-PutterTheme -Control $dlg
    [void]$dlg.ShowDialog($form)
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
    $dlg.Height = 475
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

    $titleEdit = Add-EditLine 'Title' 65
    $hostEdit = Add-EditLine 'Host' 100
    $portEdit = Add-EditLine 'Port' 135
    $userEdit = Add-EditLine 'Login' 170
    $keyEdit = Add-EditLine 'PublicKeyFile' 205

    $sessionCheck = New-Object System.Windows.Forms.CheckBox
    $sessionCheck.Text = 'Session name'
    $sessionCheck.Left = 15
    $sessionCheck.Top = 250
    $sessionCheck.Width = 130

    $findLabel = New-Object System.Windows.Forms.Label
    $findLabel.Text = 'Find:'
    $findLabel.Left = 155
    $findLabel.Top = 251
    $findLabel.AutoSize = $true

    $findBox = New-Object System.Windows.Forms.TextBox
    $findBox.Left = 200
    $findBox.Top = 247
    $findBox.Width = 180
    $findBox.Enabled = $false
    $findBox.ShortcutsEnabled = $true

    $replaceLabel = New-Object System.Windows.Forms.Label
    $replaceLabel.Text = 'Replace:'
    $replaceLabel.Left = 390
    $replaceLabel.Top = 251
    $replaceLabel.AutoSize = $true

    $replaceBox = New-Object System.Windows.Forms.TextBox
    $replaceBox.Left = 455
    $replaceBox.Top = 247
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
    $hint.Top = 280
    $hint.Width = 475
    $hint.Height = 35
    $hint.Text = 'Session name uses Find/Replace so each session keeps a unique name.'
    $dlg.Controls.Add($hint)

    $applyButton = New-Object System.Windows.Forms.Button
    $applyButton.Text = 'Apply'
    $applyButton.Left = 450
    $applyButton.Top = 360
    $applyButton.Width = 85

    $cancelButton = New-Object System.Windows.Forms.Button
    $cancelButton.Text = 'Cancel'
    $cancelButton.Left = 545
    $cancelButton.Top = 360
    $cancelButton.Width = 85

    $cancelButton.Add_Click({
        $dlg.Close()
    })

    $applyButton.Add_Click({
        $anything =
            $titleEdit.Check.Checked -or
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
                Show-PutterError 'Port must be a number.'
                return
            }

            if ($parsedPort -lt 1 -or $parsedPort -gt 65535) {
                Show-PutterError 'Port must be in the range 1-65535.'
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

        if ($titleEdit.Check.Checked) {
            $changes += "Title = $($titleEdit.Text.Text)"
        }

        if ($hostEdit.Check.Checked) {
            $changes += "Host = $($hostEdit.Text.Text)"
        }

        if ($portEdit.Check.Checked) {
            $changes += "Port = $port"
        }

        if ($userEdit.Check.Checked) {
            $changes += "Login = $($userEdit.Text.Text)"
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

                if ($titleEdit.Check.Checked) {
                    Set-ItemProperty -LiteralPath $registryPath -Name 'WinTitle' -Value $titleEdit.Text.Text -ErrorAction Stop
                }

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

    Apply-PutterTheme -Control $dlg
    [void]$dlg.ShowDialog($form)
}

function Start-PutterSessionNames {
    param([string[]]$SessionNames)

    $names = @($SessionNames | Where-Object {
        -not [string]::IsNullOrWhiteSpace([string]$_)
    })

    if ($names.Count -eq 0) {
        return
    }

    $launcher = [string]$Config.PuttyLauncher

    if ([string]::IsNullOrWhiteSpace($launcher)) {
        Show-PutterError 'No PuTTY launcher is configured. Open Options -> Settings and select a launcher.' 'Putter - Launcher not configured'
        return
    }

    if (-not (Test-Path -LiteralPath $launcher -PathType Leaf)) {
        Show-PutterError ("PuTTY launcher not found:" + [Environment]::NewLine + [Environment]::NewLine + $launcher) 'Putter - Launcher not found'
        return
    }

    $delay = [Math]::Max(0, [int]$Config.LaunchDelayMilliseconds)
    $launched = 0

    foreach ($sessionName in $names) {
        $quotedSessionName = '"' + $sessionName.Replace('"', '\"') + '"'
        $arguments = '-load ' + $quotedSessionName

        try {
            Start-Process -FilePath $launcher -ArgumentList $arguments -ErrorAction Stop
            $launched++
        }
        catch {
            Show-PutterError ("Failed to start session '$sessionName'." +
                [Environment]::NewLine + [Environment]::NewLine +
                $_.Exception.Message) 'Putter - Launch failed'
            return
        }

        if ($launched -lt $names.Count -and $delay -gt 0) {
            Start-Sleep -Milliseconds $delay
        }
    }

    $statusLabel.Text = "Started sessions: $launched"
}

function Start-PutterSessionRows {
    param([System.Windows.Forms.DataGridViewRow[]]$Rows)

    $selectedRows = @($Rows | Sort-Object Index)
    $sessionNames = @(
        $selectedRows | ForEach-Object {
            [string]$_.Cells['Session'].Value
        }
    )

    Start-PutterSessionNames -SessionNames $sessionNames
}

function Start-PutterSessions {
    Start-PutterSessionRows -Rows @($grid.SelectedRows)
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
        $sectionLines = @($lines | Where-Object {
            $trimmed = $_.Trim()
            $trimmed.StartsWith('[') -and $trimmed.EndsWith(']')
        })

        if ($sectionLines.Count -eq 0) {
            throw 'The selected file does not contain any registry sections.'
        }

        $allowedPrefix = 'HKEY_CURRENT_USER\Software\SimonTatham\PuTTY\Sessions'

        foreach ($line in $sectionLines) {
            $path = $line.Trim().TrimStart('[').TrimEnd(']')

            if ($path.StartsWith('-')) {
                $path = $path.Substring(1)
            }

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

        & reg.exe import $dialog.FileName 2>&1 | Out-Null

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
    $dlg.Height = 555
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

    $rememberWindowCheck = New-Object System.Windows.Forms.CheckBox
    $rememberWindowCheck.Text = 'Remember window position and size'
    $rememberWindowCheck.Left = 15
    $rememberWindowCheck.Top = 155
    $rememberWindowCheck.Width = 300
    $rememberWindowCheck.Checked = [bool]$Config.RememberWindowGeometry

    $nightModeCheck = New-Object System.Windows.Forms.CheckBox
    $nightModeCheck.Text = 'Night mode'
    $nightModeCheck.Left = 15
    $nightModeCheck.Top = 185
    $nightModeCheck.Width = 300
    $nightModeCheck.Checked = [bool]$Config.NightMode

    $fontSizeLabel = New-Object System.Windows.Forms.Label
    $fontSizeLabel.Text = 'Grid font size:'
    $fontSizeLabel.Left = 15
    $fontSizeLabel.Top = 218
    $fontSizeLabel.AutoSize = $true

    $fontSizeBox = New-Object System.Windows.Forms.NumericUpDown
    $fontSizeBox.Left = 110
    $fontSizeBox.Top = 214
    $fontSizeBox.Width = 70
    $fontSizeBox.Minimum = 7
    $fontSizeBox.Maximum = 24
    $fontSizeBox.Value = [decimal]$Config.GridFontSize

    $fontBoldCheck = New-Object System.Windows.Forms.CheckBox
    $fontBoldCheck.Text = 'Bold'
    $fontBoldCheck.Left = 205
    $fontBoldCheck.Top = 216
    $fontBoldCheck.Width = 80
    $fontBoldCheck.Checked = [bool]$Config.GridFontBold

    $launcherLabel = New-Object System.Windows.Forms.Label
    $launcherLabel.Text = 'PuTTY launcher:'
    $launcherLabel.Left = 15
    $launcherLabel.Top = 260
    $launcherLabel.AutoSize = $true

    $launcherBox = New-Object System.Windows.Forms.TextBox
    $launcherBox.Left = 15
    $launcherBox.Top = 280
    $launcherBox.Width = 500
    $launcherBox.Text = [string]$Config.PuttyLauncher
    $launcherBox.ShortcutsEnabled = $true

    $launcherBrowseButton = New-Object System.Windows.Forms.Button
    $launcherBrowseButton.Text = 'Browse...'
    $launcherBrowseButton.Left = 525
    $launcherBrowseButton.Top = 278
    $launcherBrowseButton.Width = 90

    $delayLabel = New-Object System.Windows.Forms.Label
    $delayLabel.Text = 'Delay between sessions (seconds):'
    $delayLabel.Left = 15
    $delayLabel.Top = 320
    $delayLabel.AutoSize = $true

    $delayBox = New-Object System.Windows.Forms.NumericUpDown
    $delayBox.Left = 220
    $delayBox.Top = 317
    $delayBox.Width = 90
    $delayBox.DecimalPlaces = 1
    $delayBox.Increment = [decimal]0.1
    $delayBox.Minimum = [decimal]0
    $delayBox.Maximum = [decimal]60
    $delayBox.Value = [decimal]([Math]::Min(60000, [Math]::Max(0, [int]$Config.LaunchDelayMilliseconds))) / 1000

    $closeToTrayCheck = New-Object System.Windows.Forms.CheckBox
    $closeToTrayCheck.Text = 'Close Putter to tray'
    $closeToTrayCheck.Left = 15
    $closeToTrayCheck.Top = 355
    $closeToTrayCheck.Width = 300
    $closeToTrayCheck.Checked = [bool]$Config.CloseToTray

    $minimizeToTrayCheck = New-Object System.Windows.Forms.CheckBox
    $minimizeToTrayCheck.Text = 'Minimize Putter to tray'
    $minimizeToTrayCheck.Left = 15
    $minimizeToTrayCheck.Top = 385
    $minimizeToTrayCheck.Width = 300
    $minimizeToTrayCheck.Checked = [bool]$Config.MinimizeToTray

    $okButton = New-Object System.Windows.Forms.Button
    $okButton.Text = 'OK'
    $okButton.Left = 430
    $okButton.Top = 445
    $okButton.Width = 85

    $cancelButton = New-Object System.Windows.Forms.Button
    $cancelButton.Text = 'Cancel'
    $cancelButton.Left = 525
    $cancelButton.Top = 445
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

    $launcherBrowseButton.Add_Click({
        $launcherDialog = New-Object System.Windows.Forms.OpenFileDialog
        $launcherDialog.Title = 'Select PuTTY launcher'
        $launcherDialog.Filter = 'Launchers (*.exe;*.lnk;*.bat;*.cmd)|*.exe;*.lnk;*.bat;*.cmd|All files (*.*)|*.*'
        $launcherDialog.Multiselect = $false

        if (-not [string]::IsNullOrWhiteSpace($launcherBox.Text)) {
            try {
                $existingDirectory = Split-Path -Parent $launcherBox.Text

                if (Test-Path -LiteralPath $existingDirectory -PathType Container) {
                    $launcherDialog.InitialDirectory = $existingDirectory
                }
            }
            catch {
            }
        }

        if ($launcherDialog.ShowDialog($dlg) -eq [System.Windows.Forms.DialogResult]::OK) {
            $launcherBox.Text = $launcherDialog.FileName
        }
    })

    $okButton.Add_Click({
        if ($backupCheck.Checked -and [string]::IsNullOrWhiteSpace($folderBox.Text)) {
            Show-PutterError 'Backup folder cannot be empty while automatic backups are enabled.'
            return
        }

        $Config.CreateBackups = $backupCheck.Checked
        $Config.BackupDirectory = $folderBox.Text
        $Config.RememberWindowGeometry = $rememberWindowCheck.Checked
        $Config.NightMode = $nightModeCheck.Checked
        $Config.GridFontSize = [int]$fontSizeBox.Value
        $Config.GridFontBold = $fontBoldCheck.Checked
        $Config.PuttyLauncher = $launcherBox.Text.Trim()
        $Config.LaunchDelayMilliseconds = [int]([decimal]$delayBox.Value * 1000)
        $Config.CloseToTray = $closeToTrayCheck.Checked
        $Config.MinimizeToTray = $minimizeToTrayCheck.Checked
        Save-PutterConfig
        Apply-PutterMainTheme

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
    $dlg.Controls.Add($rememberWindowCheck)
    $dlg.Controls.Add($nightModeCheck)
    $dlg.Controls.Add($fontSizeLabel)
    $dlg.Controls.Add($fontSizeBox)
    $dlg.Controls.Add($fontBoldCheck)
    $dlg.Controls.Add($launcherLabel)
    $dlg.Controls.Add($launcherBox)
    $dlg.Controls.Add($launcherBrowseButton)
    $dlg.Controls.Add($delayLabel)
    $dlg.Controls.Add($delayBox)
    $dlg.Controls.Add($closeToTrayCheck)
    $dlg.Controls.Add($minimizeToTrayCheck)
    $dlg.Controls.Add($okButton)
    $dlg.Controls.Add($cancelButton)
    $dlg.AcceptButton = $okButton
    $dlg.CancelButton = $cancelButton

    Apply-PutterTheme -Control $dlg
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
        "PowerShell: $($PSVersionTable.PSVersion) ($($PSVersionTable.PSEdition))" +
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

    Apply-PutterTheme -Control $dlg
    [void]$dlg.ShowDialog($form)
}

# ============================================================
# Tray
# ============================================================

$script:ExitRequested = $false

function Show-PutterMainWindow {
    $form.ShowInTaskbar = $true
    $form.Show()

    if ($form.WindowState -eq [System.Windows.Forms.FormWindowState]::Minimized) {
        $form.WindowState = [System.Windows.Forms.FormWindowState]::Normal
    }

    $form.Activate()
}

function Hide-PutterToTray {
    $form.ShowInTaskbar = $false
    $form.Hide()
}

function Show-PutterTraySessions {
    $dlg = New-Object System.Windows.Forms.Form
    $dlg.Text = 'Putter - Sessions'
    $dlg.Width = 420
    $dlg.Height = 520
    $dlg.StartPosition = 'CenterScreen'
    $dlg.FormBorderStyle = 'SizableToolWindow'
    $dlg.MinimizeBox = $false
    $dlg.MaximizeBox = $false
    $dlg.Icon = $form.Icon

    $sessionList = New-Object System.Windows.Forms.ListBox
    $sessionList.Left = 10
    $sessionList.Top = 10
    $sessionList.Width = 385
    $sessionList.Height = 420
    $sessionList.Anchor = 'Top,Bottom,Left,Right'
    $sessionList.SelectionMode = [System.Windows.Forms.SelectionMode]::One
    $sessionList.IntegralHeight = $false

    foreach ($row in @($table.Select('', 'Session ASC'))) {
        [void]$sessionList.Items.Add([string]$row.Session)
    }

    $openButton = New-Object System.Windows.Forms.Button
    $openButton.Text = 'Open'
    $openButton.Left = 215
    $openButton.Top = 440
    $openButton.Width = 85
    $openButton.Height = 30
    $openButton.Anchor = 'Bottom,Right'

    $closeButton = New-Object System.Windows.Forms.Button
    $closeButton.Text = 'Close'
    $closeButton.Left = 310
    $closeButton.Top = 440
    $closeButton.Width = 85
    $closeButton.Height = 30
    $closeButton.Anchor = 'Bottom,Right'

    $openSelectedSession = {
        if ($sessionList.SelectedIndex -lt 0) {
            return
        }

        Start-PutterSessionNames -SessionNames @([string]$sessionList.SelectedItem)
    }

    $openButton.Add_Click($openSelectedSession)
    $sessionList.Add_DoubleClick($openSelectedSession)

    $sessionList.Add_KeyDown({
        param($sender, $e)

        if ($e.KeyCode -eq [System.Windows.Forms.Keys]::Enter) {
            & $openSelectedSession
            $e.Handled = $true
            $e.SuppressKeyPress = $true
        }
        elseif ($e.KeyCode -eq [System.Windows.Forms.Keys]::Escape) {
            $dlg.Close()
            $e.Handled = $true
            $e.SuppressKeyPress = $true
        }
    })

    $closeButton.Add_Click({
        $dlg.Close()
    })

    $dlg.Controls.Add($sessionList)
    $dlg.Controls.Add($openButton)
    $dlg.Controls.Add($closeButton)
    $dlg.AcceptButton = $openButton
    $dlg.CancelButton = $closeButton

    Apply-PutterTheme -Control $dlg

    if ($sessionList.Items.Count -gt 0) {
        $sessionList.SelectedIndex = 0
    }

    [void]$dlg.ShowDialog()
}

$trayMenu = New-Object System.Windows.Forms.ContextMenuStrip

$trayShowItem = New-Object System.Windows.Forms.ToolStripMenuItem
$trayShowItem.Text = 'Show Putter'
$trayShowItem.Add_Click({
    Show-PutterMainWindow
})

$traySessionsItem = New-Object System.Windows.Forms.ToolStripMenuItem
$traySessionsItem.Text = 'Sessions...'
$traySessionsItem.Add_Click({
    Show-PutterTraySessions
})

$traySeparator = New-Object System.Windows.Forms.ToolStripSeparator

$trayExitItem = New-Object System.Windows.Forms.ToolStripMenuItem
$trayExitItem.Text = 'Exit'
$trayExitItem.Add_Click({
    $script:ExitRequested = $true
    $form.Close()
})

[void]$trayMenu.Items.Add($trayShowItem)
[void]$trayMenu.Items.Add($traySessionsItem)
[void]$trayMenu.Items.Add($traySeparator)
[void]$trayMenu.Items.Add($trayExitItem)

$trayIcon = New-Object System.Windows.Forms.NotifyIcon
$trayIcon.Icon = $form.Icon
$trayIcon.Text = 'Putter'
$trayIcon.ContextMenuStrip = $trayMenu
$trayIcon.Visible = $true

$trayIcon.Add_DoubleClick({
    Show-PutterMainWindow
})

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

$aboutMenu = New-Object System.Windows.Forms.ToolStripMenuItem
$aboutMenu.Text = 'About'
$aboutMenu.Add_Click({
    Show-AboutDialog
})

[void]$menuStrip.Items.Add($fileMenu)
[void]$menuStrip.Items.Add($optionsMenu)
[void]$menuStrip.Items.Add($aboutMenu)

$fileMenu.Add_DropDownOpening({
    $exportSelectedFileItem.Enabled = ($grid.SelectedRows.Count -gt 0)
})

# ============================================================
# Context menu
# ============================================================

$contextMenu = New-Object System.Windows.Forms.ContextMenuStrip

$openSelectedItem = New-Object System.Windows.Forms.ToolStripMenuItem
$openSelectedItem.Text = 'Open session'

$openSeparator = New-Object System.Windows.Forms.ToolStripSeparator

$multiEditItem = New-Object System.Windows.Forms.ToolStripMenuItem
$multiEditItem.Text = 'Multi-edit selected...'

$copySessionItem = New-Object System.Windows.Forms.ToolStripMenuItem
$copySessionItem.Text = 'Copy session...'

$exportSelectedItem = New-Object System.Windows.Forms.ToolStripMenuItem
$exportSelectedItem.Text = 'Export selected sessions...'

$separator = New-Object System.Windows.Forms.ToolStripSeparator

$deleteCurrentItem = New-Object System.Windows.Forms.ToolStripMenuItem
$deleteCurrentItem.Text = 'Delete this session...'

$deleteSelectedItem = New-Object System.Windows.Forms.ToolStripMenuItem
$deleteSelectedItem.Text = 'Delete selected...'

[void]$contextMenu.Items.Add($openSelectedItem)
[void]$contextMenu.Items.Add($openSeparator)
[void]$contextMenu.Items.Add($multiEditItem)
[void]$contextMenu.Items.Add($copySessionItem)
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

    $openSelectedItem.Text = if ($count -eq 1) { 'Open session' } else { "Open selected sessions ($count)" }
    $multiEditItem.Text = "Multi-edit selected ($count)..."
    $copySessionItem.Text = 'Copy session...'
    $exportSelectedItem.Text = "Export selected sessions ($count)..."
    $deleteSelectedItem.Text = "Delete selected ($count)..."

    $openSelectedItem.Enabled = ($count -gt 0)
    $multiEditItem.Enabled = ($count -gt 0)
    $copySessionItem.Enabled = ($count -eq 1)
    $exportSelectedItem.Enabled = ($count -gt 0)
    $deleteSelectedItem.Enabled = ($count -gt 0)
    $deleteCurrentItem.Enabled = ($null -ne $script:ContextRow)
})

$openSelectedItem.Add_Click({
    Start-PutterSessions
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

$copySessionItem.Add_Click({
    $rows = @($grid.SelectedRows)

    if ($rows.Count -eq 1) {
        Copy-PutterSession -Row $rows[0]
    }
})

$exportSelectedItem.Add_Click({
    Export-SelectedSessions
})

$grid.add_SessionLaunchRequested({
    Start-PutterSessions
})

# Delete deletes the selected session(s) when the grid is not in inline edit mode.
$grid.Add_KeyDown({
    param($sender, $e)

    if ($grid.IsCurrentCellInEditMode) {
        return
    }

    if ($e.KeyCode -eq [System.Windows.Forms.Keys]::Delete -and
        $e.Modifiers -eq [System.Windows.Forms.Keys]::None) {
        $rows = @($grid.SelectedRows)

        if ($rows.Count -gt 0) {
            $e.Handled = $true
            $e.SuppressKeyPress = $true
            Remove-PutterSessions -Rows $rows
        }
    }
})

# ============================================================
# Run
# ============================================================

$form.MainMenuStrip = $menuStrip
$form.Controls.Add($menuStrip)
$form.Controls.Add($filterLabel)
$form.Controls.Add($filterBox)
$form.Controls.Add($clearFilterButton)
$form.Controls.Add($grid)
$form.Controls.Add($refreshButton)
$form.Controls.Add($openButtonMain)
$form.Controls.Add($renameButton)
$form.Controls.Add($copyButtonMain)
$form.Controls.Add($deleteButtonMain)
$form.Controls.Add($statusLabel)

# Restore only after anchored controls exist, so they resize with the form immediately.
Restore-PutterWindowGeometry -Form $form
Apply-PutterMainTheme
Update-Status
Restore-PutterSort

$form.Add_Shown({
    [void]$form.BeginInvoke([System.Action]{
        Restore-PutterColumnOrder
        Restore-PutterColumnWidths
    })
})

$form.Add_Resize({
    if ($form.WindowState -eq [System.Windows.Forms.FormWindowState]::Minimized -and
        $Config.MinimizeToTray) {
        Hide-PutterToTray
    }
})

$form.Add_FormClosing({
    param($sender, $e)

    if (-not $script:ExitRequested -and
        $Config.CloseToTray -and
        $e.CloseReason -eq [System.Windows.Forms.CloseReason]::UserClosing) {
        $e.Cancel = $true
        Hide-PutterToTray
        return
    }

    $filterHistoryTimer.Stop()
    Add-PutterFilterHistoryEntry -Text $filterBox.Text
    Save-PutterColumnWidths
    Save-PutterColumnOrder
    Save-PutterSort
    Save-PutterWindowGeometry -Form $form

    $trayIcon.Visible = $false
    $trayIcon.Dispose()
    $trayMenu.Dispose()
})

try {
    [System.Windows.Forms.Application]::Run($form)
}
finally {
    if ($null -ne $trayIcon) {
        $trayIcon.Visible = $false
        $trayIcon.Dispose()
    }

    if ($null -ne $trayMenu) {
        $trayMenu.Dispose()
    }
}
