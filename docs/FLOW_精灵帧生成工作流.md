# Flow (Nano Banana) 精灵帧生成工作流

> 用 Google Flow（flow.google.com，Nano Banana 2.1）图生图产出单位攻击六宫格，本地后期成透明帧并部署。
> 实战：ww1_mark4（马克IV，2026-10-08 全流程跑通）；ww1_105mm R 版（同尺寸模板+全容纳缩放+反冲微动，同日，见 §7）。脚本存于 `tools/flow_sprite_pipeline/`，105mm 版在 `.godot/unit_review/flow_105mm/`。

## 0. 适用范围与产物

- **输入**：现役单位资产（卡图 + `assets/effects/unit_anims/<unit>/sheet_idle.png` + `anim.json`）
- **输出**：
  - `assets/effects/unit_anims/<unit>/sheet_attack.png`（6 帧 × frame_size，透明底）
  - `assets/card_icons/player/<unit>.png` + `_thumb384` + `_thumb256`（可选用新待机替换）
  - `.godot/unit_review/_deployed_preview_<unit>.gif`（256²×6 预览）
  - `.godot/unit_review/flow_<unit>/compare_<unit>.html`（新旧对比页）
- **约束**：产物只落 `.godot/unit_review/` 暂存，部署前逐项目验；`anim.json`（fps/frame_size/counts）不改。

## 1. 前置环境

| 组件 | 说明 |
|---|---|
| Flow 账号 | wuowuming@gmail.com（daguange），Chrome 配置目录 `%LOCALAPPDATA%\dsh-chrome-flow` 已登录 |
| 调试 Chrome | `chrome.exe --remote-debugging-port=9222 --user-data-dir=$env:LOCALAPPDATA\dsh-chrome-flow --no-first-run https://flow.google.com/`（Start-Process 异步拉起，先探 `http://127.0.0.1:9222/json/version`） |
| agent-browser | `$env:APPDATA\npm\node_modules\agent-browser\bin\agent-browser-win32-x64.exe`（直调 exe，勿走 npm shim / `cmd /c`） |

**agent-browser 唯一可用调用姿势**（管道/重定向会触发 Rust exe 的 stdout 编码崩溃或命名管道 EPERM）：

```powershell
$AB="$env:APPDATA\npm\node_modules\agent-browser\bin\agent-browser-win32-x64.exe"
$o="$env:TEMP\ab_out.txt"; $e="$env:TEMP\ab_err.txt"
& $AB connect 9222 2>&1 | Out-Null
Start-Process -FilePath $AB -ArgumentList @('eval','<js>') -NoNewWindow -Wait -PassThru `
  -RedirectStandardOutput $o -RedirectStandardError $e | Out-Null
Get-Content $o -Raw; Get-Content $e -Raw
```

- 目标 tab 用 `tab <n>` 切换（`tab select` 语法不存在）；eval 可能打到残留 about:blank。
- **JS 引号**：argv 会剥双引号 → JS 一律用 pwsh 双写单引号 `''`，避免 `\n` join。
- **带空格路径**作 CLI 参数会被拆词 → screenshot 等落盘参数用无空格临时路径（`$env:TEMP\...`）。
- 页面被原生文件对话框阻塞时 CDP 页面级命令超时（os error 10060）而 browser 级 `/json/version` 仍通；用 WScript `AppActivate`+`SendKeys '{ESC}'` 解（AppActivate 常失败，备用 `SetForegroundWindow`+`keybd_event ALT` 解前台锁）。
- **2026-10-09 补充**：调用约束的本质是「**不捕获输出**」——`$x=&$AB`、`2>&1`、函数内调用（输出进管道即捕获）都会触发 `StandardOutputEncoding/StandardErrorEncoding is only supported when standard output is redirected`；顶层裸语句 + `cmd /s /c "`"$AB`" args > 文件 2>&1"` 再 `Get-Content` 同样稳（cmd 内部重定向不算捕获，`cmd /s /c` 走 npm shim 也没问题）。snapshot 的 ref 每次漂移须现取（正则 `'.*ref=(e\d+).*'`，ref 前常带 expanded=false 不能写 `\[ref=`）。`type` 进不了 ProseMirror contenteditable（✓ Done 但文本不落），改 eval `document.execCommand('insertText',false,text)`；JS 串避免空格与双引号（argv 剥引号拆词）：词数组 `['Remove','the',…].join(String.fromCharCode(32))` 拼句子。

