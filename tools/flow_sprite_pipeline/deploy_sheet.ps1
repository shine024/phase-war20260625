$ErrorActionPreference='Stop'
Add-Type -AssemblyName System.Drawing
Add-Type -AssemblyName PresentationCore
$dir='F:\godot fair duet\create\phase-war\.godot\unit_review\flow_mark4'
$unit='F:\godot fair duet\create\phase-war\assets\effects\unit_anims\ww1_mark4'
$frames=@()
# 1) 1536x256 攻击表（6x256）
$sheet=New-Object System.Drawing.Bitmap(1536,256,[System.Drawing.Imaging.PixelFormat]::Format32bppArgb)
$g=[System.Drawing.Graphics]::FromImage($sheet);$g.InterpolationMode='HighQualityBicubic'
$g.Clear([System.Drawing.Color]::Transparent)
foreach($i in 0..5){
  $cell=[System.Drawing.Bitmap]::FromFile("$dir\mcell_T_$i.png")
  # 求内容包围盒
  $minX=400;$minY=448;$maxX=0;$maxY=0
  $bd=$cell.LockBits((New-Object System.Drawing.Rectangle(0,0,400,448)),[System.Drawing.Imaging.ImageLockMode]::ReadOnly,[System.Drawing.Imaging.PixelFormat]::Format32bppArgb)
  $len=$bd.Stride*448; $buf=New-Object byte[] $len
  [System.Runtime.InteropServices.Marshal]::Copy($bd.Scan0,$buf,0,$len)
  $cell.UnlockBits($bd)
  for($y=0;$y -lt 448;$y+=2){for($x=0;$x -lt 400;$x+=2){
    if($buf[($y*$bd.Stride)+($x*4)+3] -gt 8){
      if($x -lt $minX){$minX=$x};if($x -gt $maxX){$maxX=$x}
      if($y -lt $minY){$minY=$y};if($y -gt $maxY){$maxY=$y}
    }}}
  $cw=$maxX-$minX+1;$ch=$maxY-$minY+1
  $fit=232.0; $scale=[Math]::Min($fit/$cw,$fit/$ch)
  $dw=[int]($cw*$scale);$dh=[int]($ch*$scale)
  $dx=[int](128-$dw/2);$dy=[int](138-$dh/2)
  $rx=$i*256+$dx
  $dstR=[System.Drawing.Rectangle]::new($rx,$dy,$dw,$dh)
  $srcR=[System.Drawing.Rectangle]::new($minX,$minY,$cw,$ch)
  $g.DrawImage($cell,$dstR,$srcR,[System.Drawing.GraphicsUnit]::Pixel)
  $cell.Dispose()
}
$g.Flush();$sheet.Save("$unit\sheet_attack.png",[System.Drawing.Imaging.ImageFormat]::Png);$g.Dispose();$sheet.Dispose()
Write-Output "sheet_attack: $((Get-Item "$unit\sheet_attack.png").Length) bytes"
# 2) GIF 256x256 x6 @8fps
$enc=[System.Windows.Media.Imaging.GifBitmapEncoder]::new()
foreach($i in 0..5){
  $cell=[System.Drawing.Bitmap]::FromFile("$dir\mcell_T_$i.png")
  $minX=400;$minY=448;$maxX=0;$maxY=0
  $bd=$cell.LockBits((New-Object System.Drawing.Rectangle(0,0,400,448)),[System.Drawing.Imaging.ImageLockMode]::ReadOnly,[System.Drawing.Imaging.PixelFormat]::Format32bppArgb)
  $len=$bd.Stride*448; $buf=New-Object byte[] $len
  [System.Runtime.InteropServices.Marshal]::Copy($bd.Scan0,$buf,0,$len)
  $cell.UnlockBits($bd)
  for($y=0;$y -lt 448;$y+=2){for($x=0;$x -lt 400;$x+=2){
    if($buf[($y*$bd.Stride)+($x*4)+3] -gt 8){
      if($x -lt $minX){$minX=$x};if($x -gt $maxX){$maxX=$x}
      if($y -lt $minY){$minY=$y};if($y -gt $maxY){$maxY=$y}
    }}}
  $cw=$maxX-$minX+1;$ch=$maxY-$minY+1
  $fit=232.0; $scale=[Math]::Min($fit/$cw,$fit/$ch)
  $dw=[int]($cw*$scale);$dh=[int]($ch*$scale)
  $dx=[int](128-$dw/2);$dy=[int](138-$dh/2)
  $fr=New-Object System.Drawing.Bitmap(256,256,[System.Drawing.Imaging.PixelFormat]::Format32bppPArgb)
  $fg=[System.Drawing.Graphics]::FromImage($fr);$fg.InterpolationMode='HighQualityBicubic'
  $dstR=[System.Drawing.Rectangle]::new($dx,$dy,$dw,$dh)
  $srcR=[System.Drawing.Rectangle]::new($minX,$minY,$cw,$ch)
  $fg.DrawImage($cell,$dstR,$srcR,[System.Drawing.GraphicsUnit]::Pixel)
  $fg.Flush();$fg.Dispose()
  $ms=New-Object System.IO.MemoryStream
  $fr.Save($ms,[System.Drawing.Imaging.ImageFormat]::Bmp)
  $bs=[System.Windows.Media.Imaging.BitmapFrame]::Create($ms)
  $enc.Frames.Add($bs)
  $fr.Dispose();$cell.Dispose()
}
$fs=[System.IO.File]::Create("$dir\_deployed_preview_ww1_mark4.gif")
$enc.Save($fs);$fs.Dispose()
Write-Output "gif: $((Get-Item "$dir\_deployed_preview_ww1_mark4.gif").Length) bytes"
Copy-Item "$dir\_deployed_preview_ww1_mark4.gif" 'F:\godot fair duet\create\phase-war\.godot\unit_review\_deployed_preview_ww1_mark4.gif' -Force
Write-Output 'deployed preview updated'
Write-Output OK
