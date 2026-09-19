# 抓取参考图 第四轮：走代理补齐被墙源
$ErrorActionPreference = 'Continue'
$dir = "design\ui-refs\intel-card"
$UA = "Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/126.0.0.0 Safari/537.36"

Write-Host "=== 代理自动探测 ==="
$PROXY = $null
foreach ($p in @("http://127.0.0.1:10808","socks5h://127.0.0.1:10808","http://127.0.0.1:10809","http://127.0.0.1:7890","socks5h://127.0.0.1:7890","http://127.0.0.1:7897")) {
  $c = & curl.exe -sS -o NUL -w "%{http_code}" --ssl-no-revoke --proxy $p --max-time 12 "https://slay-the-spire.fandom.com/wiki/Bash" 2>$null
  Write-Host ("  {0} -> {1}" -f $p, $c)
  if ($c -eq "200") { $PROXY = $p; break }
}
if (-not $PROXY) { Write-Host "所有候选代理均不可用，退出"; exit }
Write-Host ("使用代理: " + $PROXY)

function Save-Url([string]$url, [string]$out) {
  if (Test-Path $out) { Write-Host "SKIP  $out"; return }
  & curl.exe -sSL --ssl-no-revoke --proxy $PROXY --max-time 60 -A $UA -o $out $url 2>$null
  if ((Test-Path $out) -and ((Get-Item $out).Length -gt 4000)) { Write-Host ("OK    {0} ({1})" -f (Split-Path $out -Leaf), (Get-Item $out).Length) }
  else { if (Test-Path $out) { Remove-Item $out -Force }; Write-Host "FAIL  $url" }
}
function Get-Html([string]$url) { return ((& curl.exe -sSL --ssl-no-revoke --proxy $PROXY --max-time 60 -A $UA $url 2>$null) -join "`n") }

Write-Host "=== [A] 杀戮尖塔 卡面 (fandom 渲染) ==="
Save-Url "https://slay-the-spire.fandom.com/wiki/Special:FilePath/Bash.png" "$dir\12_杀戮尖塔_卡面_重击.png"
Save-Url "https://slay-the-spire.fandom.com/wiki/Special:FilePath/Demon_Form.png" "$dir\12b_杀戮尖塔_卡面_恶魔形态.png"

Write-Host "=== [B] Monster Train 卡面探测 ==="
$mtJson = $null; $mtHost = $null
foreach ($h2 in @("https://monster-train.fandom.com","https://monstertrain.fandom.com")) {
  $j2 = Get-Html "$h2/api.php?action=query&list=allimages&ailimit=50&format=json"
  if ($j2 -match 'allimages') { $mtJson = $j2; $mtHost = $h2; Write-Host "  MT wiki = $h2"; break }
}
if ($mtJson) {
  $mtn = [regex]::Matches($mtJson, '"name":"([^"]+?\.png)"') | ForEach-Object { $_.Groups[1].Value }
  $mtn | Select-Object -First 15 | ForEach-Object { Write-Host "    - $_" }
  $mtPick = $mtn | Where-Object { $_ -match '(?i)card' } | Select-Object -First 2
  $i = 0
  foreach ($pick in $mtPick) { $i++; $enc = [uri]::EscapeDataString($pick); Save-Url "$mtHost/wiki/Special:FilePath/$enc" "$dir\13_monstertrain_卡面_$i.png" }
  if (-not $mtPick) { $p1 = $mtn | Where-Object { $_ -notmatch '(?i)icon|wiki|site' } | Select-Object -First 1; if ($p1) { $enc = [uri]::EscapeDataString($p1); Save-Url "$mtHost/wiki/Special:FilePath/$enc" "$dir\13_monstertrain_卡面_1.png" } }
}

Write-Host "=== [C] Dribbble 概念图 (og:image) ==="
foreach ($shot in @(@("17319636","14_dribbble_卡牌概念_Gameero"), @("27620881","14b_dribbble_卡牌概念_mobile"))) {
  $h = Get-Html "https://dribbble.com/shots/$($shot[0])"
  $img = [regex]::Match($h, 'property="og:image" content="([^"]+)"').Groups[1].Value
  if (-not $img) { $img = [regex]::Match($h, 'content="(https://cdn\.dribbble\.com[^"]+)"').Groups[1].Value }
  if ($img) { $img = $img -replace '&amp;','&'; Save-Url $img "$dir\$($shot[1]).jpg" }
  else { Write-Host ("  FAIL og:image " + $shot[0] + " (html len " + $h.Length + ")") }
}

Write-Host "=== [D] Steam 官方截图 ==="
foreach ($g in @(@("590380","15_steam_陷阵之志"), @("262110","15b_steam_暗黑地牢"))) {
  $h3 = Get-Html "https://store.steampowered.com/app/$($g[0])/"
  Write-Host ("  store html len: " + $h3.Length)
  $ss = [regex]::Matches($h3, 'https://shared[^"''<>\s]+?/apps/' + $g[0] + '/[^"''<>\s]*?ss_[a-f0-9]{6,}\.jpg') | ForEach-Object { $_.Value } | Select-Object -Unique
  Write-Host ("  截图数: " + $ss.Count)
  $i = 0
  foreach ($u in ($ss | Select-Object -First 2)) { $i++; Save-Url $u "$dir\$($g[1])_$i.jpg" }
}

Write-Host "=== [E] UI中国 依露希尔套图 (证书走代理重试) ==="
$i = 0
foreach ($id in @(4518604, 4518626, 4518627, 4518640, 4518645, 4518650)) {
  $i++
  $s = [string]$id; $tail = $s.Substring($s.Length-3)
  $pp = "{0}/{1}/{2}/{3}.png" -f $tail[2], $tail[1], $tail[0], $id
  & curl.exe -sSL -k --ssl-no-revoke --proxy $PROXY --max-time 40 -A $UA -e "https://www.ui.cn/" -o "$dir\16_uiCN_依露希尔_$i.png" "https://img.ui.cn/data/file/$pp" 2>$null
  if ((Test-Path "$dir\16_uiCN_依露希尔_$i.png") -and ((Get-Item "$dir\16_uiCN_依露希尔_$i.png").Length -gt 8000)) { Write-Host ("OK    16_uiCN_依露希尔_$i.png") }
  else { if (Test-Path "$dir\16_uiCN_依露希尔_$i.png") { Remove-Item "$dir\16_uiCN_依露希尔_$i.png" -Force }; Write-Host "FAIL  $id" }
}

Write-Host "=== 完成: ==="
Get-ChildItem $dir | Select-Object Name,Length | Format-Table -AutoSize