## 2. 生成路线：图生图（i2i）六宫格 —— 唯一可靠路线

纯文生图两次翻车：v1 画成 3×3 九格且六辆坦克形态互不一致；强化网格提示词 v2 直接生成失败（未扣费）。**必须用底稿锁定布局与形态。**

### 2.1 底稿模板制作

1. 文生图一张参考图（提示词见 `tools/flow_sprite_pipeline/prompt_t2i_首图.txt`），从其**单格**裁出坦克（如 v1 格(1,1) 裁 `rect(4,4,450,248)`）。
2. 缩放置于 3:2 画布（3072×2048），2 行 × 3 列，每格 1024²，格间距留白 ~130px，白底。
3. **朝向校验**：底稿坦克必须与目标朝向一致（本项目=面朝正左）。若源图朝右，整幅水平镜像：`TranslateTransform(W,0)+ScaleTransform(-1,1)`。i2i 会忠实继承底稿朝向，此步不可省。
4. 产物：`<unit>_grid_template_L.png`。

### 2.2 底稿入 Flow（重要坑）

> **2026-10-09 更新**：下面前两条坑已不复现——「上传媒体内容」点击后 DOM 会出现 `input[type=file]`（accept=.png,.jpg,.jpeg,.webp,.gif,.heif,.heic,.mp4…），`upload "input[type=file]" <绝对路径>` 一步成功，不再开原生对话框阻塞；上传成功判据=左栏出现资产卡「<文件名> 已上传的图片」。**挂接到提示词最简路径**：「添加素材」→「上传的内容」tab → 资源列表 listbox **直接点 option 即挂接**（无需再点「添加到提示」；点后面板自动关，提示框旁出现「素材」+「清除提示」按钮）。

- ~~❌ 素材面板「上传媒体内容」会开原生文件对话框阻塞页面~~（2026-10-09 已可正常使用）；
- ~~❌ `input[type=file]` 隐藏元素 CDP 查不到（DOM.querySelectorAll 返回 0），setFileInputFiles 报 Invalid parameters~~（2026-10-09 点击「上传媒体内容」后即可查到并 upload 成功；直接 upload 到「添加素材」按钮仍报 CDP Node is not a file input element）；
- ❌ Page.setInterceptFileChooserDialog 拦不到 fileChooserOpened 事件；
- ❌ agent-browser 的 `press Control+v` 是 CDP 合成键，进不了 contenteditable；
- ✅ **首选：合成 DragEvent drop**（105mm R 版实测稳定复现）——本地 HttpListener 供文件（GET /t.png）+ 页面 eval 合成 drop：

```js
(async()=>{ const inp=document.querySelector('div[contenteditable="true"]');
  const r=await fetch('http://127.0.0.1:8791/t.png'); const b=await r.blob();
  const f=new File([b],'template.png',{type:'image/png'});
  const dt=new DataTransfer(); dt.items.add(f);
  inp.dispatchEvent(new DragEvent('drop',{dataTransfer:dt,bubbles:true,cancelable:true})); })()
```

  成功判据是 composer 旁出现「素材」缩略块（勿以 blob img 数判断）；配套 POST /save 收成品、GET /ping 探活。
- ✅ 备用：STA 子进程写真位图入剪贴板 → Chrome 前台 → 真键盘 ^v：

```powershell
# 1) STA 子进程写位图（Set-Clipboard -Value 会把 Image 写成文本，作废）
$enc = <base64 of: Add-Type System.Windows.Forms; [System.Windows.Forms.Clipboard]::SetImage($img)>
& pwsh -STA -NoProfile -EncodedCommand $enc
# 2) Chrome 前台 + 真键盘粘贴
SetForegroundWindow(chrome主窗口) + keybd_event(ALT down/up) + WScript SendKeys '^v'
# 3) 成功判据：左栏「上传的内容」+ 资产卡「image.png 3072x2048」+ 提示框出现「素材」「清除提示」按钮
```

