<#
.SYNOPSIS
    Installs a YOLO-mode desktop launcher for Claude Code.

.DESCRIPTION
    Resolves claude.exe to a real, non-virtualized path under ~\.local\bin and
    generates the desktop shortcut from scratch. Nothing is hardcoded to one machine.

    Run this from a NORMAL PowerShell window, not from a terminal inside the Claude
    desktop app -- see the container note below and in README.md.

    Because the shortcut runs Claude Code with permission prompts off, the installer
    also turns off Remote Control, Workflows and scheduled cloud routines in the user
    settings -- see the lockdown note below. Pass -SkipLockdown to opt out.

.PARAMETER SkipPathUpdate
    Do not add ~\.local\bin to the user PATH.

.PARAMETER SkipLockdown
    Do not touch ~\.claude\settings.json. Leaves Remote Control, Workflows and
    scheduled cloud routines at whatever they already are.

.PARAMETER Force
    Overwrite an existing claude.exe in ~\.local\bin instead of keeping it.

.PARAMETER Name
    Shortcut file name, without the .lnk extension.
#>
[CmdletBinding()]
param(
    [switch]$SkipPathUpdate,
    [switch]$SkipLockdown,
    [switch]$Force,
    [string]$Name = 'yolo-claude'
)

$ErrorActionPreference = 'Stop'
Add-Type -AssemblyName System.Drawing

$RepoDir = Split-Path -Parent $MyInvocation.MyCommand.Path
$BinDir  = Join-Path $env:USERPROFILE '.local\bin'

# Prefer the OneDrive-redirected Desktop when one exists -- on a redirected
# profile the shell folder and the real Desktop are different directories, and
# only the redirected one is what the user actually sees.
$Desktop = [Environment]::GetFolderPath('Desktop')
if ($env:OneDrive) {
    $oneDriveDesktop = Join-Path $env:OneDrive 'Desktop'
    if (Test-Path -LiteralPath $oneDriveDesktop) { $Desktop = $oneDriveDesktop }
}

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
# Icon
#
# claude.exe embeds the logo, but only at 32x32, so the shortcut looks soft at
# large icon sizes. If the Claude desktop app is installed, its package ships a
# 300x300 logo we can rebuild into a proper multi-resolution .ico. The .ico is
# written next to claude.exe so the shortcut does not depend on the versioned
# WindowsApps path, which changes on every app update.
# --------------------------------------------------------------------------
function Find-LogoSource {
    $roots = @()
    try {
        $pkg = Get-AppxPackage -Name 'Claude' -ErrorAction SilentlyContinue
        if ($pkg) { $roots += $pkg.InstallLocation }
    } catch { }
    $roots += Get-ChildItem (Join-Path $env:ProgramFiles 'WindowsApps') -Directory -Filter 'Claude_*' -ErrorAction SilentlyContinue |
        Select-Object -ExpandProperty FullName

    foreach ($root in ($roots | Where-Object { $_ } | Select-Object -Unique)) {
        $assets = Join-Path $root 'assets'
        $best = $null; $bestPx = 0
        Get-ChildItem $assets -Filter 'Square*Logo*.png' -ErrorAction SilentlyContinue | ForEach-Object {
            try {
                $img = [System.Drawing.Image]::FromFile($_.FullName)
                $px = [math]::Min($img.Width, $img.Height)
                $img.Dispose()
                if ($px -gt $bestPx) { $bestPx = $px; $best = $_.FullName }
            } catch { }
        }
        if ($best -and $bestPx -ge 128) { return $best }
    }
    return $null
}

