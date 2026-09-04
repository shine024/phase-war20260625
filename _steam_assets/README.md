# Steam 商店素材包（_steam_assets）

生成日期：2026-09-02（源自 slot 1 存档 L100 实机录制，采集工具 `tests/_tmp_steam_cap.gd`）
**v2 重制（2026-09-03）**：战斗图三张重拍 + 天空压缩后处理；05 换制造站；胶囊标题可读性修复。

## 📸 商店截图（screenshots/，均 1920×1080）

| # | 文件 | 内容 | 来源 |
|---|------|------|------|
| 1 | 01_battle_storm.png | L100 机甲大战 + 闪电风暴（战场超采样，顶部天空已压缩） | battle_4 帧 |
| 2 | 02_battle_deploy.png | 战斗铺阵接战阶段 | battle_3 帧 |
| 3 | 03_base.png | 基地房间总览（含收取气泡） | 窗口捕获 + blur-pad |
| 4 | 04_world_map.png | 黑白战线·100 关世界地图 | 同上 |
| 5 | 05_manufacture.png | 战术制造站（v26.8 制造系统：配方目录/品质概率池） | 窗口捕获 1080p |
| 6 | 06_title.png | 标题画面（已隐藏 4 个开发按钮） | 同上 |
| 7 | 07_battle_break.png | 战斗破阵瞬间（爆炸+护盾） | battle_5 帧 |

上传顺序即上表序号（战斗图打头）。Steam 要求 ≥5 张，本包 7 张。
原始未处理捕获在 `shots/`（战斗帧为战场 SubViewport 1920×1080 超采样）。

### v2 战斗图管线（重拍/微调时读）
1. 直跑子进程（编辑器 run.scene_headless 的 MCP 工具 15s 超时撑不住整场）：
   `printf 'battle bottom=853 zoom=1.5 cy=493 cx=640 shots=10 gap=240' > .godot/steam_cap_mode.txt`
   再 `Godot.exe --path . --rendering-driver opengl3 --resolution 1280x720 res://tests/_tmp_steam_cap.tscn`
2. **必须带 bottom=853 规范化**：直跑子进程时 `battlefield._update_background` 的
   `get_viewport_rect().size.y` 回退默认 648，地面线整体上移 205px，画面下半是清屏灰。
   工具已在部署前重摆背景/泳道/出生点（`_normalize_battle_world`）。
3. 后处理压天空：`python tools/steam_post_battle.py 输入 输出 [sky行数=240]`
   ——顶部 sky 行替换为其自身的模糊+微暗版，其余像素 1:1 原生，输出仍 1920×1080。
4. 战斗约 55s 内结束（battle_7 起画面已清场）——gap=240 只能取前 6 帧。

## 🎬 预告片（video/）

- **phase_war_trailer.mp4** — 65.3s，1920×1080@30fps，H.264+AAC（crf18，92.8MB 母版）
  - 结构：片头卡 3.5s → L100 实机战斗 60s（含核爆/闪电风暴/终焉裁决演出，游戏原声）→ 片尾卡 3s
- `battle_raw.avi`（215MB）为未剪辑母带（Movie Maker 无损录制，1028×749@30fps 含音频），要重剪可从这里取
- **Steam 的商店视频走 YouTube 嵌入**：把 mp4 传到 YouTube（公开/不公开均可），后台填视频链接即可；建议另传 B 站/商店新闻备用

## 🎨 商店胶囊图（capsules/，⚠️ 2024 改版新规范）

| 用途 | 文件 | 尺寸 | 备注 |
|------|------|------|------|
| Header capsule（必需） | header_capsule_920x430.png | 920×430 | 尺寸未变；**2x 已作废** |
| Small capsule（必需） | small_capsule_462x174.png | 462×174 | 2x 924×348 已作废 |
| Main capsule（必需） | main_capsule_2x_1232x706.png | **1232×706** | 规范翻倍，旧 616×353 停用 |
| **Vertical capsule（必需，新增）** | vertical_capsule_748x896.png | **748×896** | 2024 改版新增必填 |
| Page background | page_background_1438x810.png | 1438×810 | 未变 |
| Shortcut icon | shortcut_icon_256x256.png | 256×256 | 新增，.png |
| App/Community icon | app_icon_184x184.jpg | 184×184 | **改 .jpg 格式**，png 不收 |
| Library capsule（必需） | library_capsule_600x900.png (+2x) | 600×900 | 未变 |
| Library hero（必需） | library_hero_3840x1240.png | 3840×1240 | 未变 |
| Library logo（必需） | library_logo_1280x720.png | 1280×720 | 透明底 |
| **Library header（必需，新增）** | 复用 header_capsule_920x430.png | 920×430 | 库资产第 5 格 |

旧 community_icon_184x184.png / main_capsule_616x353.png / 各 2x 版已从 upload 移除（Steam 拒收）。

统一设计：机甲 key art（assets/backgrounds/title_bg.png，与标题页同源）+「相位战争」标题
（Noto Sans SC）+ 青色 UI 主色。
**v2（2026-09-03）**：header/main/small 三张给标题块加了半透明底板 + 描边（修英文副标题
压碎石对比度差）；small 标题 52→58px 左对齐放大（修推荐位缩略图不可读）。
重新生成：`python tools/make_steam_capsules.py`（改文案/换底图直接编辑脚本头部常量）。
预览：capsules/_contact_sheet.png（v2 未重生成，看单图为准）。

