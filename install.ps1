<#
.SYNOPSIS
    Installs a YOLO-mode desktop launcher for Claude Code.

.DESCRIPTION
    Resolves claude.exe to a real, non-virtualized path under ~\.local\bin and
    generates the desktop shortcut from scratch. Nothing is hardcoded to one machine.

    Run this from a NORMAL PowerShell window, not from a terminal inside the Claude
    desktop app -- see the container note below and in README.md.

.PARAMETER SkipPathUpdate
    Do not add ~\.local\bin to the user PATH.

.PARAMETER Force
    Overwrite an existing claude.exe in ~\.local\bin instead of keeping it.
#>
[CmdletBinding()]
param(
    [switch]$SkipPathUpdate,
    [switch]$Force
)

$ErrorActionPreference = 'Stop'

$BinDir  = Join-Path $env:USERPROFILE '.local\bin'
$Desktop = [Environment]::GetFolderPath('Desktop')

function Write-Step($m) { Write-Host "==> $m" -ForegroundColor Cyan }
function Write-Ok($m)   { Write-Host "    [OK] $m" -ForegroundColor Green }
function Write-Warn($m) { Write-Host "    [!]  $m" -ForegroundColor Yellow }
function Write-Err($m)  { Write-Host "    [x]  $m" -ForegroundColor Red }

# --------------------------------------------------------------------------
# MSIX container detection
#
# The Claude desktop app runs in an MSIX container. Writes to %APPDATA% from
# inside it are silently redirected to
#   %LOCALAPPDATA%\Packages\<pkg>\LocalCache\Roaming\
# so anything npm-installed there is invisible to Explorer, Task Scheduler, and
# ordinary terminals. That is what breaks naively-created shortcuts.
# --------------------------------------------------------------------------
function Test-InAppContainer {
    $marker = Join-Path $env:APPDATA ".yolo-claude-probe-$PID"
    try { Set-Content -LiteralPath $marker -Value 'probe' -ErrorAction Stop } catch { return $false }
    try {
        $hit = Get-ChildItem (Join-Path $env:LOCALAPPDATA 'Packages') -Directory -ErrorAction SilentlyContinue |
            ForEach-Object { Join-Path $_.FullName "LocalCache\Roaming\.yolo-claude-probe-$PID" } |
            Where-Object { Test-Path -LiteralPath $_ } |
            Select-Object -First 1
        return [bool]$hit
    } finally {
        Remove-Item -LiteralPath $marker -Force -ErrorAction SilentlyContinue
    }
}

# A path is "virtualized" if it lives under a package's LocalCache, or resolves
# there through a junction (e.g. the nvm4w -> AppData\Roaming\npm trick).
function Test-VirtualizedPath([string]$Path) {
    if (-not $Path) { return $false }
    if ($Path -like '*\Packages\*\LocalCache\*') { return $true }
    $probe = $Path
    for ($i = 0; $i -lt 12 -and $probe; $i++) {
        $item = Get-Item -LiteralPath $probe -Force -ErrorAction SilentlyContinue
        if ($item -and $item.Target) {
            $t = @($item.Target)[0]
            if ($t -like '*\Packages\*\LocalCache\*') { return $true }
        }
        $parent = Split-Path -Parent $probe
        if ($parent -eq $probe) { break }
        $probe = $parent
    }
    return $false
}

function Find-RealClaudeExe {
    $where = & where.exe claude.exe 2>$null
    if ($LASTEXITCODE -eq 0 -and $where) {
        foreach ($p in $where) {
            if ((Test-Path -LiteralPath $p) -and -not (Test-VirtualizedPath $p)) { return $p }
        }
    }
    return $null
}