function New-IcoFile {
    param(
        [Parameter(Mandatory)][string]$SourceImage,
        [Parameter(Mandatory)][string]$Destination,
        [int[]]$Sizes = @(16, 24, 32, 48, 64, 128, 256)
    )

    $src = [System.Drawing.Image]::FromFile($SourceImage)
    try {
        $frames = @()
        foreach ($size in $Sizes) {
            $bmp = New-Object System.Drawing.Bitmap($size, $size, [System.Drawing.Imaging.PixelFormat]::Format32bppArgb)
            $g = [System.Drawing.Graphics]::FromImage($bmp)
            $g.InterpolationMode    = [System.Drawing.Drawing2D.InterpolationMode]::HighQualityBicubic
            $g.PixelOffsetMode      = [System.Drawing.Drawing2D.PixelOffsetMode]::HighQuality
            $g.SmoothingMode        = [System.Drawing.Drawing2D.SmoothingMode]::HighQuality
            $g.CompositingQuality   = [System.Drawing.Drawing2D.CompositingQuality]::HighQuality
            $g.Clear([System.Drawing.Color]::Transparent)
            $g.DrawImage($src, (New-Object System.Drawing.Rectangle(0, 0, $size, $size)))
            $g.Dispose()

            # 32bpp BGRA, stored bottom-up
            $rect = New-Object System.Drawing.Rectangle(0, 0, $size, $size)
            $data = $bmp.LockBits($rect, [System.Drawing.Imaging.ImageLockMode]::ReadOnly, [System.Drawing.Imaging.PixelFormat]::Format32bppArgb)
            $stride = $size * 4
            $pixels = New-Object byte[] ($stride * $size)
            for ($y = 0; $y -lt $size; $y++) {
                $srcRow = [IntPtr]::Add($data.Scan0, $y * $data.Stride)
                [System.Runtime.InteropServices.Marshal]::Copy($srcRow, $pixels, ($size - 1 - $y) * $stride, $stride)
            }
            $bmp.UnlockBits($data)
            $bmp.Dispose()

            # 1bpp AND mask, rows padded to 4 bytes; all zero, the alpha channel does the work
            $maskStride = [math]::Ceiling($size / 32) * 4
            $mask = New-Object byte[] ($maskStride * $size)

            $ms = New-Object System.IO.MemoryStream
            $bw = New-Object System.IO.BinaryWriter($ms)
            # BITMAPINFOHEADER
            $bw.Write([uint32]40)
            $bw.Write([int32]$size)
            $bw.Write([int32]($size * 2))   # height doubled: XOR image + AND mask
            $bw.Write([uint16]1)
            $bw.Write([uint16]32)
            $bw.Write([uint32]0)            # BI_RGB
            $bw.Write([uint32]($pixels.Length + $mask.Length))
            $bw.Write([int32]0); $bw.Write([int32]0)
            $bw.Write([uint32]0); $bw.Write([uint32]0)
            $bw.Write($pixels)
            $bw.Write($mask)
            $bw.Flush()

            $frames += [pscustomobject]@{ Size = $size; Bytes = $ms.ToArray() }
            $bw.Dispose(); $ms.Dispose()
        }

        $out = New-Object System.IO.MemoryStream
        $w = New-Object System.IO.BinaryWriter($out)
        # ICONDIR
        $w.Write([uint16]0); $w.Write([uint16]1); $w.Write([uint16]$frames.Count)
        $offset = 6 + (16 * $frames.Count)
        foreach ($f in $frames) {
            $dim = if ($f.Size -ge 256) { 0 } else { $f.Size }   # 0 means 256 in the ICO format
            $w.Write([byte]$dim); $w.Write([byte]$dim)
            $w.Write([byte]0); $w.Write([byte]0)
            $w.Write([uint16]1); $w.Write([uint16]32)
            $w.Write([uint32]$f.Bytes.Length)
            $w.Write([uint32]$offset)
            $offset += $f.Bytes.Length
        }
        foreach ($f in $frames) { $w.Write($f.Bytes) }
        $w.Flush()
        [System.IO.File]::WriteAllBytes($Destination, $out.ToArray())
        $w.Dispose(); $out.Dispose()
    } finally {
        $src.Dispose()
    }
}

