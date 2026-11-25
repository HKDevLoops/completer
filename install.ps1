# ============================================================================
# install.ps1 - simple iwr-style linker for the PowerShell completer functions.
# Usage (remote):  $env:COMPLETER_RAW_BASE='https://<RAW-BASE>'
#                  iwr "$env:COMPLETER_RAW_BASE/install.ps1" | iex
#                  (irm ... | iex is equivalent on Windows PowerShell 5.1)
# Usage (local):   . .\install.ps1        (from this folder)
# Detects OS + main profile, asks permission, backs up old completer.ps1,
# writes the new one, and adds ONE guarded source line to the main profile.
#
# SECURITY (PowerShell equivalent of curl's --proto restriction): piping an
# unknown remote response straight into iex executes arbitrary code with YOUR
# privileges. Prefer `irm -Uri <trusted-https-url>` (Invoke-RestMethod) to fetch
# and inspect the payload first, use only trusted HTTPS URLs, and set
# $env:COMPLETER_SHA256 to the expected SHA-256 of completer.ps1 so the
# downloaded file is verified before it is written to disk and later
# dot-sourced from your profile. Unset it to skip the check. Files written by
# this installer get a restrictive ACL on Windows where the native APIs allow.
# Native PowerShell APIs only: Invoke-WebRequest, Get-FileHash, Copy-Item,
# Add-Content, Get-Date, Test-Path, Read-Host, Get-Content, New-Item,
# Get-Acl, Set-Acl.
# ============================================================================

$ErrorActionPreference = 'Stop'

# Raw base used to fetch completer.ps1 when not running from a local folder.
$RawBase = $env:COMPLETER_RAW_BASE
if (-not $RawBase) { $RawBase = 'https://<RAW-BASE>' }

$InstallRoot = $PSScriptRoot
if (-not $InstallRoot -and $MyInvocation.MyCommand.Path) {
    $InstallRoot = Split-Path -Parent $MyInvocation.MyCommand.Path
}
if (-not $InstallRoot) { $InstallRoot = (Get-Location).Path }

function Get-MainProfile {
    $candidates = @(
        $PROFILE.CurrentUserCurrentHost,
        $PROFILE.CurrentUserAllHosts,
        (Join-Path $HOME 'OneDrive\Documents\PowerShell\Microsoft.PowerShell_profile.ps1'),
        (Join-Path $HOME 'Documents\PowerShell\Microsoft.PowerShell_profile.ps1'),
        (Join-Path $HOME 'Documents\WindowsPowerShell\Microsoft.PowerShell_profile.ps1')
    )
    foreach ($c in $candidates) {
        if ($c -and (Test-Path -LiteralPath $c)) { return $c }
    }
    return $PROFILE.CurrentUserCurrentHost
}

function Backup-InstallFile {
    param([string]$Path)
    if (Test-Path -LiteralPath $Path) {
        $stamp = Get-Date -Format 'yyyyMMdd-HHmmss'
        Copy-Item -LiteralPath $Path -Destination "$Path.bak.$stamp" -Force
        Write-Host "  backup -> $Path.bak.$stamp" -ForegroundColor DarkGray
    }
}

function Set-CompleterRestrictiveAcl {
    param([string]$Path)
    if (-not $Path -or -not (Test-Path -LiteralPath $Path)) { return }
    # Native Windows ACLs only; silently skip on other platforms.
    if ($env:OS -ne 'Windows_NT' -and [System.Environment]::OSVersion.Platform -ne [System.PlatformID]::Win32NT) { return }
    try {
        $acl = Get-Acl -LiteralPath $Path
        # Drop inherited rules, then remove explicit ones before granting a
        # minimal set: current user, SYSTEM and Administrators only.
        $acl.SetAccessRuleProtection($true, $false)
        foreach ($rule in @($acl.Access)) { $acl.RemoveAccessRule($rule) | Out-Null }
        $sids = @(
            [System.Security.Principal.WindowsIdentity]::GetCurrent().User,
            (New-Object System.Security.Principal.SecurityIdentifier('S-1-5-18')),    # SYSTEM
            (New-Object System.Security.Principal.SecurityIdentifier('S-1-5-32-544')) # Administrators
        )
        foreach ($sid in $sids) {
            $rule = New-Object System.Security.AccessControl.FileSystemAccessRule($sid, 'FullControl', 'None', 'None', 'Allow')
            $acl.AddAccessRule($rule)
        }
        Set-Acl -LiteralPath $Path -AclObject $acl
        Write-Host "  restricted ACL -> $Path" -ForegroundColor DarkGray
    } catch {
        # Never break the simple install UX if ACL APIs are restricted.
        Write-Warning "Could not restrict ACL on '$Path': $_"
    }
}

