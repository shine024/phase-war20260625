# 抓取参考图 第三轮
$ErrorActionPreference = 'Continue'
$dir = "design\ui-refs\intel-card"
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

Write-Host "=== [1] 探测: ali213 / data.jsdelivr / spire-codex ==="
foreach ($u in @("https://3g.ali213.net/gl/html/221623_3.html","https://data.jsdelivr.com/v1/packages/gh/schmich/hearthstone-card-images","https://spire-codex.com/")) {
  $code = & curl.exe -sS -o NUL -w "%{http_code}" --max-time 12 -A $UA -L $u 2>$null
  Write-Host ("  {0} -> {1}" -f $u, $code)
}

Write-Host "=== [2] 知乎《杀戮尖塔》设计拆解 配图 ==="
$h = Get-Html "https://zhuanlan.zhihu.com/p/650859964"
Write-Host ("  html len: {0}" -f $h.Length)
$imgs = [regex]::Matches($h, 'https://pic\d?\.zhimg\.com/[^"''<>\s]+') | ForEach-Object { $_.Value -replace '&amp;','&' } | Select-Object -Unique
$imgs = $imgs | Where-Object { $_ -notmatch '_is' } | Select-Object -First 8
Write-Host ("  zhimg 数: {0}" -f $imgs.Count)
$i = 0
foreach ($u in $imgs) { $i++; Save-Url $u "$dir\ref02_zhihu_sts_$i.img" }

Write-Host "=== [3] 陷阵之志 界面攻略页 配图 ==="
$h2 = Get-Html "https://3g.ali213.net/gl/html/221623_3.html"
Write-Host ("  html len: {0}" -f $h2.Length)
$imgs2 = [regex]::Matches($h2, 'https?://[^"''<>\s]+?\.(?:png|jpg|jpeg)') | ForEach-Object { $_.Value } | Where-Object { $_ -notmatch 'logo|icon' } | Select-Object -Unique -First 6
Write-Host ("  ali213 数: {0}" -f $imgs2.Count)
$i = 0
foreach ($u in $imgs2) { $i++; Save-Url $u "$dir\ref05_itb_ali213_$i.img" }

Write-Host "=== [4] hearthstonejson 文档里的真实 render URL 格式 ==="
$h3 = Get-Html "https://hearthstonejson.com/docs/images.html"
[regex]::Matches($h3, 'https://art\.hearthstonejson\.com[^"''<>\s ]+') | Select-Object -First 6 | ForEach-Object { Write-Host ("  sample: " + $_.Value) }

Write-Host "=== [5] schmich/hearthstone-card-images 仓库文件列表 (jsDelivr) ==="
$j4 = Get-Html "https://data.jsdelivr.com/v1/packages/gh/schmich/hearthstone-card-images"
$ver = [regex]::Match($j4, '"version":"([^"]+)"').Groups[1].Value
Write-Host ("  version: {0}" -f $ver)
if ($ver) {
  $j5 = Get-Html "https://data.jsdelivr.com/v1/packages/gh/schmich/hearthstone-card-images@$ver?structure=flat"
  $files = [regex]::Matches($j5, '"/([^"]+?\.(?:jpg|png))"') | ForEach-Object { $_.Groups[1].Value }
  Write-Host ("  files: {0}" -f $files.Count)
  $files | Select-Object -First 10 | ForEach-Object { Write-Host "    - $_" }
  $pick = $files | Where-Object { $_ -match '(CS2_029|EX1_277|CS2_042)' } | Select-Object -First 1
  if (-not $pick) { $pick = $files | Select-Object -First 1 }
  if ($pick) {
    $u5 = "https://cdn.jsdelivr.net/gh/schmich/hearthstone-card-images@$ver/$pick"
    Write-Host "  pick: $u5"
    Save-Url $u5 "$dir\ref01_hearthstone_card.img"
  }
}

Write-Host "=== [6] spire-codex (STS2 卡图) ==="
$h6 = Get-Html "https://spire-codex.com/rus/images"
$s6 = [regex]::Matches($h6, '(?:src|href)="(https?://[^"]+?\.(?:png|jpg|webp))"') | ForEach-Object { $_.Groups[1].Value } | Select-Object -Unique -First 5
Write-Host ("  候选: {0}" -f $s6.Count)
$s6 | ForEach-Object { Write-Host "    - $_" }

Write-Host "=== 完成: ==="
Get-ChildItem $dir | Select-Object Name,Length | Format-Table -AutoSize