# --------------------------------------------------------------------------
# Lockdown
#
# The shortcut launches Claude Code with --dangerously-skip-permissions, so
# nothing it runs asks for confirmation. Two features turn that from "risky on
# a machine I am sitting at" into "risky from anywhere":
#
#   Remote Control  claude.ai/code takeover, `claude remote-control`,
#                   --remote-control / --rc, auto-start, and the in-session
#                   toggle. Paired with YOLO mode, anything sent from a phone
#                   or a browser tab executes here unconfirmed.
#   Workflows/cron  multi-agent orchestration and scheduled cloud routines,
#                   which fan out unattended work under those same permissions.
#
# So we merge three keys into the user settings. Existing settings are kept and
# a timestamped backup is written first. -SkipLockdown opts out.
#
# There is deliberately no switch here for `--bg` background agents: Claude Code
# ships none. CLAUDE_CODE_DISABLE_BACKGROUND_TASKS is a different feature -- it
# kills backgrounded shell commands, which long-running jobs rely on -- so
# setting it would break more than it protects.
# --------------------------------------------------------------------------
function Set-ClaudeLockdown {
    param([Parameter(Mandatory)][string]$SettingsPath)

    New-Item -ItemType Directory -Path (Split-Path -Parent $SettingsPath) -Force | Out-Null

    $settings = $null
    if (Test-Path -LiteralPath $SettingsPath) {
        $raw = Get-Content -LiteralPath $SettingsPath -Raw -ErrorAction Stop
        if (-not [string]::IsNullOrWhiteSpace($raw)) {
            try { $settings = $raw | ConvertFrom-Json -ErrorAction Stop }
            catch { throw "existing settings.json is not valid JSON -- fix or move it first" }
        }
    }
    if (-not $settings) { $settings = New-Object psobject }

    $changed = $false

    foreach ($key in @('disableRemoteControl', 'disableWorkflows')) {
        if ($settings.PSObject.Properties[$key] -and $settings.$key -eq $true) { continue }
        $settings | Add-Member -NotePropertyName $key -NotePropertyValue $true -Force
        $changed = $true
    }

    if (-not $settings.PSObject.Properties['env'] -or $null -eq $settings.env) {
        $settings | Add-Member -NotePropertyName 'env' -NotePropertyValue (New-Object psobject) -Force
        $changed = $true
    }
    if ($settings.env.CLAUDE_CODE_DISABLE_CRON -ne '1') {
        $settings.env | Add-Member -NotePropertyName 'CLAUDE_CODE_DISABLE_CRON' -NotePropertyValue '1' -Force
        $changed = $true
    }

    if (-not $changed) { return $null }

    $backup = $null
    if (Test-Path -LiteralPath $SettingsPath) {
        $backup = "$SettingsPath.bak-$(Get-Date -Format 'yyyyMMdd-HHmmss')"
        Copy-Item -LiteralPath $SettingsPath -Destination $backup -Force
    }

    # -Depth is well past anything that lives in settings.json (hooks, permissions,
    # autoMode); the PS 5.1 default of 2 would flatten those into literal strings.
    # WriteAllText with a BOM-less UTF8Encoding because Set-Content/Out-File here
    # emit a BOM, which not every JSON reader tolerates.
    $json = $settings | ConvertTo-Json -Depth 32
    [System.IO.File]::WriteAllText($SettingsPath, $json, (New-Object System.Text.UTF8Encoding($false)))
    return @{ Backup = $backup }
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

if ($SkipLockdown) {
    Write-Step 'Hardening Claude Code settings'
    Write-Warn '-SkipLockdown: Remote Control and Workflows left as-is'
    Write-Warn 'a YOLO shortcut plus Remote Control means remote input runs here unconfirmed'
} else {
    Write-Step 'Hardening Claude Code settings'
    $settingsPath = Join-Path $env:USERPROFILE '.claude\settings.json'
    try {
        $lock = Set-ClaudeLockdown -SettingsPath $settingsPath
        if ($null -eq $lock) {
            Write-Ok 'already set: Remote Control off, Workflows off, cron routines off'
        } else {
            Write-Ok 'Remote Control off, Workflows off, cron routines off'
            if ($lock.Backup) { Write-Ok "backed up to $(Split-Path -Leaf $lock.Backup)" }
            Write-Warn 'restart any running Claude Code session to pick this up'
        }
    } catch {
        Write-Warn "left $settingsPath alone: $($_.Exception.Message)"
    }
}

Write-Step 'Preparing icon'
$icoPath = Join-Path $BinDir 'claude.ico'
$iconLocation = "$claude,0"
if ((Test-Path -LiteralPath $icoPath) -and -not $Force) {
    $iconLocation = "$icoPath,0"
    Write-Ok "already built: $icoPath"
} else {
    $logo = Find-LogoSource
    if ($logo) {
        try {
            New-IcoFile -SourceImage $logo -Destination $icoPath
            $iconLocation = "$icoPath,0"
            Write-Ok "built $icoPath from $(Split-Path -Leaf $logo)"
        } catch {
            Write-Warn "icon build failed ($($_.Exception.Message)); falling back to the bundled icon"
        }
    }

    # No desktop app to harvest a logo from, or the build failed. Fall back to
    # the .ico committed to this repo rather than to the 32x32 one inside
    # claude.exe, which is soft at large desktop icon sizes.
    if ($iconLocation -eq "$claude,0") {
        $bundled = Join-Path $RepoDir 'icons\claude-logo.ico'
        if (Test-Path -LiteralPath $bundled) {
            Copy-Item -LiteralPath $bundled -Destination $icoPath -Force
            $iconLocation = "$icoPath,0"
            Write-Ok "copied the bundled icon to $icoPath"
        } else {
            Write-Warn 'No logo source and no bundled icon; using the 32x32 icon inside claude.exe'
        }
    }
}

Write-Step "Creating shortcut on $Desktop"
$lnk = Join-Path $Desktop "$Name.lnk"
$shell = New-Object -ComObject WScript.Shell
$sc = $shell.CreateShortcut($lnk)
$sc.TargetPath       = $claude
$sc.Arguments        = '--dangerously-skip-permissions'
$sc.WorkingDirectory = $env:USERPROFILE
$sc.IconLocation     = $iconLocation
$sc.Description      = 'Launch Claude Code in YOLO mode (skip permission prompts)'
$sc.WindowStyle      = 1
$sc.Save()
Write-Ok "$Name.lnk"

# Nudge Explorer so a changed icon shows without a sign-out.
try { ie4uinit.exe -show } catch { }

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
