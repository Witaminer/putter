# ============================================================
# Putter Builder
# Builds Putter.exe from Putter.ps1 using ps2exe.
# ============================================================

$PreferredPs2ExeVersion = '1.0.18'

$source = Join-Path $PSScriptRoot 'Putter.ps1'
$output = Join-Path $PSScriptRoot 'Putter.exe'

Write-Host
Write-Host '============================================================' -ForegroundColor Cyan
Write-Host '                       Putter Builder' -ForegroundColor Cyan
Write-Host '============================================================' -ForegroundColor Cyan
Write-Host

Write-Host 'Source : ' -NoNewline
Write-Host $source -ForegroundColor White

Write-Host 'Output : ' -NoNewline
Write-Host $output -ForegroundColor White

Write-Host 'Engine : ' -NoNewline
Write-Host "PowerShell $($PSVersionTable.PSVersion) ($($PSVersionTable.PSEdition))" -ForegroundColor White

Write-Host
Write-Host 'Checking source file...' -ForegroundColor Yellow

if (-not (Test-Path -LiteralPath $source -PathType Leaf)) {
    Write-Host
    Write-Host 'ERROR: Putter.ps1 was not found.' -ForegroundColor Red
    Write-Host 'Expected source file:' -ForegroundColor Red
    Write-Host $source -ForegroundColor White
    Write-Host
    exit 1
}

Write-Host 'Putter.ps1 found.' -ForegroundColor Green

Write-Host
Write-Host 'Checking for ps2exe...' -ForegroundColor Yellow

$ps2exeCommand = Get-Command Invoke-ps2exe -ErrorAction SilentlyContinue

if ($null -eq $ps2exeCommand) {
    Write-Host
    Write-Host 'ps2exe was not found.' -ForegroundColor Yellow
    Write-Host

    $answer = Read-Host "Install ps2exe $PreferredPs2ExeVersion from PowerShell Gallery? [Y/N]"

    if ($answer -notmatch '^[Yy]$') {
        Write-Host
        Write-Host 'Build cancelled.' -ForegroundColor Yellow
        Write-Host
        exit 1
    }

    Write-Host
    Write-Host "Installing ps2exe $PreferredPs2ExeVersion..." -ForegroundColor Yellow

    try {
        Install-Module ps2exe `
            -RequiredVersion $PreferredPs2ExeVersion `
            -Scope CurrentUser `
            -Force `
            -ErrorAction Stop
    }
    catch {
        Write-Host
        Write-Host 'ERROR: ps2exe installation failed.' -ForegroundColor Red
        Write-Host $_.Exception.Message -ForegroundColor Red
        Write-Host
        exit 1
    }

    Write-Host 'ps2exe installed successfully.' -ForegroundColor Green
}

Write-Host
Write-Host 'Loading ps2exe...' -ForegroundColor Yellow

try {
    Import-Module ps2exe -Force -ErrorAction Stop
}
catch {
    Write-Host
    Write-Host 'ERROR: Could not load ps2exe.' -ForegroundColor Red
    Write-Host $_.Exception.Message -ForegroundColor Red
    Write-Host
    exit 1
}

$ps2exeModule = Get-Module ps2exe |
    Sort-Object Version -Descending |
    Select-Object -First 1

if ($null -ne $ps2exeModule) {
    Write-Host "Found ps2exe $($ps2exeModule.Version)." -ForegroundColor Green
}
else {
    Write-Host 'Found Invoke-ps2exe.' -ForegroundColor Green
}

if (Test-Path -LiteralPath $output -PathType Leaf) {
    Write-Host
    Write-Host 'Existing Putter.exe found.' -ForegroundColor Yellow
    Write-Host

    $answer = Read-Host 'Replace the existing Putter.exe? [Y/N]'

    if ($answer -notmatch '^[Yy]$') {
        Write-Host
        Write-Host 'Build cancelled.' -ForegroundColor Yellow
        Write-Host
        exit 1
    }

    Write-Host
    Write-Host 'Removing old executable...'

    try {
        Remove-Item -LiteralPath $output -Force -ErrorAction Stop
    }
    catch {
        Write-Host
        Write-Host 'ERROR: Could not remove the existing Putter.exe.' -ForegroundColor Red
        Write-Host $_.Exception.Message -ForegroundColor Red
        Write-Host
        exit 1
    }

    Write-Host 'Old executable removed.' -ForegroundColor Green
}

Write-Host
Write-Host 'Building Putter.exe...' -ForegroundColor Cyan
Write-Host
Write-Host 'Command:' -ForegroundColor DarkGray
Write-Host "Invoke-ps2exe `"$source`" `"$output`" -noConsole" -ForegroundColor DarkGray
Write-Host

try {
    Invoke-ps2exe $source $output -noConsole
}
catch {
    Write-Host
    Write-Host 'ERROR: Build failed.' -ForegroundColor Red
    Write-Host $_.Exception.Message -ForegroundColor Red
    Write-Host
    exit 1
}

if (-not (Test-Path -LiteralPath $output -PathType Leaf)) {
    Write-Host
    Write-Host 'ERROR: Build finished without creating Putter.exe.' -ForegroundColor Red
    Write-Host
    exit 1
}

$file = Get-Item -LiteralPath $output
$hash = Get-FileHash -LiteralPath $output -Algorithm SHA256

Write-Host
Write-Host '============================================================' -ForegroundColor Green
Write-Host '                     BUILD SUCCESSFUL' -ForegroundColor Green
Write-Host '============================================================' -ForegroundColor Green
Write-Host

Write-Host 'File    : ' -NoNewline
Write-Host $file.FullName -ForegroundColor White

Write-Host 'Size    : ' -NoNewline
Write-Host ("{0:N0} bytes" -f $file.Length) -ForegroundColor White

Write-Host 'SHA-256 : ' -NoNewline
Write-Host $hash.Hash.ToLowerInvariant() -ForegroundColor White

Write-Host