> 实战备注：此姿势时序敏感、复现率不稳；若失败，走 Flow 会话内已上传素材的资产选择器（「添加素材」→ 资产列表点选 → 「添加到提示」），项目内素材会永久留存，一次上传反复可用。

### 2.3 i2i 提示词模板（核心）

```
底稿为 2 行 3 列六格同一坦克待机姿态。要求：
1. 布局留白白底完全不变；坦克如复制粘贴，绝不移动/缩放/重绘/增减部件；
2. 仅按帧序在炮口（车体侧面中部高度、朝画面左侧）加特效：
   格1 待机无特效；格2 橙黄小星光点蓄力；格3 大橙白炮口焰短促向左；
   格4 衰减变小变暗；格5 无火光灰白硝烟向左飘；格6 回待机；
3. 绝不弹道/弹丸/光束/文字/边框/序号/辅助线，绝不发黑发棕；
4. 特效只出现在炮口附近，绝不改变部件组成，全部面朝正左。
```

### 2.4 生成、轮询、下载

- 点开始生成后每 ~13s eval 轮询 `document.images`，出现**新的 flow-content 或 flow.google.com/asb 图片 id** 即成品（记住历史 id 集合，新 id=新成品）。2026-10-09 实测：成品域名为 `flow.google.com/asb/<token>`，flow-content 域名仍用于已上传素材回显；点一次「开始生成」即发出（按钮变「停止」=生成中，约 20s 完成，完成后自动清空提示词）。
- 下载：单图 `Invoke-WebRequest` 直链 flow-content CDN（实为 JPEG FF D8）；**asb 域名直连报 TLS Authentication failed（需 cookie），走页面「批量下载」→ zip → 解压最稳**（zip 里的 *.jpg 即成品）。
- 成品常见为 **1200×896（非严格 3:2）**，2 行 3 列每格 400×448 —— 后期按实际尺寸切格，勿假设 3:2。

## 3. 本地后期管线（按序执行）

脚本在 `tools/flow_sprite_pipeline/`，`<unit>` 处硬编码为 ww1_mark4，换单位改路径常量即可。工作目录 `.godot/unit_review/flow_<unit>/`。

| # | 脚本 | 作用 | 关键参数/坑 |
|---|---|---|---|
| 1 | （切格镜像，见下） | 成品 1200×896 → 每格 400×448 水平镜像 → `mcell_0..5.png` | 逐格落盘再组装；**勿用嵌套数组中转 Bitmap**（PS @() 展平坑，op_Multiply 连环炸） |
| 2 | `make_transparent3.ps1` | **边界洪泛填充**白键转透明 → `mcell_T_0..5.png` | 从四边 BFS，bgTest=min≥250 且 spread≤6；前景 a=255 保焰心烟幕；邻接背景 1px 前景 a=min(255,d*6+30) 羽化。三代迭代结论：逐像素色距键会抠穿焰心、膨胀法留描边，洪泛是唯一正解 |
| 3 | `defringe_fix.ps1` | 白底反预乘去白边 `F=(C-255(1-a))/a`（a<12 清零）+ 按帧擦除框清串色 + 重建 row_T + 从 f0 重建卡图三档 | 擦除框只擦框内 min≥190 白像素（保车体）；**Save 到正被 Bitmap 占用的同路径会 GDI+ 错误** → 存 tmp 再 Move；擦除框扁平 int[] 传 C#（嵌套数组被 PS 展平） |
| 4 | `speck_fix.ps1` | 残余白色噪点（宽阈值 min≥160 且色差≤40）+ 交界窄条全清 | 用于擦框漏网的边角残点 |
| 5 | `edge_fix.ps1` | 左缘直切边锥形收尾（Taper）+ 火光边缘半透明像素 3×3 alpha 平滑（SmoothGlow） | **Taper 采样色可能取到暗部（炮管/烟影）→ 放大成方块**；修法见下「事故复盘」 |
| 6 | `deploy_sheet.ps1` | bbox 拟合 232px 居中 → `sheet_attack.png`（6×256）+ GIF（GifBitmapEncoder）→ 拷贝至 `.godot/unit_review/` | bbox 粗扫步长 2；帧内容锚点 (128,138) |
| 7 | `make_card.ps1` | 由待机格生成卡图 512/384/256 → 覆盖 assets 三档 | 卡敌我共用路径（vintage_audit.json cardE=cardP），替换一次双方生效；原卡备份 `card_backup/` |
| 8 | `review_page_template.html` | 新旧对比页模板（CSS steps 动画+调速按钮），引用 row_T/sheet，部署后刷新验收 | 改页面引用资源后 **row_T 必须与 mcell 同步重建**（见事故复盘） |

