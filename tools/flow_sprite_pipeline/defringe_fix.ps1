$ErrorActionPreference = 'Stop'
Add-Type -AssemblyName System.Drawing
Add-Type -TypeDefinition @'
using System;
public static class Defringe {
  // 白底反预乘去白边 + 指定矩形内白色像素擦除（flat: x0,y0,x1,y1 每 4 个一框）
  public static void Process(byte[] buf, int w, int h, int stride, int[] flat, int nBoxes) {
    for (int i = 0; i < buf.Length; i += 4) {
      int a = buf[i + 3];
      if (a == 0) continue;
      if (a < 12) { buf[i + 3] = 0; continue; }
      if (a < 255) {
        // C = F*a + 255*(1-a)  =>  F = (C - 255*(1-a)) / a
        double af = a / 255.0;
        int b = buf[i], g = buf[i + 1], r = buf[i + 2];
        int fb = (int)Math.Round((b - 255.0 * (1 - af)) / af);
        int fg = (int)Math.Round((g - 255.0 * (1 - af)) / af);
        int fr = (int)Math.Round((r - 255.0 * (1 - af)) / af);
        buf[i]     = (byte)Math.Max(0, Math.Min(255, fb));
        buf[i + 1] = (byte)Math.Max(0, Math.Min(255, fg));
        buf[i + 2] = (byte)Math.Max(0, Math.Min(255, fr));
      }
    }
    if (flat != null && nBoxes > 0) {
      for (int b = 0; b < nBoxes; b++) {
        int x0 = Math.Max(0, flat[b*4]); int y0 = Math.Max(0, flat[b*4+1]);
        int x1 = Math.Min(w - 1, flat[b*4+2]); int y1 = Math.Min(h - 1, flat[b*4+3]);
        for (int y = y0; y <= y1; y++) {
          for (int x = x0; x <= x1; x++) {
            int i = (y * stride) + x * 4;
            int mn = Math.Min(buf[i], Math.Min(buf[i + 1], buf[i + 2]));
            if (mn >= 190) { buf[i + 3] = 0; }   // 只擦白色系，保车体
          }
        }
      }
    }
  }
}
'@

$dir = 'F:\godot fair duet\create\phase-war\.godot\unit_review\flow_mark4'
# 每帧的串色擦除框（local 400x448 坐标，扁平 x0,y0,x1,y1）：f3右缘/f4右缘/f5左右缘
$eraseMap = @{
  3 = @(392, 150, 399, 320)
  4 = @(372, 160, 399, 300)
  5 = @(0, 140, 85, 320, 370, 130, 399, 300)
}

for ($idx = 0; $idx -lt 6; $idx++) {
  $p = "$dir\mcell_T_$idx.png"
  $src = [System.Drawing.Bitmap]::FromFile($p)
  $w = $src.Width; $h = $src.Height
  $dst = New-Object System.Drawing.Bitmap($w, $h, [System.Drawing.Imaging.PixelFormat]::Format32bppArgb)
  $rect = New-Object System.Drawing.Rectangle(0, 0, $w, $h)
  $sd = $src.LockBits($rect, [System.Drawing.Imaging.ImageLockMode]::ReadOnly, [System.Drawing.Imaging.PixelFormat]::Format32bppArgb)
  $dd = $dst.LockBits($rect, [System.Drawing.Imaging.ImageLockMode]::WriteOnly, [System.Drawing.Imaging.PixelFormat]::Format32bppArgb)
  $len = $sd.Stride * $h
  $buf = New-Object byte[] $len
  [System.Runtime.InteropServices.Marshal]::Copy($sd.Scan0, $buf, 0, $len)
  $boxes = $null; $nBoxes = 0
  if ($eraseMap.ContainsKey($idx)) { $boxes = [int[]]$eraseMap[$idx]; $nBoxes = [int]($boxes.Length / 4) }
  [Defringe]::Process($buf, $w, $h, $sd.Stride, $boxes, $nBoxes)
  [System.Runtime.InteropServices.Marshal]::Copy($buf, 0, $dd.Scan0, $len)
  $src.UnlockBits($sd); $dst.UnlockBits($dd)
  $tmp = "$p.tmp.png"
  $dst.Save($tmp, [System.Drawing.Imaging.ImageFormat]::Png)
  $dst.Dispose(); $src.Dispose()
  Move-Item $tmp $p -Force
  Write-Output "cell $idx defringed"
}