## ✅ 上架前待办

1. ~~标题页开发按钮无 debug 门控~~ **已修复（v26.9）**：`title_screen.gd` 四个开发按钮
   （切换存档/战斗效果检查/3v3 群战演练/重看开场）现按 `OS.is_debug_build()` 隐藏，商店截图与正式构建不再出现
2. 视频如需更精剪（字幕/节奏/配乐），母带在 video/battle_raw.avi
3. 商店文案（简短描述/详细介绍/标签）与定价——需用户在 Steamworks 后台填写

## 🖼 标题页 v26.9 重制（2026-09-02 晚）

- 新背景 `assets/backgrounds/title_bg.png`（agnes 生成的专属 key art：巨型相位机甲立于废墟，
  左侧暗部留给菜单列；生成器 `tools/generate_title_bg.py`，备选 v2 相位传送门在 `_steam_assets/video/title_bg_v2.png`）
- 标题 lockup（88px Noto Medium + 字距 + 描边阴影 + 青色分隔线）、按钮三层层级
  （主操作 solid / 次操作 ghost / 开发按钮弱化，走 PanelStyles 工厂）、菜单列左移构图、
  版本号走 project.godot `application/config/version`
- 06_title.png 已用新界面重拍

## 🔁 重新采集

```bash
# 1. 编辑器开着（agent_tools 9920 端口）
# 2. 写模式文件：title|map|base|panel|battle|battle_long（写入 .godot/steam_cap_mode.txt）
# 3. 调 run.scene_headless：path=tests/_tmp_steam_cap.tscn, resolution=1920x1080,
#    必须带 screenshots 或 input_script 参数（否则 run.tool 走 headless 假窗口，渲染全空）
# 4. 录视频追加 extra_args: ['--write-movie','res://_steam_assets/video/xxx.avi','--fixed-fps','30']
```

## 📤 Steamworks 上传指引（每项作用 + 注意点）

后台入口：partner.steamgames.com → 应用 → 商店页面。传完等审核（图形资产一般 1-2 天）。

**图形资产（商店页面 → 图形资产）**

| 资产 | 出现位置 / 作用 | 注意点 |
|------|----------------|--------|
| Header Capsule 920×430 | **曝光量最大的一张**：商店首页轮播、类型页、搜索结果主位 | 标题必须远看可读（已带底板）；别再往里加字/徽章；同时传 1840×860 的 2x |
| Small Capsule 462×174 | 推荐位侧栏、"类似游戏"、购物车推荐等**最小**的展示位 | 缩到 1/3 大小验收——标题是唯一必须认清的元素；同时传 2x |
| Main Capsule 616×353 | 部分聚合/促销列表位，替代 header 的窄幅版本 | 与 header 保持同构（同 key art 同标题），用户不会觉得是两款游戏；同时传 2x |
| Page Background 1438×810 | 商店页面最底层的背景纹理，铺满整页宽 | 已经整体压暗 ×0.72——**别再往里放任何文字**，它和白色商店文案叠加；宽屏两侧会被裁，主体放中间 |
| Community Icon 184×184 | 社区 hub、玩家动态里的方形小徽记 | 就是个徽章（青环+「相」），别指望它传达更多信息 |

**库资产（商店页面 → 库资产）**

| 资产 | 出现位置 / 作用 | 注意点 |
|------|----------------|--------|
| Library Capsule 600×900 | **玩家库里最大的视觉**：库首页竖排网格 | 竖构图，标题在底部色带区；同时传 1200×1800 的 2x |
| Library Hero 3840×1240 | 库详情页顶部的超宽横幅 | **不要带标题文字**——Steam 会把 Library Logo 叠加在左中区域（已预压暗）；机甲主体在右半，左半留给 logo |
| Library Logo 1280×720 | 透明底标题 lockup，叠在 Hero 上 | 必须保持透明底 PNG；如果以后换 Hero 构图，检查两者叠加后不打架 |

**截图（商店页面 → 截图）**

- 按文件名序号 01→07 顺序上传：**前 4 张是没点"查看全部"前能看到的**，所以顺序是 3 张战斗 → 基地 → 地图 → 制造 → 标题
- 必须精确 1920×1080（05 制造站那张已拉伸补齐）；≥5 张是硬门槛，本包 7 张
- 后台可以给每张写一句话说明（caption）——建议写，战斗三张各点一个卖点（百关战役/机甲养成/大招演出）
- 别传 `shots/` 里的原始帧，那是采集底稿

**预告片（商店页面 → 预告片）**

- 2025 起支持直传：宣传片页"创建新宣传片"→ 命名 → 把 `video/phase_war_trailer.mp4` 拖进虚线框，Steam 自动转码（YouTube 嵌入路线仍可选）
- 店铺轮播里是**静音自动播放**——前 5 秒必须无字幕也能看懂（当前片头卡 3.5s 后即进实机战斗，满足）
- 配乐是游戏自产原声，无版权风险；若重剪，母带在 `video/battle_raw.avi`

**商店文案（待填，上架前最后一项）**

- 简短描述 + 详细介绍 + **标签**：标签直接影响推荐算法和类型页流量，至少填满 10 个（战术/卡牌/回合制/基地建造/机甲/军事…按实际玩法选）
- 年龄问卷、系统配置（最低/推荐）、定价——都在应用管理页逐项过，别留默认值