**单格切格镜像参考**（步骤1）：

```powershell
foreach($idx in @(0..5)){
  $col=$idx%3; $row=[int][Math]::Floor($idx/3)
  # src rect = (col*400, row*448, 400, 448)，镜像画到 mcell_$idx.png
}
```

## 4. 验收清单

- [ ] 深底合成检查（#1c2130）：六帧无白边、无深色描边、无邻格串色、无残点
- [ ] 帧序：待机→蓄力→爆发→衰减→余烟→闭合，首尾同待机
- [ ] 六帧车体形态/大小/位置一致（如复制粘贴），全部面朝正左
- [ ] 特效只在炮口附近；无弹道弹丸光束；悬浮精灵无地面无影子
- [ ] 火光/烟幕左缘无平直断口、无放大成块的暗部锥形
- [ ] `sheet_attack.png` 尺寸 = 6×frame_size；GIF 可播；卡图三档透明底
- [ ] 对比页 0.5×/1×/2× 播放逐帧目验

## 5. 事故复盘（ww1_mark4 实录）

1. **v1 文生图**：3×3 九格 + 坦克形态互不一致 → 废弃（留档 `_t2i_v1_ref.jpg`）。
2. **v2 强化提示词**：「失败，未扣费」→ 放弃纯 t2i 网格控制。
3. **v3 i2i 成功**但底稿朝右 → 全部朝右违规；逐格水平镜像修复。
4. **透明化三代**：色距键抠穿焰心 → 膨胀法奶油描边 → **洪泛填充**定稿。
5. **烟尾串格**：余烟帧烟尾越界串入待机帧两侧 → 擦除框清除。
6. **白边**：白底反预乘去晕。
7. **Taper 放大暗部**：左缘锥形收尾采样到炮管深灰色，放大成灰方块 → 该区废弃重绘（原图白键+6px 羽化）。
8. **row_T 漏重建**：修帧后只重建了 sheet/GIF，网页引用的 row_T 未同步 → 页面仍显旧帧。**教训：改任何 mcell 后，row_T、sheet、GIF、卡图四件必须同一批重建。**

## 6. 后续可复用

- 换单位：改脚本内路径常量 + 擦除框坐标（按新成品串色位置定）+ 提示词单位描述。
- 敌方单位共用本管线（卡图路径不同，无 cardE=cardP 合并问题）。
- 待机微动（idle bake 多帧）仍走 CSS 预览模拟，正式资产待烘焙多帧微动表。

## 7. 构图与对位调整方法（ww1_105mm R 版实录，2026-10-08）

### 7.1 同尺寸模板法（替代 3072×2048 放大铺底）

