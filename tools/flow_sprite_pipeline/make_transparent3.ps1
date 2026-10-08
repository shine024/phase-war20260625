$ErrorActionPreference = 'Stop'
Add-Type -AssemblyName System.Drawing
Add-Type -TypeDefinition @'
using System;
using System.Collections.Generic;
public static class FloodKey {
  // bgTest: min channel >= 250 且 spread <= 6 才算背景候选
  // 从四边洪泛；到达=背景(a=0)；其余=前景；前景中与背景相邻的1px做 d*6+30 羽化
  public static void Process(byte[] buf, int w, int h, int stride) {
    int n = w * h;
    byte[] state = new byte[n];               // 0=unknown 1=bg 2=fg
    var queue = new Queue<int>();
    Func<int, bool> isBgLike = (p) => {
      int i = p * 4;
      int b = buf[i], g = buf[i + 1], r = buf[i + 2];
      int mx = Math.Max(r, Math.Max(g, b));
      int mn = Math.Min(r, Math.Min(g, b));
      return mn >= 250 && (mx - mn) <= 6;
    };
    for (int x = 0; x < w; x++) {
      if (isBgLike(x)) { state[x] = 1; queue.Enqueue(x); }
      int b2 = (h - 1) * w + x;
      if (state[b2] == 0 && isBgLike(b2)) { state[b2] = 1; queue.Enqueue(b2); }
    }
    for (int y = 0; y < h; y++) {
      int l = y * w, r2 = y * w + w - 1;
      if (state[l] == 0 && isBgLike(l)) { state[l] = 1; queue.Enqueue(l); }
      if (state[r2] == 0 && isBgLike(r2)) { state[r2] = 1; queue.Enqueue(r2); }
    }
    int[] nb = { -1, 1, -w, w };
    while (queue.Count > 0) {
      int p = queue.Dequeue();
      int x = p % w, y = p / w;
      foreach (int off in nb) {
        if (off == -1 && x == 0) continue;
        if (off == 1 && x == w - 1) continue;
        int q = p + off;
        if (q < 0 || q >= n) continue;
        if (state[q] == 0 && isBgLike(q)) { state[q] = 1; queue.Enqueue(q); }
      }
    }
    for (int p = 0; p < n; p++) {
      int i = p * 4;
      if (state[p] == 1) { buf[i + 3] = 0; continue; }
      int b = buf[i], g = buf[i + 1], r = buf[i + 2];
      int mn = Math.Min(r, Math.Min(g, b));
      int dv = 255 - mn;
      bool touchBg = false;
      int x = p % w, y = p / w;
      for (int dy = -1; dy <= 1 && !touchBg; dy++) {
        int yy = y + dy; if (yy < 0 || yy >= h) continue;
        for (int dx = -1; dx <= 1; dx++) {
          int xx = x + dx; if (xx < 0 || xx >= w) continue;
          if (state[yy * w + xx] == 1) { touchBg = true; break; }
        }
      }
      byte a;
      if (touchBg) {
        a = (byte)Math.Min(255, dv * 6 + 30);   // 边缘羽化
      } else {
        a = 255;                                 // 前景整体不透明（焰心/烟/车体全保）
      }
      buf[i + 3] = a;
    }
  }
}
'@

$dir = 'F:\godot fair duet\create\phase-war\.godot\unit_review\flow_mark4'
for ($idx = 0; $idx -lt 6; $idx++) {
  $src = [System.Drawing.Bitmap]::FromFile("$dir\mcell_$idx.png")
  $w = $src.Width; $h = $src.Height
  $dst = New-Object System.Drawing.Bitmap($w, $h, [System.Drawing.Imaging.PixelFormat]::Format32bppArgb)
  $rect = New-Object System.Drawing.Rectangle(0, 0, $w, $h)
  $sd = $src.LockBits($rect, [System.Drawing.Imaging.ImageLockMode]::ReadOnly, [System.Drawing.Imaging.PixelFormat]::Format32bppArgb)
  $dd = $dst.LockBits($rect, [System.Drawing.Imaging.ImageLockMode]::WriteOnly, [System.Drawing.Imaging.PixelFormat]::Format32bppArgb)
  $len = $sd.Stride * $h
  $buf = New-Object byte[] $len
  [System.Runtime.InteropServices.Marshal]::Copy($sd.Scan0, $buf, 0, $len)
  [FloodKey]::Process($buf, $w, $h, $sd.Stride)
  [System.Runtime.InteropServices.Marshal]::Copy($buf, 0, $dd.Scan0, $len)
  $src.UnlockBits($sd); $dst.UnlockBits($dd)
  $p = "$dir\mcell_T_$idx.png"
  $dst.Save($p, [System.Drawing.Imaging.ImageFormat]::Png)
  $dst.Dispose(); $src.Dispose()
  Write-Output "cell $idx -> $((Get-Item $p).Length) bytes"
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
Write-Output "row: $((Get-Item "$dir\new_attack_row_T.png").Length) bytes"
Write-Output 'OK'
