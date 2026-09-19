# 抓取参考图 第二轮：改用国内可达源
$ErrorActionPreference = 'Continue'
$dir = "design\ui-refs\intel-card"
New-Item -ItemType Directory -Force -Path $dir | Out-Null
$UA = "Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/126.0.0.0 Safari/537.36"

function Save-Url([string]$url, [string]$out) {
  if (Test-Path $out) { Write-Host "SKIP  $out"; return }
  & curl.exe -sSL --max-time 45 -A $UA -o $out $url 2>$null
  if ((Test-Path $out) -and ((Get-Item $out).Length -gt 2500)) {
    Write-Host ("OK    {0} ({1})" -f $out, (Get-Item $out).Length)
  } else {
    if (Test-Path $out) { Remove-Item $out -Force }
    Write-Host "FAIL  $url"
  }
}
function Get-Html([string]$url) { return ((& curl.exe -sSL --max-time 45 -A $UA $url 2>$null) -join "`n") }

Write-Host "=== [1] 炉石卡面 (HearthstoneJSON, 换 enUS/256x) ==="
Save-Url "https://art.hearthstonejson.com/v1/render/latest/enUS/512x/CS2_029.jpg" "$dir\ref01_hearthstone_fireball.jpg"
if (-not (Test-Path "$dir\ref01_hearthstone_fireball.jpg")) {
  Save-Url "https://art.hearthstonejson.com/v1/render/latest/zhCN/256x/CS2_029.jpg" "$dir\ref01_hearthstone_fireball_zh.jpg"
}

Write-Host "=== [2] Wildfrost 卡面渲染 ==="
Save-Url "https://wildfrostwiki.com/Special:FilePath/Baby_Snowbo_Card.png" "$dir\ref03_wildfrost_card.png"

Write-Host "=== [3] biligame wiki 探测 (sts/hs/dd/itb) ==="
foreach ($slug in @("sts","hs","dd","itb")) {
  $j = Get-Html "https://wiki.biligame.com/$slug/api.php?action=query&list=allimages&ailimit=10&format=json"
  if ($j -match 'allimages') {
    Write-Host "  wiki '$slug' 存在:"
    [regex]::Matches($j, '"name":"([^"]+)"') | Select-Object -First 8 | ForEach-Object { Write-Host "    - $($_.Groups[1].Value)" }
  } else { Write-Host "  wiki '$slug' 不存在或无响应" }
}

Write-Host "=== [4] biligame 杀戮尖塔 页面原图 (重击/恶魔形态) ==="
foreach ($t in @(@("重击","sts_bash"), @("恶魔形态","sts_demonform"))) {
  $enc = [uri]::EscapeDataString($t[0])
  $j = Get-Html "https://wiki.biligame.com/sts/api.php?action=query&titles=$enc&prop=pageimages&piprop=original&format=json"
  $u = [regex]::Match($j, '"original":\{"source":"(https[^"]+)"').Groups[1].Value
  if ($u) { $u = $u -replace '\\/','/'; Save-Url $u "$dir\ref02_biligame_$($t[1]).png" } else { Write-Host "  no pageimage: $($t[0])"; Write-Host $j.Substring(0, [Math]::Min(200,$j.Length)) }
}

Write-Host "=== [5] 3loumao 杀戮尖塔UI设计细节 文章配图 ==="
$h = Get-Html "https://game.3loumao.org/760106114"
$imgpat = 'https?://[^"''<>\s]+?\.(?:png|jpg|jpeg|webp)'
$imgs = [regex]::Matches($h, $imgpat) | ForEach-Object { $_.Value } | Where-Object { $_ -notmatch 'logo|icon|avatar|favicon' } | Select-Object -Unique
Write-Host ("  文章图片数: {0}" -f $imgs.Count)
$i = 0
foreach ($u in ($imgs | Select-Object -First 8)) { $i++; $ext = ($u -split '\.')[-1]; Save-Url $u "$dir\ref02_sts_ui_detail_$i.$ext" }

Write-Host "=== [6] TapTap 自制卡牌设计图 ==="
foreach ($m in @(@("701191215172816379","taptap_mainui"), @("696122920249852670","taptap_cardpack"))) {
  $h2 = Get-Html "https://www.taptap.cn/moment/$($m[0])"
  $t2 = [regex]::Matches($h2, 'https://img\.tapimg\.com/[^"''<>\s]+?\.(?:png|jpg|jpeg|webp)[^"''<>\s]*') | ForEach-Object { $_.Value } | Select-Object -Unique
  Write-Host ("  moment {0}: {1} 张" -f $m[0], $t2.Count)
  $i = 0
  foreach ($u in ($t2 | Select-Object -First 3)) { $i++; Save-Url $u "$dir\ref10_$($m[1])_$i.img" }
}

Write-Host "=== [7] GitHub FFT 单位面板参考图 ==="
$h9 = Get-Html "https://github.com/qwang06/rogue-tbs/issues/26"
$g = [regex]::Match(($h9 -replace '\\u0026','&'), 'https://(?:private-user-images|user-images)\.githubusercontent\.com/[^"\\\s]+').Value
if ($g) { $g = $g -replace '&amp;','&'; Save-Url $g "$dir\ref09_fft_unit_panel.img" } else { Write-Host "  issue 里没找到图片链接" }

Write-Host "=== 完成: ==="
Get-ChildItem $dir | Select-Object Name,Length | Format-Table -AutoSize
