$ErrorActionPreference = 'Stop'
Add-Type -AssemblyName System.Drawing
$dir = 'F:\godot fair duet\create\phase-war\.godot\unit_review\flow_mark4'
$src = [System.Drawing.Bitmap]::FromFile("$dir\mcell_0.png")  # 400x448 mirrored idle, white bg

# 1) white -> alpha with soft threshold
$w = $src.Width; $h = $src.Height
$out = New-Object System.Drawing.Bitmap($w, $h, [System.Drawing.Imaging.PixelFormat]::Format32bppArgb)
for ($y = 0; $y -lt $h; $y++) {
  for ($x = 0; $x -lt $w; $x++) {
    $p = $src.GetPixel($x, $y)
    $bright = ($p.R + $p.G + $p.B) / 3
    $a = $p.A
    if ($bright -ge 244) { $a = 0 }
    elseif ($bright -ge 224) { $a = [int](255 * (244 - $bright) / 20) }
    $out.SetPixel($x, $y, [System.Drawing.Color]::FromArgb($a, $p.R, $p.G, $p.B))
  }
}

# 2) bounding box of alpha>8
$minX = $w; $minY = $h; $maxX = 0; $maxY = 0
for ($y = 0; $y -lt $h; $y++) { for ($x = 0; $x -lt $w; $x++) {
  if ($out.GetPixel($x, $y).A -gt 8) {
    if ($x -lt $minX) { $minX = $x }; if ($x -gt $maxX) { $maxX = $x }
    if ($y -lt $minY) { $minY = $y }; if ($y -gt $maxY) { $maxY = $y }
  }
} }
$cw = $maxX - $minX + 1; $ch = $maxY - $minY + 1
Write-Output "content bbox: ($minX,$minY) ${cw}x${ch}"

# 3) center-fit into square canvases at 86%
foreach ($size in @(512, 384, 256)) {
  $canvas = New-Object System.Drawing.Bitmap($size, $size, [System.Drawing.Imaging.PixelFormat]::Format32bppArgb)
  $g = [System.Drawing.Graphics]::FromImage($canvas)
  $g.InterpolationMode = 'HighQualityBicubic'
  $g.SmoothingMode = 'HighQuality'
  $fit = [int]($size * 0.86)
  $scale = [Math]::Min($fit / [double]$cw, $fit / [double]$ch)
  $dw = [int]($cw * $scale); $dh = [int]($ch * $scale)
  $dx = [int](($size - $dw) / 2); $dy = [int](($size - $dh) / 2)
  $srcRect = New-Object System.Drawing.Rectangle($minX, $minY, $cw, $ch)
  $dstRect = New-Object System.Drawing.Rectangle($dx, $dy, $dw, $dh)
  $g.DrawImage($out, $dstRect, $srcRect, [System.Drawing.GraphicsUnit]::Pixel)
  $g.Flush(); $g.Dispose()
  $p = "$dir\new_card_$size.png"
  $canvas.Save($p, [System.Drawing.Imaging.ImageFormat]::Png)
  $canvas.Dispose()
  Write-Output "saved $p ($((Get-Item $p).Length) bytes)"
}
$out.Dispose(); $src.Dispose()
Write-Output 'OK'
