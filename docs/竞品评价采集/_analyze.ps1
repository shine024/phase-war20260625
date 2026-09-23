# 竞品评价采集 · 合并 / 正负划分 / 主题统计 脚本（幂等可重跑）
# 用法: pwsh -File _analyze.ps1   （在本目录 docs/竞品评价采集/ 下运行）
# 输入: raw/*.jsonl （每行一条评论 JSON，字段见 README 数据字典）
# 输出: reviews_all.jsonl / reviews_positive.jsonl / reviews_negative.jsonl
#       _stats.json / _quotes_pos.txt / _quotes_neg.txt （并打印摘要）
$ErrorActionPreference = 'Stop'
$root = $PSScriptRoot
$raw  = Join-Path $root 'raw'

# ---------- 1. 读取 + 去重合并 ----------
$all  = [System.Collections.Generic.List[object]]::new()
$seen = [System.Collections.Generic.HashSet[string]]::new([System.StringComparer]::Ordinal)
foreach ($f in (Get-ChildItem $raw -Filter *.jsonl -ErrorAction SilentlyContinue)) {
    $n = 0
    foreach ($line in (Get-Content $f.FullName -Encoding UTF8)) {
        if ([string]::IsNullOrWhiteSpace($line)) { continue }
        try { $o = $line | ConvertFrom-Json } catch { Write-Warning "JSON 解析失败 $($f.Name): $($line.Substring(0,[Math]::Min(80,$line.Length)))"; continue }
        $key = "$($o.game)#$($o.id)"
        if (-not $seen.Add($key)) { continue }
        $all.Add($o) | Out-Null; $n++
    }
    Write-Host ("  读取 {0,-22} {1,4} 条" -f $f.Name, $n)
}
Write-Host ("合并去重后总计: {0} 条" -f $all.Count)

# ---------- 2. 划分 正/负 并落盘 ----------
$pos = $all | Where-Object { $_.voted_up -eq $true }
$neg = $all | Where-Object { $_.voted_up -eq $false }
$utf8 = New-Object System.Text.UTF8Encoding($false)   # 无 BOM；兼容 Windows PowerShell 5.1 与 pwsh 7（5.1 不认 -Encoding utf8NoBOM）
function Convert-ToLines($rows) { @($rows | ForEach-Object { [string]($_ | ConvertTo-Json -Compress -Depth 4) }) }
[System.IO.File]::WriteAllLines((Join-Path $root 'reviews_all.jsonl'),      [string[]](Convert-ToLines $all), $utf8)
[System.IO.File]::WriteAllLines((Join-Path $root 'reviews_positive.jsonl'), [string[]](Convert-ToLines @($pos)), $utf8)
[System.IO.File]::WriteAllLines((Join-Path $root 'reviews_negative.jsonl'), [string[]](Convert-ToLines @($neg)), $utf8)

# ---------- 3. 按游戏统计 ----------
$gameStats = $all | Group-Object game | ForEach-Object {
    $g = $_.Group
    $p = ($g | Where-Object voted_up -eq $true).Count
    $e = ($g | Where-Object lang -eq 'schinese').Count
    $negH = ($g | Where-Object { $_.voted_up -eq $false } | Measure-Object hours -Average).Average
    $posH = ($g | Where-Object { $_.voted_up -eq $true  } | Measure-Object hours -Average).Average
    [pscustomobject]@{
        game = $_.Name; total = $g.Count; positive = $p; negative = ($g.Count - $p)
        pos_pct = [math]::Round(100 * $p / $g.Count, 1)
        schinese = $e
        avg_hours_neg = if ($negH) { [math]::Round($negH, 0) } else { 0 }
        avg_hours_pos = if ($posH) { [math]::Round($posH, 0) } else { 0 }
    }
}