# Find a copy stashed inside an MSIX container, so we can reuse the ~340 MB that
# is already on disk instead of re-downloading it.
function Find-ContainerClaude {
    $glob = Join-Path $env:LOCALAPPDATA 'Packages\*\LocalCache\Roaming\npm\node_modules\@anthropic-ai\claude-code\bin\claude.exe'
    Get-ChildItem -Path $glob -ErrorAction SilentlyContinue |
        Sort-Object LastWriteTime -Descending |
        Select-Object -First 1 -ExpandProperty FullName
}

# --------------------------------------------------------------------------

Write-Host ''
Write-Host 'yolo-claude installer' -ForegroundColor White
Write-Host '---------------------'

$inContainer = Test-InAppContainer
if ($inContainer) {
    Write-Warn 'Running inside an MSIX app container (e.g. a terminal in the Claude desktop app).'
    Write-Warn 'The shortcut will still be created, but PATH changes will not persist outside it.'
    Write-Warn 'For a clean install, re-run this from a normal PowerShell window.'
    Write-Host ''
}

Write-Step "Preparing $BinDir"
New-Item -ItemType Directory -Path $BinDir -Force | Out-Null
Write-Ok $BinDir

Write-Step 'Locating claude.exe'
$claude   = $null
$existing = Join-Path $BinDir 'claude.exe'

if ((Test-Path -LiteralPath $existing) -and -not $Force) {
    $claude = $existing
    Write-Ok "already installed: $claude"
} else {
    $onPath = Find-RealClaudeExe
    if ($onPath) {
        $claude = $onPath
        Write-Ok "found on PATH: $claude"
    } else {
        $stashed = Find-ContainerClaude
        if ($stashed) {
            Write-Host '    copying the container copy (no download needed)...' -ForegroundColor DarkGray
            Copy-Item -LiteralPath $stashed -Destination $existing -Force
            $claude = $existing
            Write-Ok "copied to $claude"
        } else {
            Write-Host '    not found; running the official native installer...' -ForegroundColor DarkGray
            try {
                Invoke-RestMethod https://claude.ai/install.ps1 | Invoke-Expression
            } catch {
                Write-Err "installer failed: $($_.Exception.Message)"
            }
            if (Test-Path -LiteralPath $existing) {
                $claude = $existing
                Write-Ok "installed to $claude"
            }
        }
    }
}

if (-not $claude) {
    Write-Err 'Could not resolve claude.exe. Install it with: irm https://claude.ai/install.ps1 | iex'
    exit 1
}

$ver = & $claude --version 2>&1
if ($LASTEXITCODE -ne 0) {
    Write-Err "claude.exe found but did not run: $ver"
    exit 1
}
Write-Ok "verified: $ver"

Write-Step "Creating shortcut on $Desktop"
$lnk = Join-Path $Desktop 'Claude Code.lnk'
$shell = New-Object -ComObject WScript.Shell
$sc = $shell.CreateShortcut($lnk)
$sc.TargetPath       = $claude
$sc.Arguments        = '--dangerously-skip-permissions'
$sc.WorkingDirectory = $env:USERPROFILE
$sc.IconLocation     = "$claude,0"
$sc.Description      = 'Launch Claude Code in YOLO mode (skip permission prompts)'
$sc.WindowStyle      = 1
$sc.Save()
Write-Ok 'Claude Code.lnk'

if (-not $SkipPathUpdate) {
    Write-Step 'Updating user PATH'
    $userPath = [Environment]::GetEnvironmentVariable('Path', 'User')
    if ($userPath -split ';' -contains $BinDir) {
        Write-Ok 'already present'
    } else {
        $new = if ([string]::IsNullOrWhiteSpace($userPath)) { $BinDir } else { "$userPath;$BinDir" }
        [Environment]::SetEnvironmentVariable('Path', $new, 'User')
        Write-Ok "added $BinDir (restart terminals to pick it up)"
        if ($inContainer) { Write-Warn 'written inside a container -- may not apply system-wide' }
    }
}

Write-Host ''
Write-Host 'Done.' -ForegroundColor White
Write-Host ''
