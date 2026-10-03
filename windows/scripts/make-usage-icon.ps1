<#
.SYNOPSIS
  Builds claude-usage.ico: the Claude burst inside a battery, for the
  claude-usage.bat shortcut (a "how much is left" icon).

  Takes the 256 px frame out of icons\claude-logo.ico, so it needs no source
  artwork. Writes the same PNG-in-ICO container as make-icon.ps1.

.EXAMPLE
  .\scripts\make-usage-icon.ps1
#>
[CmdletBinding()]
param(
  [string]$Logo,
  [string]$Destination,

  # Fraction of the battery shown as charged.
  [double]$Charge = 0.7
)

$ErrorActionPreference = "Stop"
Add-Type -AssemblyName System.Drawing

# Resolved here rather than in param(): Windows PowerShell 5.1 leaves
# $PSScriptRoot / $MyInvocation empty inside parameter defaults.
$iconDir = Join-Path (Split-Path -Parent $PSScriptRoot) "icons"
if (-not $Logo) { $Logo = Join-Path $iconDir "claude-logo.ico" }
if (-not $Destination) { $Destination = Join-Path $iconDir "claude-usage.ico" }

# Pull the largest PNG entry out of the logo ICO.
$ico = [System.IO.File]::ReadAllBytes((Resolve-Path -LiteralPath $Logo).Path)
$count = [BitConverter]::ToUInt16($ico, 4)
$best = -1; $bestDim = 0
for ($i = 0; $i -lt $count; $i++) {
  $dim = $ico[6 + 16 * $i]; if ($dim -eq 0) { $dim = 256 }
  if ($dim -gt $bestDim) { $bestDim = $dim; $best = $i }
}
$len = [BitConverter]::ToUInt32($ico, 6 + 16 * $best + 8)
$off = [BitConverter]::ToUInt32($ico, 6 + 16 * $best + 12)
$logoBmp = [System.Drawing.Bitmap]::FromStream((New-Object System.IO.MemoryStream (, $ico[$off..($off + $len - 1)])))

function New-RoundRect([float]$x, [float]$y, [float]$w, [float]$h, [float]$r) {
  $p = New-Object System.Drawing.Drawing2D.GraphicsPath
  $d = 2 * $r
  $p.AddArc($x, $y, $d, $d, 180, 90)
  $p.AddArc($x + $w - $d, $y, $d, $d, 270, 90)
  $p.AddArc($x + $w - $d, $y + $h - $d, $d, $d, 0, 90)
  $p.AddArc($x, $y + $h - $d, $d, $d, 90, 90)
  $p.CloseFigure()
  $p
}

$S = 256
$canvas = New-Object System.Drawing.Bitmap $S, $S, ([System.Drawing.Imaging.PixelFormat]::Format32bppArgb)
$g = [System.Drawing.Graphics]::FromImage($canvas)
$g.Clear([System.Drawing.Color]::Transparent)
$g.SmoothingMode = [System.Drawing.Drawing2D.SmoothingMode]::AntiAlias
$g.InterpolationMode = [System.Drawing.Drawing2D.InterpolationMode]::HighQualityBicubic
$g.PixelOffsetMode = [System.Drawing.Drawing2D.PixelOffsetMode]::HighQuality

$ink    = [System.Drawing.Color]::FromArgb(255, 45, 42, 40)
$shell  = [System.Drawing.Color]::FromArgb(255, 250, 246, 240)
$chargeColor = [System.Drawing.Color]::FromArgb(255, 246, 205, 188)

# Horizontal battery: body + terminal nub on the right.
$bx = 10; $by = 52; $bw = 214; $bh = 152; $stroke = 16
$body = New-RoundRect $bx $by $bw $bh 30
$g.FillPath((New-Object System.Drawing.SolidBrush $shell), $body)

$inset = $stroke / 2 + 10
$cw = ($bw - 2 * $inset) * $Charge
$fill = New-RoundRect ($bx + $inset) ($by + $inset) $cw ($bh - 2 * $inset) 14
$g.FillPath((New-Object System.Drawing.SolidBrush $chargeColor), $fill)

$g.DrawPath((New-Object System.Drawing.Pen $ink, $stroke), $body)
$nub = New-RoundRect ($bx + $bw + 4) 100 20 56 8
$g.FillPath((New-Object System.Drawing.SolidBrush $ink), $nub)

# Claude burst centred in the body.
$ls = 128
$g.DrawImage($logoBmp, (New-Object System.Drawing.Rectangle ([int]($bx + ($bw - $ls) / 2)), ([int]($by + ($bh - $ls) / 2)), $ls, $ls))
$g.Dispose()
$logoBmp.Dispose()

$sizes = @(256, 128, 64, 48, 40, 32, 24, 20, 16)
$pngs = @()
foreach ($s in $sizes) {
  $bmp = New-Object System.Drawing.Bitmap $s, $s, ([System.Drawing.Imaging.PixelFormat]::Format32bppArgb)
  $gg = [System.Drawing.Graphics]::FromImage($bmp)
  $gg.Clear([System.Drawing.Color]::Transparent)
  $gg.InterpolationMode = [System.Drawing.Drawing2D.InterpolationMode]::HighQualityBicubic
  $gg.PixelOffsetMode = [System.Drawing.Drawing2D.PixelOffsetMode]::HighQuality
  $gg.SmoothingMode = [System.Drawing.Drawing2D.SmoothingMode]::HighQuality
  $gg.DrawImage($canvas, (New-Object System.Drawing.Rectangle 0, 0, $s, $s))
  $gg.Dispose()
  $ms = New-Object System.IO.MemoryStream
  $bmp.Save($ms, [System.Drawing.Imaging.ImageFormat]::Png)
  $pngs += , $ms.ToArray()
  $ms.Dispose()
  $bmp.Dispose()
}
$canvas.Dispose()

# ICO container with PNG-compressed entries (Vista+).
$fs = [System.IO.File]::Create($Destination)
$bw2 = New-Object System.IO.BinaryWriter $fs
$bw2.Write([UInt16]0); $bw2.Write([UInt16]1); $bw2.Write([UInt16]$sizes.Count)
$offset = 6 + 16 * $sizes.Count
for ($i = 0; $i -lt $sizes.Count; $i++) {
  $dim = if ($sizes[$i] -ge 256) { 0 } else { $sizes[$i] }
  $bw2.Write([Byte]$dim); $bw2.Write([Byte]$dim)
  $bw2.Write([Byte]0); $bw2.Write([Byte]0)
  $bw2.Write([UInt16]1); $bw2.Write([UInt16]32)
  $bw2.Write([UInt32]$pngs[$i].Length)
  $bw2.Write([UInt32]$offset)
  $offset += $pngs[$i].Length
}
foreach ($p in $pngs) { $bw2.Write($p) }
$bw2.Flush(); $bw2.Close(); $fs.Close()

Write-Host "wrote $Destination ($((Get-Item $Destination).Length) bytes)"