$FW = 400; $FH = 448
$row = New-Object System.Drawing.Bitmap(($FW * 6), $FH, [System.Drawing.Imaging.PixelFormat]::Format32bppArgb)
$g = [System.Drawing.Graphics]::FromImage($row)
$g.InterpolationMode = 'HighQualityBicubic'
$g.Clear([System.Drawing.Color]::Transparent)
for ($idx = 0; $idx -lt 6; $idx++) {
  $cell = [System.Drawing.Image]::FromFile("$dir\mcell_T_$idx.png")
  $dstR = New-Object System.Drawing.Rectangle([int]($idx * $FW), 0, $FW, $FH)
  $srcR = New-Object System.Drawing.Rectangle(0, 0, $FW, $FH)
  $g.DrawImage($cell, $dstR, $srcR, [System.Drawing.GraphicsUnit]::Pixel)
  $cell.Dispose()
}
$g.Flush()
$row.Save("$dir\new_attack_row_T.png", [System.Drawing.Imaging.ImageFormat]::Png)
$g.Dispose(); $row.Dispose()
Write-Output "row rebuilt: $((Get-Item "$dir\new_attack_row_T.png").Length) bytes"

# 卡图三档重生成（源=去白边后的 f0 透明格）
$src0 = [System.Drawing.Image]::FromFile("$dir\mcell_T_0.png")
# 求 alpha>8 的包围盒（粗扫，步长2）
$minX=400; $minY=448; $maxX=0; $maxY=0
$b0 = New-Object System.Drawing.Bitmap("$dir\mcell_T_0.png")
for ($y = 0; $y -lt 448; $y += 2) { for ($x = 0; $x -lt 400; $x += 2) {
  if ($b0.GetPixel($x, $y).A -gt 8) {
    if ($x -lt $minX) { $minX = $x }; if ($x -gt $maxX) { $maxX = $x }
    if ($y -lt $minY) { $minY = $y }; if ($y -gt $maxY) { $maxY = $y }
  }
} }
$cw = $maxX - $minX + 1; $ch = $maxY - $minY + 1
Write-Output "idle bbox: ($minX,$minY) ${cw}x${ch}"
foreach ($size in @(512, 384, 256)) {
  $canvas = New-Object System.Drawing.Bitmap($size, $size, [System.Drawing.Imaging.PixelFormat]::Format32bppArgb)
  $cg = [System.Drawing.Graphics]::FromImage($canvas)
  $cg.InterpolationMode = 'HighQualityBicubic'
  $fit = [int]($size * 0.86)
  $scale = [Math]::Min($fit / [double]$cw, $fit / [double]$ch)
  $dw = [int]($cw * $scale); $dh = [int]($ch * $scale)
  $dx = [int](($size - $dw) / 2); $dy = [int](($size - $dh) / 2)
  $srcR = New-Object System.Drawing.Rectangle($minX, $minY, $cw, $ch)
  $dstR = New-Object System.Drawing.Rectangle($dx, $dy, $dw, $dh)
  $cg.DrawImage($b0, $dstR, $srcR, [System.Drawing.GraphicsUnit]::Pixel)
  $cg.Flush(); $cg.Dispose()
  $canvas.Save("$dir\new_card_$size.png", [System.Drawing.Imaging.ImageFormat]::Png)
  $canvas.Dispose()
}
Copy-Item "$dir\new_card_512.png" "F:\godot fair duet\create\phase-war\assets\card_icons\player\ww1_mark4.png" -Force
Copy-Item "$dir\new_card_384.png" "F:\godot fair duet\create\phase-war\assets\card_icons\_thumb384\player\ww1_mark4.png" -Force
Copy-Item "$dir\new_card_256.png" "F:\godot fair duet\create\phase-war\assets\card_icons\_thumb256\player\ww1_mark4.png" -Force
$b0.Dispose(); $src0.Dispose()
Write-Output 'cards updated'
Write-Output 'OK'
