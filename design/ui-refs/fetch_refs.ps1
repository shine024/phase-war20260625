# 抓取“卡牌/情报面板”优秀参考图（一次性脚本）
# 输出目录: design/ui-refs/intel-card/
$ErrorActionPreference = 'Continue'
$dir = "design\ui-refs\intel-card"
New-Item -ItemType Directory -Force -Path $dir | Out-Null
$UA = "Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/126.0.0.0 Safari/537.36"

function Save-Url([string]$url, [string]$out) {
  if (Test-Path $out) { Write-Host "SKIP  $out"; return $true }
  Write-Host "GET   $url"
  & curl.exe -sSL --max-time 60 -A $UA -o $out $url 2>$null
  if ((Test-Path $out) -and ((Get-Item $out).Length -gt 3000)) {
    Write-Host ("OK    {0} ({1} bytes)" -f $out, (Get-Item $out).Length)
    return $true
  }
  if (Test-Path $out) { Remove-Item $out -Force }
  Write-Host "FAIL  $out"
  return $false
}

function Get-Html([string]$url) {
  return ((& curl.exe -sSL --max-time 60 -A $UA $url 2>$null) -join "`n")
}

function Grab([string]$text, [string]$pattern, [int]$idx = 1) {
  $m = [regex]::Match($text, $pattern)
  if ($m.Success -and $m.Groups.Count -gt $idx) { return $m.Groups[$idx].Value }
  return $null
}

Write-Host "=== [1] 炉石传说 火球术 (HearthstoneJSON 渲染) ==="
Save-Url "https://art.hearthstonejson.com/v1/render/latest/zhCN/512x/CS2_029.jpg" "$dir\ref01_hearthstone_火球术.jpg"

Write-Host "=== [2] 杀戮尖塔 卡面 ==="
Save-Url "https://slay-the-spire.fandom.com/wiki/Special:FilePath/Bash.png" "$dir\ref02_sts_重击.png"
Save-Url "https://slay-the-spire.fandom.com/wiki/Special:FilePath/Demon_Form.png" "$dir\ref02b_sts_恶魔形态.png"

Write-Host "=== [3] Wildfrost 卡面 (wiki 全图片列表探测) ==="
$j = Get-Html "https://wildfrostwiki.com/api.php?action=query&list=allimages&ailimit=20&format=json"
$names = [regex]::Matches($j, '"name":"([^"]+?\.png)"') | ForEach-Object { $_.Groups[1].Value } | Select-Object -First 20
$names | ForEach-Object { Write-Host "  wf candidate: $_" }
$wfPick = $names | Where-Object { $_ -notmatch '^(Icon|UI|Status|Cardback)' } | Select-Object -First 1
if ($wfPick) {
  $enc = [uri]::EscapeDataString($wfPick)
  Save-Url "https://wildfrostwiki.com/Special:FilePath/$enc" "$dir\ref03_wildfrost_卡.png"
}

Write-Host "=== [4] Monster Train 卡面 (fandom 探测) ==="
$mtJson = $null
foreach ($host2 in @("https://monster-train.fandom.com","https://monstertrain.fandom.com")) {
  $j2 = Get-Html "$host2/api.php?action=query&list=allimages&ailimit=40&format=json"
  if ($j2 -match 'allimages') { $mtJson = $j2; Write-Host "  MT wiki = $host2"; break }
}
if ($mtJson) {
  $mtn = [regex]::Matches($mtJson, '"name":"([^"]+?\.png)"') | ForEach-Object { $_.Groups[1].Value }
  $mtn | ForEach-Object { Write-Host "  mt candidate: $_" }
  $mtPick = $mtn | Where-Object { $_ -match '(?i)card|unit|champion' } | Select-Object -First 1
  if ($mtPick) {
    $enc2 = [uri]::EscapeDataString($mtPick)
    Save-Url "https://monster-train.fandom.com/wiki/Special:FilePath/$enc2" "$dir\ref04_monstertrain_卡.png"
  }
}

Write-Host "=== [5] Into the Breach 商店截图(含单位情报面板) ==="
$html5 = Get-Html "https://store.steampowered.com/app/590380/Into_the_Breach/"
$ss = [regex]::Matches($html5, 'https://shared[^"]*?/apps/590380/[^"]*?ss_[a-f0-9]{6,}\.jpg') | ForEach-Object { $_.Value } | Select-Object -Unique -First 3
$i = 0
foreach ($u in $ss) { $i++; Save-Url $u "$dir\ref05_itb_战斗_$i.jpg" }

Write-Host "=== [6] Darkest Dungeon 商店截图(角色属性面板) ==="
$html6 = Get-Html "https://store.steampowered.com/app/262110/Darkest_Dungeon/"
$ss6 = [regex]::Matches($html6, 'https://shared[^"]*?/apps/262110/[^"]*?ss_[a-f0-9]{6,}\.jpg') | ForEach-Object { $_.Value } | Select-Object -Unique -First 3
$i = 0
foreach ($u in $ss6) { $i++; Save-Url $u "$dir\ref06_dd_角色面板_$i.jpg" }

Write-Host "=== [7/8] Dribbble 卡牌 UI 概念图 ==="
foreach ($shot in @(@("17319636", "ref07_dribbble_gameero"), @("27620881", "ref08_dribbble_mobilecard"))) {
  $h = Get-Html "https://dribbble.com/shots/$($shot[0])"
  $img = Grab $h 'property="og:image" content="([^"]+)"'
  if (-not $img) { $img = Grab $h 'content="(https://cdn\.dribbble\.com[^"]+)"' }
  if ($img) { $img = $img -replace '&amp;','&'; Save-Url $img "$dir\$($shot[1]).jpg" }
  else { Write-Host "FAIL  dribbble og:image $($shot[0])" }
}

Write-Host "=== [9] FFT 风格战场单位面板 (GitHub issue 参考图) ==="
$h9 = Get-Html "https://github.com/qwang06/rogue-tbs/issues/26"
$h9 = $h9 -replace '\\u0026','&'
$g1 = Grab $h9 'https://private-user-images\.githubusercontent\.com/[^"\\\s]+'
$g2 = Grab $h9 'https://user-images\.githubusercontent\.com/[^"\\\s]+'
if ($g1) { $g1 = $g1 -replace '&amp;','&'; Save-Url $g1 "$dir\ref09_fft_unit_panel.jpg" }
elseif ($g2) { $g2 = $g2 -replace '&amp;','&'; Save-Url $g2 "$dir\ref09_fft_unit_panel.jpg" }
else { Write-Host "FAIL  github issue 图片" }

Write-Host "=== 完成，目录内容: ==="
Get-ChildItem $dir | Select-Object Name,Length | Format-Table -AutoSize
