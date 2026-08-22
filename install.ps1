<#
.SYNOPSIS
  Installs the yolo-claude desktop shortcut: Claude Code launched with
  --dangerously-skip-permissions, wearing the Claude logo.

.EXAMPLE
  .\install.ps1
  .\install.ps1 -Name "yolo" -ClaudePath "D:\tools\claude.exe"
#>
[CmdletBinding()]
param(
  # Shortcut file name, without the .lnk extension.
  [string]$Name = "yolo-claude",

  # Path to claude.exe. Auto-detected when omitted.
  [string]$ClaudePath,

  # Arguments passed to claude.exe on launch.
  [string]$Arguments = "--dangerously-skip-permissions",

  # Working directory the shortcut starts in.
  [string]$WorkingDirectory = $HOME
)

$ErrorActionPreference = "Stop"
$repo = Split-Path -Parent $MyInvocation.MyCommand.Path

function Resolve-ClaudeExe {
  param([string]$Explicit)

  if ($Explicit) {
    if (-not (Test-Path -LiteralPath $Explicit)) {
      throw "claude.exe not found at: $Explicit"
    }
    return (Resolve-Path -LiteralPath $Explicit).Path
  }

  $candidates = @(
    (Join-Path $HOME ".local\bin\claude.exe"),
    (Join-Path $env:LOCALAPPDATA "Programs\claude\claude.exe"),
    (Join-Path $env:APPDATA "npm\claude.cmd")
  )
  foreach ($c in $candidates) {
    if ($c -and (Test-Path -LiteralPath $c)) { return $c }
  }

  $onPath = Get-Command claude -ErrorAction SilentlyContinue
  if ($onPath) { return $onPath.Source }

  throw "Could not locate claude.exe. Pass -ClaudePath explicitly."
}

function Resolve-DesktopPath {
  # OneDrive-redirected Desktop wins when it exists; the shell's own
  # Desktop folder is the fallback.
  $shellDesktop = [Environment]::GetFolderPath("Desktop")
  if ($env:OneDrive) {
    $oneDrive = Join-Path $env:OneDrive "Desktop"
    if (Test-Path -LiteralPath $oneDrive) { return $oneDrive }
  }
  return $shellDesktop
}

# --- icon -------------------------------------------------------------
$iconSource = Join-Path $repo "icons\claude-logo.ico"
if (-not (Test-Path -LiteralPath $iconSource)) {
  throw "icons\claude-logo.ico is missing from the repo at: $repo"
}

$iconDir = Join-Path $HOME ".claude"
if (-not (Test-Path -LiteralPath $iconDir)) {
  New-Item -ItemType Directory -Path $iconDir | Out-Null
}
# Installed outside the Claude Code install tree so an update can't wipe it.
$iconTarget = Join-Path $iconDir "claude-logo.ico"
Copy-Item -LiteralPath $iconSource -Destination $iconTarget -Force
Write-Host "icon    -> $iconTarget"

# --- shortcut ---------------------------------------------------------
$exe = Resolve-ClaudeExe -Explicit $ClaudePath
$desktop = Resolve-DesktopPath
$lnk = Join-Path $desktop "$Name.lnk"

$shell = New-Object -ComObject WScript.Shell
$sc = $shell.CreateShortcut($lnk)
$sc.TargetPath = $exe
$sc.Arguments = $Arguments
$sc.WorkingDirectory = $WorkingDirectory
$sc.IconLocation = "$iconTarget,0"
$sc.Description = "Claude Code (permissions skipped)"
$sc.Save()

Write-Host "target  -> $exe $Arguments"
Write-Host "shortcut-> $lnk"

# Nudge Explorer so the new icon shows without a sign-out.
try { ie4uinit.exe -show } catch { }

Write-Host ""
Write-Host "Done. '$Name' is on your desktop." -ForegroundColor Green