$os = if ($env:OS) { $env:OS } else { [System.Environment]::OSVersion.Platform }
$main = Get-MainProfile
$target = Join-Path (Split-Path -Parent $main) 'completer.ps1'
$markerStart = '# >>> completer:install >>>'
$markerEnd   = '# <<< completer:install <<<'

Write-Host 'completer installer' -ForegroundColor Cyan
Write-Host "  OS            : $os"
Write-Host "  PowerShell    : $($PSVersionTable.PSVersion)"
Write-Host "  Main config   : $main"
Write-Host "  Function file : $target"

$answer = $env:COMPLETER_YES
if (-not $answer) { $answer = Read-Host 'Add the completer function here and link it? [y/N]' }
if ($answer -notmatch '^(y|yes|1)$') { Write-Host 'Aborted.' -ForegroundColor Yellow; return }

# Obtain the function file: local folder first, iwr download second.
$source = Join-Path $InstallRoot 'completer.ps1'
$downloaded = $false
if (-not (Test-Path -LiteralPath $source)) {
    $url = "$RawBase/completer.ps1"
    Write-Host "  Fetching $url ..." -ForegroundColor DarkGray
    Invoke-WebRequest -Uri $url -OutFile $source -UseBasicParsing
    $downloaded = $true
}
if (-not (Test-Path -LiteralPath $source)) {
    throw "Cannot locate completer.ps1 (looked in '$InstallRoot' and '$RawBase')."
}

# Optional integrity gate: verify the downloaded function file before it is
# written to its final location and later dot-sourced from the profile.
$expectedHash = $env:COMPLETER_SHA256
if ($expectedHash) {
    $actualHash = (Get-FileHash -LiteralPath $source -Algorithm SHA256).Hash
    if ($actualHash -ne $expectedHash.Trim()) {
        throw "SHA256 mismatch for completer.ps1: expected '$expectedHash', got '$actualHash'. Set the correct `$env:COMPLETER_SHA256 or unset it to skip verification."
    }
    Write-Host "  SHA256 verified: $actualHash" -ForegroundColor Green
}

# Back up + write the function file.
Backup-InstallFile -Path $target
Copy-Item -LiteralPath $source -Destination $target -Force
Set-CompleterRestrictiveAcl -Path $target
if ($downloaded) { Set-CompleterRestrictiveAcl -Path $source }
Write-Host "  wrote -> $target" -ForegroundColor Green

# Ensure the main profile exists before appending.
$mainDir = Split-Path -Parent $main
if ($mainDir -and -not (Test-Path -LiteralPath $mainDir)) {
    New-Item -ItemType Directory -Path $mainDir -Force | Out-Null
}
if (-not (Test-Path -LiteralPath $main)) {
    New-Item -ItemType File -Path $main -Force | Out-Null
}

# Add ONE guarded source line to the main profile.
$content = Get-Content -LiteralPath $main -Raw
if (-not $content) { $content = '' }
if ($content -notmatch [regex]::Escape($markerStart)) {
    Backup-InstallFile -Path $main
    $quoted = $target -replace "'", "''"
    $block = (@(
        '',
        $markerStart,
        "# Generated by completer installer. Edit with 'completer alias ...'.",
        ". '$quoted'",
        $markerEnd,
        ''
    ) -join [Environment]::NewLine)
    Add-Content -LiteralPath $main -Value $block -Encoding UTF8
    Write-Host '  linked from main config.' -ForegroundColor Green
}
else {
    Write-Host '  already linked (marker present); nothing to do.' -ForegroundColor Green
}
Write-Host "Done. Restart the shell and run 'completer pwsh'." -ForegroundColor Cyan
