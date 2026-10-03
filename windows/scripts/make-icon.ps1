<#
.SYNOPSIS
  Regenerates claude-logo.ico from a source PNG.

  Only needed if you want to rebuild the icon from a different artwork file --
  claude-logo.ico is already committed, so install.ps1 never calls this.

  The source PNG ships with an opaque white background, so this recovers a
  per-pixel alpha from the white/orange blend rather than doing a hard
  colour-key knockout, which would leave a white fringe on the anti-aliased
  edges of the burst.

.EXAMPLE
  .\scripts\make-icon.ps1 -Source .\claude.png
#>
[CmdletBinding()]
param(
  [Parameter(Mandatory = $true)]
  [string]$Source,

  [string]$Destination = (Join-Path (Split-Path -Parent (Split-Path -Parent $MyInvocation.MyCommand.Path)) "icons\claude-logo.ico"),

  # Brand orange of the logo artwork, sampled from a solid interior pixel.
  [int]$R = 217, [int]$G = 119, [int]$B = 87
)

$ErrorActionPreference = "Stop"
Add-Type -AssemblyName System.Drawing

$orig = [System.Drawing.Bitmap]::FromFile((Resolve-Path -LiteralPath $Source).Path)
$base = New-Object System.Drawing.Bitmap $orig.Width, $orig.Height, ([System.Drawing.Imaging.PixelFormat]::Format32bppArgb)
$g = [System.Drawing.Graphics]::FromImage($base)
$g.Clear([System.Drawing.Color]::Transparent)
$g.DrawImage($orig, 0, 0, $orig.Width, $orig.Height)
$g.Dispose()
$orig.Dispose()

# Un-blend: each pixel is white * (1-a) + brand * a, so a falls out of the
# channel furthest from white.
for ($y = 0; $y -lt $base.Height; $y++) {
  for ($x = 0; $x -lt $base.Width; $x++) {
    $c = $base.GetPixel($x, $y)
    $a = [int][Math]::Round((255 - $c.B) * 255.0 / (255 - $B))
    if ($a -le 3) {
      $base.SetPixel($x, $y, [System.Drawing.Color]::Transparent)
    } else {
      if ($a -gt 255) { $a = 255 }
      $base.SetPixel($x, $y, [System.Drawing.Color]::FromArgb($a, $R, $G, $B))
    }
  }
}

# Crop to the glyph so it fills the icon instead of floating in dead margin.
$minX = $base.Width; $minY = $base.Height; $maxX = -1; $maxY = -1
for ($y = 0; $y -lt $base.Height; $y++) {
  for ($x = 0; $x -lt $base.Width; $x++) {
    if ($base.GetPixel($x, $y).A -gt 8) {
      if ($x -lt $minX) { $minX = $x }
      if ($x -gt $maxX) { $maxX = $x }
      if ($y -lt $minY) { $minY = $y }
      if ($y -gt $maxY) { $maxY = $y }
    }
  }
}
$side = [Math]::Max($maxX - $minX + 1, $maxY - $minY + 1)
$cx = ($minX + $maxX) / 2.0
$cy = ($minY + $maxY) / 2.0
$sqSide = [int]($side + 2 * [int]($side * 0.06))
$left = [int]([Math]::Round($cx - $sqSide / 2.0))
$top = [int]([Math]::Round($cy - $sqSide / 2.0))

$canvas = New-Object System.Drawing.Bitmap $sqSide, $sqSide, ([System.Drawing.Imaging.PixelFormat]::Format32bppArgb)
$gc = [System.Drawing.Graphics]::FromImage($canvas)
$gc.Clear([System.Drawing.Color]::Transparent)
$gc.DrawImage($base,
  (New-Object System.Drawing.Rectangle 0, 0, $sqSide, $sqSide),
  (New-Object System.Drawing.Rectangle $left, $top, $sqSide, $sqSide),
  [System.Drawing.GraphicsUnit]::Pixel)
$gc.Dispose()
$base.Dispose()

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
$bw = New-Object System.IO.BinaryWriter $fs
$bw.Write([UInt16]0); $bw.Write([UInt16]1); $bw.Write([UInt16]$sizes.Count)
$offset = 6 + 16 * $sizes.Count
for ($i = 0; $i -lt $sizes.Count; $i++) {
  $dim = if ($sizes[$i] -ge 256) { 0 } else { $sizes[$i] }
  $bw.Write([Byte]$dim); $bw.Write([Byte]$dim)
  $bw.Write([Byte]0); $bw.Write([Byte]0)
  $bw.Write([UInt16]1); $bw.Write([UInt16]32)
  $bw.Write([UInt32]$pngs[$i].Length)
  $bw.Write([UInt32]$offset)
  $offset += $pngs[$i].Length
}
foreach ($p in $pngs) { $bw.Write($p) }
$bw.Flush(); $bw.Close(); $fs.Close()

Write-Host "wrote $Destination ($((Get-Item $Destination).Length) bytes)"
