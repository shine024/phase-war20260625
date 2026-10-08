$ErrorActionPreference='Stop'
Add-Type -AssemblyName System.Drawing
Add-Type -TypeDefinition @'
using System;
public static class Speck {
  public static void Erase(byte[] buf, int w, int h, int stride, int x0, int y0, int x1, int y1, int thr) {
    for (int y = Math.Max(0,y0); y <= Math.Min(h-1,y1); y++)
      for (int x = Math.Max(0,x0); x <= Math.Min(w-1,x1); x++) {
        int i = y*stride + x*4;
        int mn = Math.Min(buf[i], Math.Min(buf[i+1], buf[i+2]));
        int mx = Math.Max(buf[i], Math.Max(buf[i+1], buf[i+2]));
        if (mn >= thr && (mx - mn) <= 40) buf[i+3] = 0;
      }
  }
}
'@
$dir='F:\godot fair duet\create\phase-war\.godot\unit_review\flow_mark4'
$jobs = @(
  @{f=4; x0=360; y0=100; x1=399; y1=340; thr=160},
  @{f=5; x0=0;   y0=100; x1=110; y1=340; thr=160},
  @{f=5; x0=355; y0=100; x1=399; y1=340; thr=160}
)
foreach ($j in $jobs) {
  $p = "$dir\mcell_T_$($j.f).png"
  $src = [System.Drawing.Bitmap]::FromFile($p)
  $rect = New-Object System.Drawing.Rectangle(0,0,$src.Width,$src.Height)
  $sd = $src.LockBits($rect,[System.Drawing.Imaging.ImageLockMode]::ReadWrite,[System.Drawing.Imaging.PixelFormat]::Format32bppArgb)
  $len = $sd.Stride*$src.Height
  $buf = New-Object byte[] $len
  [System.Runtime.InteropServices.Marshal]::Copy($sd.Scan0,$buf,0,$len)
  [Speck]::Erase($buf,$src.Width,$src.Height,$sd.Stride,$j.x0,$j.y0,$j.x1,$j.y1,$j.thr)
  [System.Runtime.InteropServices.Marshal]::Copy($buf,0,$sd.Scan0,$len)
  $src.UnlockBits($sd)
  $tmp="$p.tmp.png"; $src.Save($tmp,[System.Drawing.Imaging.ImageFormat]::Png); $src.Dispose()
  Move-Item $tmp $p -Force
  Write-Output "f$($j.f) specks cleared"
}
# 重建 row
$FW=400;$FH=448
$row = New-Object System.Drawing.Bitmap(($FW*6),$FH,[System.Drawing.Imaging.PixelFormat]::Format32bppArgb)
$g=[System.Drawing.Graphics]::FromImage($row); $g.InterpolationMode='HighQualityBicubic'
$g.Clear([System.Drawing.Color]::Transparent)
for($i=0;$i -lt 6;$i++){
  $c=[System.Drawing.Image]::FromFile("$dir\mcell_T_$i.png")
  $g.DrawImage($c,(New-Object System.Drawing.Rectangle(($i*$FW),0,$FW,$FH)),(New-Object System.Drawing.Rectangle(0,0,$FW,$FH)),[System.Drawing.GraphicsUnit]::Pixel)
  $c.Dispose()
}
$g.Flush();$row.Save("$dir\new_attack_row_T.png",[System.Drawing.Imaging.ImageFormat]::Png)
$g.Dispose();$row.Dispose()
Write-Output 'row rebuilt'
# 深底复核图
$canvas = New-Object System.Drawing.Bitmap(2260,440,[System.Drawing.Imaging.PixelFormat]::Format32bppArgb)
$g2=[System.Drawing.Graphics]::FromImage($canvas); $g2.Clear([System.Drawing.Color]::FromArgb(255,28,33,48))
$r=[System.Drawing.Image]::FromFile("$dir\new_attack_row_T.png")
$g2.DrawImage($r,(New-Object System.Drawing.Rectangle(10,10,2240,418)),(New-Object System.Drawing.Rectangle(0,0,2400,448)),[System.Drawing.GraphicsUnit]::Pixel)
$g2.Flush();$canvas.Save("$env:TEMP\speck_check.png",[System.Drawing.Imaging.ImageFormat]::Png)
$g2.Dispose();$canvas.Dispose();$r.Dispose()
Write-Output OK
