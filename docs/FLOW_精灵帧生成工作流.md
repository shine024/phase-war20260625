# Flow (Nano Banana) 精灵帧生成工作流

> 用 Google Flow（flow.google.com，Nano Banana 2.1）图生图产出单位攻击六宫格，本地后期成透明帧并部署。
> 实战首例：ww1_mark4（马克IV）攻击帧，2026-10-08 全流程跑通。脚本存于 `tools/flow_sprite_pipeline/`。

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

## 2. 生成路线：图生图（i2i）六宫格 —— 唯一可靠路线

纯文生图两次翻车：v1 画成 3×3 九格且六辆坦克形态互不一致；强化网格提示词 v2 直接生成失败（未扣费）。**必须用底稿锁定布局与形态。**

### 2.1 底稿模板制作

1. 文生图一张参考图（提示词见 `tools/flow_sprite_pipeline/prompt_t2i_首图.txt`），从其**单格**裁出坦克（如 v1 格(1,1) 裁 `rect(4,4,450,248)`）。
2. 缩放置于 3:2 画布（3072×2048），2 行 × 3 列，每格 1024²，格间距留白 ~130px，白底。
3. **朝向校验**：底稿坦克必须与目标朝向一致（本项目=面朝正左）。若源图朝右，整幅水平镜像：`TranslateTransform(W,0)+ScaleTransform(-1,1)`。i2i 会忠实继承底稿朝向，此步不可省。
4. 产物：`<unit>_grid_template_L.png`。

### 2.2 底稿入 Flow（重要坑）

- ❌ 素材面板「上传媒体内容」会开原生文件对话框阻塞页面；
- ❌ `input[type=file]` 隐藏元素 CDP 查不到（DOM.querySelectorAll 返回 0），setFileInputFiles 报 Invalid parameters；
- ❌ Page.setInterceptFileChooserDialog 拦不到 fileChooserOpened 事件；
- ❌ agent-browser 的 `press Control+v` 是 CDP 合成键，进不了 contenteditable；
- ✅ **可用姿势**：STA 子进程写真位图入剪贴板 → Chrome 前台 → 真键盘 ^v：

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

- 点开始生成后每 ~13s eval 轮询 `document.images`，出现**新的 flow-content 图片 id** 即成品（记住历史 id 集合，新 id=新成品）。
- 下载：单图 `Invoke-WebRequest` 直链 flow-content CDN（实为 JPEG FF D8）；批量用面板「批量下载」→ zip → 解压（zip 里的 image.png_xxx.jpg 即成品）。
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