# ---------- 4. 主题关键词归类（一条评论命中某类只计一次） ----------
$themes = [ordered]@{
    # —— 负面侧 ——
    'N平衡/数值'   = '平衡|失衡|数值|太强|过强|削弱|加强.{0,3}(过头|太)|imbalanc|unbalanced|overpowered|needs? (a )?nerf|balance'
    'N随机/运气'   = '随机|概率|运气|RNG|rng|luck|luckbased|random'
    'N商业化/氪金' = '氪|抽卡|付费|内购|收费|收钱|定价|退款|pay.?to.?win|p2w|microtransaction|monetiz|gacha|greed|refund|predatory'
    'N内容量/更新' = '内容(少|不足|单薄|匮乏)|没内容|无内容|更新慢|更新.{0,4}(慢|少)|lack of content|content (is )?(thin|shallow|lacking)|not enough content|runs out of content|update.{0,6}slow'
    'N技术质量'    = '闪退|崩溃|卡顿|掉帧|优化|发热|bug|crash|lag|stutter|freez|perform|optimiz|broken'
    'N乏味/重复'   = '无聊|枯燥|乏味|重复|玩腻|厌倦|boring|repetitiv|tedious|grind|monoton|stale|late.?game|end.?game|后期'
    'N上手门槛'    = '劝退|上手难|上手门槛|门槛高|新手(不友好|教程)|引导(差|乱|不清)|看不懂|tutorial|steep|onboard|hard to (get into|understand)|confus'
    'NPVP/外挂'    = '外挂|开挂|匹配|演员|演员|cheater|hacker|matchmak|smurf|toxic|sweat'
    'N本地化'      = '翻译|机翻|中文(不全|烂|差|没)|本地化|localiz|translat|english (version|text)|no english'
    'N2停更/弃坑'  = '弃坑|停更|不更新|没更新|弃养|鬼服|abandon|dead.?game|no (more )?updates?|stopped updating|uninstall'
    'N2重复/腻宽'  = '重复|玩腻|boring|repetitiv|tedious|stale|samey|gets old'
    'N2平衡宽'     = '平衡|失衡|数值|太强|过强|削弱|imbalanc|unbalanc|overpowered|nerf|counter'
    'N2数值膨胀'   = '数值膨胀|通货膨胀|inflat|power.?creep|numbers go up'
    'N2UI/可读性'  = '\bUI\b|界面|看不清|可读|clutter|unreadable|small text|hard to read'
    'N2难度曲线'   = '难度|卡关|过不去|太难|difficulty (spike|curve)|too hard|stuck|a wall'
    # —— 正面侧 ——
    'P上瘾/停不下' = '上头|停不下|中毒|沉迷|再来一(把|局)|addict|hooked|one more|can.?t stop|just one'
    'P构筑/流派'   = '构筑|流派|build|组合|套路|synerg|combo|deck|配装|搭配|draft'
    'P策略/战术'   = '策略|战术|烧脑|思考|strategy|tactic|brain|think'
    'P性价比'      = '便宜|性价比|值(得|回)|价格|良心价|cheap|worth|price|sale|discount'
    'P视听表现'    = '美术|画面|音乐|音效|像素|风格|art|music|sound|visual|aesthetic|soundtrack'
    'P放置/挂机'   = '放置|挂机|idle|afk|background|passive'
    'P更新/开发者' = '更新(勤|快|及时|用心)|开发者|制作组|响应|倾听|dev(s)? (are|is)|developer|support|listening'
    'P泛好评'      = '好玩|有趣|推荐|神作|喜欢|fun|great|amazing|recommend|love|gem|best'
}
function Count-Themes($reviews, [string[]]$keys) {
    $out = [ordered]@{}
    foreach ($k in $keys) {
        $rx = $themes[$k]
        $hit = @($reviews | Where-Object { $_.review -match $rx }).Count   # @() 包裹：单条命中时标量无 .Count（PS5.1 会得 null）
        $out[$k] = @{ hits = $hit; pct = if ($reviews.Count) { [math]::Round(100 * $hit / $reviews.Count, 1) } else { 0 } }
    }
    return $out
}
$themeStats = @{
    sample_total = $all.Count
    positive = Count-Themes @($pos) @($themes.Keys | Where-Object { $_ -like 'P*' })
    negative = Count-Themes @($neg) @($themes.Keys | Where-Object { $_ -like 'N*' })
}

# ---------- 5. 高赞摘录（供人工阅读，正/负各 12 条） ----------
$quote = {
    param($set, $path, $label)
    $top = $set | Sort-Object @{e='votes_up';Descending=$true}, @{e='hours';Descending=$true} | Select-Object -First 12
    $lines = foreach ($t in $top) {
        "[{0} | {1}赞 | {2}h | {3}] {4}" -f $t.game, $t.votes_up, $t.hours, $t.date, $t.review
    }
    [System.IO.File]::WriteAllText($path, (("# {0}（按 votes_up 排序，前12）`r`n" -f $label) + ($lines -join "`r`n")), $utf8)
}
& $quote $pos (Join-Path $root '_quotes_pos.txt') '正面高赞摘录'
& $quote $neg (Join-Path $root '_quotes_neg.txt') '负面高赞摘录'

# ---------- 6. 汇总输出 ----------
$stats = [pscustomobject]@{
    generated_at = (Get-Date -Format 'yyyy-MM-dd HH:mm')
    sample = @{ total = $all.Count; positive = $pos.Count; negative = $neg.Count
                pos_pct = [math]::Round(100 * $pos.Count / [math]::Max(1,$all.Count), 1)
                schinese = ($all | Where-Object lang -eq 'schinese').Count }
    by_game = $gameStats
    themes  = $themeStats
}
[System.IO.File]::WriteAllText((Join-Path $root '_stats.json'), ($stats | ConvertTo-Json -Depth 6), $utf8)
$stats | ConvertTo-Json -Depth 6
