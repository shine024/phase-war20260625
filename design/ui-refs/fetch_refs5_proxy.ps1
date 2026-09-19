# 抓取参考图 第五轮：代理全通收网
$ErrorActionPreference = 'Continue'
$dir = "design\ui-refs\intel-card"
$UA = "Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/126.0.0.0 Safari/537.36"
$P = "http://127.0.0.1:10808"

function Save-Url([string]$url, [string]$out, [string]$ref = "") {
  if (Test-Path $out) { Write-Host "SKIP  $out"; return }
  $args = @("-sSL","--ssl-no-revoke","--proxy",$P,"--max-time","60","-A",$UA,"-o",$out)
  if ($ref) { $args += @("-e",$ref) }
  $args += $url
  & curl.exe @args 2>$null
  if ((Test-Path $out) -and ((Get-Item $out).Length -gt 4000)) { Write-Host ("OK    {0} ({1})" -f (Split-Path $out -Leaf), (Get-Item $out).Length) }
  else { if (Test-Path $out) { Remove-Item $out -Force }; Write-Host "FAIL  $url" }
}
function Get-Html([string]$url, [string]$ref = "") {
  $args = @("-sSL","--ssl-no-revoke","--proxy",$P,"--max-time","60","-A",$UA)
  if ($ref) { $args += @("-e",$ref) }
  $args += $url
  return ((& curl.exe @args 2>$null) -join "`n")
}

Write-Host "=== [A] 杀戮尖塔 卡面 (fandom api -> static.wikia 直链) ==="
$j = Get-Html "https://slay-the-spire.fandom.com/api.php?action=query&titles=File:Bash.png%7CFile:Demon_Form.png&prop=imageinfo&iiprop=url&format=json"
Write-Host ("  api len: " + $j.Length)
$urls = [regex]::Matches(($j -replace '\\\/','/'), '"url":"(https://static\.wikia\.nocookie\.net[^"]+)"') | ForEach-Object { $_.Groups[1].Value }
$urls = $urls | Select-Object -Unique
Write-Host ("  直链数: " + $urls.Count)
$i = 0
foreach ($u in $urls) { $i++; Save-Url $u "$dir\12_杀戮尖塔_卡面_$i.png" "https://slay-the-spire.fandom.com/" }

Write-Host "=== [B] Monster Train 卡面 (allimages 直链) ==="
$j2 = Get-Html "https://monster-train.fandom.com/api.php?action=query&list=allimages&ailimit=100&format=json"
$mtAll = [regex]::Matches(($j2 -replace '\\\/','/'), '"name":"([^"]+?)","timestamp[^}]*?"url":"(https[^"]+)"')
Write-Host ("  全部图片: " + $mtAll.Count)
$mtAll | Select-Object -First 12 | ForEach-Object { Write-Host ("    - " + $_.Groups[1].Value) }
$mtPick = $mtAll | Where-Object { $_.Groups[1].Value -match '(?i)card' } | Select-Object -First 2
$i = 0
foreach ($m in $mtPick) { $i++; Save-Url ($m.Groups[2].Value -replace '\\/','/') "$dir\13_monstertrain_卡面_$i.png" "https://monster-train.fandom.com/" }

Write-Host "=== [C] Dribbble og:image ==="
foreach ($shot in @(@("17319636","14_dribbble_卡牌概念_Gameero"), @("27620881","14b_dribbble_卡牌概念_mobile"))) {
  $h = Get-Html "https://dribbble.com/shots/$($shot[0])"
  Write-Host ("  shot $($shot[0]) html len: " + $h.Length)
  $img = [regex]::Match($h, 'property="og:image" content="([^"]+)"').Groups[1].Value
  if ($img) { $img = $img -replace '&amp;','&'; Save-Url $img "$dir\$($shot[1]).jpg" "https://dribbble.com/" }
  else { Write-Host ("  og:image 未取到(可能202反爬)，稍后用浏览器") }
}

Write-Host "=== [D] Steam 官方截图 ==="
foreach ($g in @(@("590380","15_steam_陷阵之志"), @("262110","15b_steam_暗黑地牢"))) {
  $h3 = Get-Html "https://store.steampowered.com/app/$($g[0])/"
  $ss = [regex]::Matches($h3, 'https://shared[^"''<>\s]+?/apps/' + $g[0] + '/[^"''<>\s]*?ss_[a-f0-9]{6,}\.jpg') | ForEach-Object { $_.Value } | Select-Object -Unique
  Write-Host ("  {0}: 截图数 {1}" -f $g[1], $ss.Count)
  $i = 0
  foreach ($u in ($ss | Select-Object -First 2)) { $i++; Save-Url $u "$dir\$($g[1])_$i.jpg" "https://store.steampowered.com/" }
}

Write-Host "=== [E] UI中国 依露希尔套图 ==="
$ok = 0
foreach ($id in 4518604..4518668) {
  if ($ok -ge 8) { break }
  $s = [string]$id; $tail = $s.Substring($s.Length-3)
  $pp = "https://img.ui.cn/data/file/{0}/{1}/{2}/{3}.png" -f $tail[2], $tail[1], $tail[0], $id
  $out = "$dir\16_uiCN_依露希尔_{0}.png" -f ($id - 4518603)
  & curl.exe -sSL -k --ssl-no-revoke --proxy $P --max-time 40 -A $UA -e "https://www.ui.cn/" -o $out $pp 2>$null
  if ((Test-Path $out) -and ((Get-Item $out).Length -gt 20000)) { $ok++; Write-Host ("OK    " + (Split-Path $out -Leaf)) }
  else { if (Test-Path $out) { Remove-Item $out -Force } }
}
Write-Host ("  依露希尔成功: $ok 张")

Write-Host "=== 完成: ==="
Get-ChildItem $dir | Select-Object Name,Length | Format-Table -AutoSize