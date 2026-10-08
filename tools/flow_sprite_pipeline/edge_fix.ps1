$ErrorActionPreference='Stop'
Add-Type -AssemblyName System.Drawing
Add-Type -TypeDefinition @'
using System;
public static class EdgeFix {
  // 左缘锥形收尾：对 x=0 有直切边的行，把 x0..K 重绘为从透明到原有的渐变
  public static void Taper(byte[] buf, int w, int h, int stride, int K) {
    for (int y = 0; y < h; y++) {
      int a0px = buf[y*stride + 3];
      if (a0px <= 8) continue;                    // 该行无直切内容
      int r2=0,g2=0,b2=0,a2=0;
      for (int x = 2; x <= 4; x++) {              // 采样原色
        int i = y*stride + x*4;
        b2 += buf[i]; g2 += buf[i+1]; r2 += buf[i+2]; a2 += buf[i+3];
      }
      b2/=3; g2/=3; r2/=3; a2/=3;
      for (int x = 0; x < K; x++) {
        double t = x / (double)K;
        int a = (int)Math.Round(a2 * Math.Pow(t, 1.3));
        int i = y*stride + x*4;
        buf[i] = (byte)b2; buf[i+1] = (byte)g2; buf[i+2] = (byte)r2; buf[i+3] = (byte)a;
      }
    }
  }
  // 火光边缘 alpha 平滑：部分透明且暖亮色的像素做 3x3 alpha 盒式模糊
  public static void SmoothGlow(byte[] buf, int w, int h, int stride) {
    int[] copy = new int[w*h];
    for (int y = 0; y < h; y++) for (int x = 0; x < w; x++)
      copy[y*w+x] = buf[y*stride + x*4 + 3];
    for (int y = 1; y < h-1; y++) {
      for (int x = 1; x < w-1; x++) {
        int i = y*stride + x*4;
        int a = buf[i+3];
        if (a == 0 || a >= 250) continue;
        int mn = Math.Min(buf[i], Math.Min(buf[i+1], buf[i+2]));
        int mx = Math.Max(buf[i], Math.Max(buf[i+1], buf[i+2]));
        if (mn < 120 && mx < 200) continue;       // 深色像素（车体）不动
        int sum = 0, n = 0;
        for (int dy = -1; dy <= 1; dy++) for (int dx = -1; dx <= 1; dx++) {
          sum += copy[(y+dy)*w + (x+dx)]; n++;
        }
        buf[i+3] = (byte)(sum / n);
      }
    }
  }
}
'@
$dir='F:\godot fair duet\create\phase-war\.godot\unit_review\flow_mark4'
foreach($i in 0..5){
  $p="$dir\mcell_T_$i.png"
  $src=[System.Drawing.Bitmap]::FromFile($p)
  $rect=[System.Drawing.Rectangle]::new(0,0,$src.Width,$src.Height)
  $sd=$src.LockBits($rect,[System.Drawing.Imaging.ImageLockMode]::ReadWrite,[System.Drawing.Imaging.PixelFormat]::Format32bppArgb)
  $len=$sd.Stride*$src.Height;$buf=New-Object byte[] $len
  [System.Runtime.InteropServices.Marshal]::Copy($sd.Scan0,$buf,0,$len)
  if($i -eq 3){ [EdgeFix]::Taper($buf,400,448,$sd.Stride,30) }
  if($i -eq 4){ [EdgeFix]::Taper($buf,400,448,$sd.Stride,24) }
  [EdgeFix]::SmoothGlow($buf,400,448,$sd.Stride)
  [System.Runtime.InteropServices.Marshal]::Copy($buf,0,$sd.Scan0,$len)
  $src.UnlockBits($sd)
  $tmp="$p.tmp.png";$src.Save($tmp,[System.Drawing.Imaging.ImageFormat]::Png);$src.Dispose()
  Move-Item $tmp $p -Force
  Write-Output "f$i fixed"
}
# 重建 row_T + 深底检查图
$FW=400;$FH=448
$row=[System.Drawing.Bitmap]::new($FW*6,$FH,[System.Drawing.Imaging.PixelFormat]::Format32bppArgb)
$g=[System.Drawing.Graphics]::FromImage($row);$g.InterpolationMode='HighQualityBicubic'
$g.Clear([System.Drawing.Color]::Transparent)
for($i=0;$i -lt 6;$i++){
  $c=[System.Drawing.Image]::FromFile("$dir\mcell_T_$i.png")
  $g.DrawImage($c,[System.Drawing.Rectangle]::new(($i*$FW),0,$FW,$FH),[System.Drawing.Rectangle]::new(0,0,$FW,$FH),[System.Drawing.GraphicsUnit]::Pixel)
  $c.Dispose()
}
$g.Flush();$row.Save("$dir\new_attack_row_T.png",[System.Drawing.Imaging.ImageFormat]::Png);$g.Dispose();$row.Dispose()
$canvas=[System.Drawing.Bitmap]::new(2260,440,[System.Drawing.Imaging.PixelFormat]::Format32bppArgb)
$g2=[System.Drawing.Graphics]::FromImage($canvas);$g2.Clear([System.Drawing.Color]::FromArgb(255,28,33,48))
$r=[System.Drawing.Image]::FromFile("$dir\new_attack_row_T.png")
$g2.DrawImage($r,[System.Drawing.Rectangle]::new(10,10,2240,418),[System.Drawing.Rectangle]::new(0,0,2400,448),[System.Drawing.GraphicsUnit]::Pixel)
$g2.Flush();$canvas.Save("$env:TEMP\taper_check.png",[System.Drawing.Imaging.ImageFormat]::Png)
$g2.Dispose();$canvas.Dispose();$r.Dispose()
Write-Output OK