旧法把 256px 帧0 放大铺 3072×2048 底稿 → Flow 照描放大后**描边 6px 发灰发白**（贴纸感）。R 版改：**模板直接做成成品同尺寸 1200×896（每格 400×448）**，源图用旧攻击表 f0（bbox 254×142）缩放至 283×158 贴入，描边实测 4→4.5px 与现役一致。每格构图规格写死：炮体靠右（炮口前留白）、轮底同一基线（格内 y=398）、左侧留白给特效；白底 + 2px 浅灰(#d8d8d8)格线（Flow 会守格线，成品切格后需清缘，见 7.3）。生成器脚本 `build_template_R.ps1`，提示词 `ww1_105mm_attack_flow_prompt_i2i_R.txt`（额外约束：描边细且紧贴轮廓、特效严格不出本格）。

### 7.2 锚点验收探针（切格前必做）

对成品逐格实测两个锚点：**尾杆尖**（格内暗色最右列）与**轮底**（暗色最下行）。R 版六格 trailTip=380 / wheelBottom=398 完全一致 → 直切即可；若不一致，按锚点差逐格平移裁切窗口（mark4 旧案：ox=cellX+(T_k−T_0)、oy=cellY+(B_k−B_0)）。特效越格检查：对特效帧做暖色密度剖面（每 10px 列段强暖像素计数），可发现「密核直抵格线=Flow 出图时已越格被裁」——该部分切格后不可恢复，只能靠构图/缩放规避。

### 7.3 后期链新增两步（在 FloodKey 前后）

1. **格线残边清理**（FloodKey 前）：切格边缘 2px 带（x∈{0,1,398,399}/y∈{0,1,446,447}）内灰色像素（mn≥150 且 spread≤20）→白，每格约 3.3k px；不清会留格线残框。
2. **边缘去污 EdgeDecon**（FloodKey 后）：距透明 ≤2px 的不透明亮灰（mn≥150 且 spread≤48，排除暖色火焰 spread>48）→ 重上描边色(13,18,28)；再对 a<250 羽化带同条件去污。白晕两代根因：不透明环带 JPEG 白底残留、羽化像素纯白 RGB——反预乘无效，必须重上描边色。

### 7.4 对位部署：尺寸三重锁与容纳不变量

- **frame_size 是单位级参数**（`unit_frame_anim.gd` `_load_seq` 同一 fs 切 idle+attack 方形帧）；改帧宽被三重锁死：idle 表实宽=8×fs、冒烟测试锁「sheet 实宽==counts×frame_size」、`_compensate_size` 尺寸补偿耦合 fs。
- **容纳不变量**：炮身与待机同大 ⇔ 炮身占帧比固定（本项目 142/256=0.555）；「最宽帧完全容纳」要求 内容span/炮身 ≤ 帧宽/炮身占比（1/0.555=1.80）。若特效/炮身实宽比 > 1.80（105mm 火光=2.44），**容纳与同大数学上不可兼得，与帧宽取值无关**——只能在「炮身缩小」与「特效裁边」之间二选一，由用户裁定。

### 7.5 部署变换三策略（按用户裁定选择）

| 策略 | 公式 | 适用 |
|---|---|---|
| A. 炮身同大+逐帧补空白 | s=142/156 锁炮身；特效帧 dx 单独偏移（跳变量=偏移差，被动效掩盖） | 用户要炮身与待机严格同大、接受特效裁边 |
| B. 全容纳统一变换 | s=(帧宽−2×margin)/最宽span；六帧统一 dx=(帧宽−span×s)/2 | 用户裁定容纳优先（105mm 最终采用） |
| C. B + 反冲微动 | 在 B 基础上预留峰值余量：s=(帧宽−峰值−2×margin)/span；dx_i=recoil_i | 要后坐感（105mm 定稿） |

- dy 统一：`dy = 地面线(226) − 轮底y × s`。
- **反冲微动**：炮身朝左 → 后坐=画面 +x（右移）；曲线示例 f2 爆发+8（峰值）/ f3 +7 / f4 +3 / 其余 0（爆发帧瞬间后坐，~375ms 缓复）。玩家侧 `flip_h` 镜像后方向自动正确，无需按敌我分支。零裁剪自检：`min(dx_i)+minx×s ≥ 0` 且 `max(dx_i)+maxx×s ≤ 帧宽`。
- 实施位置：部署脚本的 per-frame dxs 数组（如 `pipeline_R.ps1`），**不动引擎代码**；换曲线改一个数组重跑一条龙即可。

### 7.6 会话级经验补充

- agent-browser 先 `get cdp-url` 验目标——daemon 自带无头浏览器（已登录态），`connect 9222` 才切到可见 Chrome；每次生成提交「开始生成」需点第二次才真正发出。
- 下载原图：先 eval 取 img 完整 src（含签名参数，截断即 403）再 `Invoke-WebRequest`；页面内 fetch 跨域会 Failed to fetch。
- 带空格路径作 CLI 参数必须整体加引号再传入 ArgumentList，否则被拆词（`F:\godot fair duet` → 误存 `F:\godot` + `fair`）。
- 预览页验证用 `tab new` + `open` 新标签，不占用用户正在看的页面。

## 8. 透明底结论（2026-10-09 实测定论）

Flow 网页版**拿不到真透明底**，两条路均实测否决：

| 路线 | 结果 |
|---|---|
| 文生图 prompt 要求 FULLY TRANSPARENT / real alpha / PNG | 画 Photoshop 式棋盘格假透明（1376×768） |
| 上传白底图 + 「移除背景」类编辑提示词 | 仍画棋盘格；页面 canvas 实测四角+中心 alpha 全 255（不透明） |

- 交付物全是 JPEG（FF D8），物理无 alpha 通道；设置面板（智能体设置）只有确认模式/比例/分辨率倍率/默认模型，**无输出格式、无透明开关**。
- 页面内 canvas 验 alpha 技法（无需下载）：同源 `flow.google.com/asb` 图 `drawImage`→`getImageData` 读四角/中心 alpha——JPEG 无 alpha 则全 255，PNG 真 alpha 会保留；跨域 flow-content 图会污染画布不可读。
- 真透明底唯一未测候选=Gemini API 出图；项目内治本方案仍是**品红/纯色底出图 + chroma_key**（`tools/img25_anchor_gen.py:14`、`tools/img25_attack_gen.py` `chroma_key(im,bg,tol=85)`），棋盘格假透明比白底更糟（多一层格纹要抠），不可用。

## 9. 全身单位 3×2 品红格网 + 打包链（fut_arm_omega BIP6/BIP6R 实录，2026-10-09）

与 §7 炮类（105mm）同源流程的**全身机甲变体**，差异点与打包扩展：

### 9.1 3×2 逐排大小跳变 → 逐帧机身归一（区别于炮类全局单缩放）

- Flow 对 3×2 网格**逐排大小不一致实测 ~9% 线性（下排面积 +15~19%）**。炮类 §7.2 靠锚点探针全一致才敢直切；全身单位特效贴身、无独立尾杆探针，必须**逐帧量「右半幅机身高」**（x≥格宽/2，避开朝左特效区）逐帧缩放到 idle 基准（容纳不变量：attack 机身=idle 机身，ω 例 192px）。
- **头顶测量用持续密度门**：连续 7 行密度≥40 才算头顶（30 档烟柱也会过门；40 档实测烟灭头过，误差≤1.2%）。脚线=右半幅 α≥128 最下行。
- 品红管线**禁用无差别 edge_unmix**：对贴透明邻域全量反解品红底会把中性灰描边 (128,128,128) 算成 (74,183,74) 荧光绿（每帧 1300-1800px）。替代=「绿污染继承」：贴透明 3px 内 g>max(r,b)+12 的像素 BFS 继承最近正常邻居色。JPEG 品红场残留另配 despill（min(r,b)−g>6 压回）。
- 黑格线（col/row 各 ~6px 带）切格前**填品红交给键控**，不要直接写 alpha=0（RGB 图上写 4 元组会产生黑边假象）。格线位置用行/列暗度游程实测，勿按均分猜。

### 9.2 全身单位后坐力微动（§7.5 策略 C 的全身版）

- 朝左 → 后坐=+x 右移；`RECOIL=[0,6,8,5,2,0]`（静→踢→峰→缓→残→归），**右缘基准从满格让出峰值余量**（ω：254→246，预留 8px），`ox=右缘基准−宽+1+RECOIL[i]`。零裁剪自检同 §7.5。
- 全身机甲的后坐读感来自整体位移+姿态（模型原格已带压低/前倾），位移 6-8px 足够，勿加大。

### 9.3 微动待机（bob idle）与攻击 rest 帧同位 → 零跳变

- 从攻击表**净身 rest 帧**（去悬空烟缕：非主体连通域整体低于「脚线上方 90px」线者删；与主体连通的去不掉属贴身特效，目验定性）生成 4 帧 bob `dy=[0,-2,0,2]`@8fps，替代多帧静态 idle（file 更小、循环更顺）。
- **同位铁律**：idle rest 帧与攻击 rest 帧同右缘、同脚线（ω：右缘 246、脚线 231）→ idle→attack 切换零跳变。
- idle 帧数变更后必跑 `tools/_tmp_anim_foot_frac.py`（foot_frac 随内容底自动重测，ω 0.0645→0.0918），anim.json counts 同步改。

### 9.4 同源卡图链 + 锚点三处同步

- 卡图从**同一净身 rest 帧**缩放出（构图对齐旧卡内容 bbox：内容高/脚线 y 对齐）→ 旧 ff/hf 锚点（头顶/脚高占比）不失效；enemy=原生朝左、player=水平翻转（xeno 契约），部署 vis_*_NNN + _thumb256/_thumb384 双侧。
- **构图变了必须重标炮口锚点**，三处同步缺一不可：`docs/敌我双方卡头脚和开火位置.json`（compact 单行格式，定点字符串替换，勿 json.dump indent 重排全文件）+ `data/muzzle_anchors.gd`（敌）+ `data/player_muzzle_anchors.gd`（我，且我 fireX=1−敌 fireX）。实测法：炮管逐帧描迹取 muzzle 像素坐标→换算占比。
- 打包脚本模式：`cut_*.py`（清洗链）与 `*_package_v1.py`（打包：攻击表+idle+卡图+预览条）分文件，后者 import 前者复用清洗链（`python -I` 下需 `sys.path.insert` 脚本目录）。

## 10. 飞行单位品红底变体 + agent-browser 新版实录（mod_inf_scout_drone 022，2026-10-10）

§9 流程的**小型飞行单位变体**，核心变化=全程品红底（用户拍板：白底不好抠，提示词让加品红底+非背景机体细描线，后期好抠）：

### 10.1 品红底模板与键控

- 模板 bg=#FF00FF、格线=#C800C8（同色相→键控时格线随底一起掉，不留残线）。机身素材贴底前必须**洪泛去白+全局杀近白(≥232)闭合口袋**（纯 bbox 粘贴会带白矩形；桅杆间闭合白袋洪泛够不到）。
- 键控判据 `r>140 & b>140 & g<0.75·min(r,b)−10`：橙火/白焰芯/灰烟/灰绿机体/黄条全安全。羽化=tint 邻接半透明 110。
- **紫晕两段杀**：半透明烟雾与 AA 边会吃品红染（边缘去染照顾不到），全域 `r−g>10 & b−g>10 → 压回均值灰` 两遍（第二遍阈值 10 抓暗部轮廓残留）；灰绿涂装无合法紫红像素，安全。
- 预览渲染的"绿边"伪影别当病：细亮线在品红底上缩放显绿是色差，先查像素（g>r+8 即 0 命中）再定病。

### 10.2 飞行单位归一与打包

- 行间漂移非等比（本例宽 +7.8% / 高 +2.6% / 下移 6px）：§9.1 的单缩放扩成 **sx/sy 分轴**归一，机体暗色掩码（max rgb<150）做锚。飞行单位质心 y 极差门 ≤12px（本批 2.7px）。
- bob idle 直接取攻击表 rest 帧（cell1 天然无烟可净身），dy=[0,-2,0,2]@8fps 整帧平移；foot_frac=内容底缘（飞行单位悬空，0.40 级），改帧数后照跑 `_tmp_anim_foot_frac.py`。
- 卡图：rest 帧 2x→512 内容居中，enemy=原生朝左、player=水平翻转（与 §9.4 xeno 契约一致）；出膛点=焰像素逐行右缘中位数（贴鼻侧），fireY 同源换算。

### 10.3 agent-browser 新版坑（Chrome 155 + Flow 2026-10 版）

- **eval `b.click()` 对 Angular 按钮（开始生成）静默无效**（事件到位但 handler 不触发）；必须 agent-browser 原生 `click 'button[aria-label="开始生成"]'`（CDP 受信任事件，带引号中文属性值可用）。发送判据=composer 清空+停止按钮出现。
- screenshot 绝对路径 10060 超时、相对路径落进程 cwd（项目根）；媒体库上传：`上传媒体内容` 按钮点了才注入 input[type=file]；**upload 可能静默挂错资产**——发送前必须验 chip（签名 URL curl 下载测品红占比，签名 URL 可匿名下载，无参 CDN 路径 403）。
- 品红模板上传后 Flow 侧出过一次错挂（chip 指向白图 21a1cf7b），重走 composer 上传入口后恢复正常（bccf1dd2）；asin/asb 结果图与页面同源，canvas toDataURL + 30KB 分块 eval 抽取可用，重组时正则必须用裸 base64 模式（带引号模式会漏 data: 前缀块）。

- **模板上传正道=剪贴板粘贴，OS 原生文件对话框是陷阱**（034 批实录）：`添加媒体`→`上传` 会弹 Chrome 原生「打开」对话框——**阻塞整个浏览器进程**（后续 CDP 全部 10060 超时），且 PowerShell `SendKeys` 的路径+回车打的是 OS 前台窗口（终端），不是对话框；`AppActivate('打开')` 返回 False；UIA AutomationElement 枚举子窗口 marshal 失败。正道：`powershell -STA` 执行 `[System.Windows.Forms.Clipboard]::SetImage([System.Drawing.Bitmap]::FromFile(路径))` → CDP 点 composer → agent-browser `press Control+v`，一次成功。
- **CDP `press Escape` 打的是页面**（收起媒体选择面板用它）；PowerShell SendKeys 的 ESC 打 OS 前台——两者别混。另：CDP `press` 组合键写法 `press Control+v`。
- **chip 图验不了 canvas 就走页内 fetch**：flow-content.google 域的 chip `<img>` 会污染 canvas（getImageData SecurityError，无 CORS）；改页内 `eval` 里 `fetch(src)` → `blob` → `URL.createObjectURL` → 新 `Image` → 干净 canvas → toDataURL。验品红占比照旧。
- **结果轮询去重别信 8-hex 图片 id**：asb 签名 URL 每次渲染重切 token，旧图看起来像新图；按**提示卡文案匹配**或已知前缀过滤才稳。

### 10.4 验收页与缓存核验（022 批收口实录，2026-10-10）

- **验收页 CSS 半帧步进病**：strip 窗口 W px、雪碧图按 k 倍显示时，`steps(N)` 的总位移必须是 **N × W·k**（每步正好一整帧显示宽），照抄源图宽度（N×帧宽）就每次走 1/k 帧——窗口里恒显"上一帧右半 + 下一帧左半"，看起来像同一机体有两个版本（022 批用户实问，根因=位移 -1536 应为 -3072）。判据：播放时窗口内机体被竖切缝一分为二即是此病。
- **ctex 新鲜度核验唯一正姿势**：读本单位 `.import` 的 `path=` 行拿哈希，再 stat 那个 ctex。禁止 `ls .godot/imported | grep 关键词`——`sheet_attack.png` 是全项目通用文件名，且哈希子串会撞关键词（本批 grep "022" 命中哈希恰含 022 的**别单位** ctex，mtime 全部对不上，虚惊一场）。终审仍以引擎实载维度为准（headless --script 加载 4 图 + JSON.parse_string，`var j: Variant =` 防 Variant 推断报错）。
- **循环闭合差量化**（首尾同为 rest 姿势的序列，如 六格焰 1待机/6闭合）：对帧1 vs 帧6 做 alpha 交集像素差（>60 占比）+ 拉普拉斯锐度对比。锐度一致→只是模型重绘细节出入（桨角/面板线），循环 6→1 轻跳；嫌跳就**帧6 直接换帧1 内容**（语义等价，格6 本就是回待机）。本批 36% 像素差/锐度 35.7 vs 37.2，未动。
