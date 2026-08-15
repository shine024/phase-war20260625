# Phase War UI 检查报告

**检查日期**: 2026-06-09
**分辨率**: 1280x720
**检查范围**: 所有UI面板和界面元素

---

## 一、严重问题（需立即修复）

### 1. 面板尺寸超出屏幕

#### 1.1 卡牌强化面板 (card_enhancement_panel.tscn)
**问题**: custom_minimum_size = Vector2(1200, 640)
- 对于1280x720屏幕来说太大，几乎占满整个屏幕
- 可能导致内容被裁剪或难以操作
- 建议改为 Vector2(1000, 580) 或使用百分比布局

**优先级**: 🔴 高

#### 1.2 成就面板 (achievement_panel.tscn)
**问题**: 硬编码偏移量
```gdscript
offset_left = 100.0
offset_top = 50.0
offset_right = 700.0
offset_bottom = 650.0
```
- 固定位置和尺寸，可能导致在不同分辨率下出现问题
- 建议改为居中布局或使用 anchors

**优先级**: 🔴 高

#### 1.3 关卡选择面板 (level_select_panel.tscn)
**问题**: 固定尺寸 900x700
```gdscript
offset_left = -450.0
offset_top = -350.0
offset_right = 450.0
offset_bottom = 350.0
```
- 对于1280x720屏幕来说太大
- 建议改为 Vector2(800, 600) 或更小

**优先级**: 🔴 高

---

## 二、中等问题（影响用户体验）

### 2.1 字体大小不一致

**问题**: 各面板使用不同的字体大小标准，缺乏统一性

| 面板 | 标题字体 | 正文字体 | 小字体 |
|------|---------|---------|--------|
| backpack_panel | 15px | - | - |
| card_enhancement_panel | 22px | 14-18px | - |
| evolution_panel | 32px | 18-24px | - |
| faction_panel | 17px | - | 13px |
| affix_panel | 17px | 12-14px | 10px |
| achievement_panel | 16px | - | 12px |
| leaderboard_panel | 17px | - | 11px |
| battle_hud | - | 12-14px | 10px |

**建议标准**:
- 大标题: 24-28px
- 标题: 16-18px
- 正文: 13-14px
- 小字: 10-12px

**优先级**: 🟡 中

### 2.2 背包面板Grid列数过多

**问题**: backpack_panel.tscn 中 GridContainer columns = 17
- 对于1000px宽的面板，每列只有约50px
- 卡牌格子太小，可能影响视觉效果和交互
- 建议改为 columns = 10-12

**优先级**: 🟡 中

### 2.3 改造面板缺乏样式

**问题**: modification_panel.tscn
- 布局非常简单，缺乏样式定义
- 没有背景、边框等视觉元素
- 与其他面板风格不统一
- 建议添加 StyleBoxFlat 样式

**优先级**: 🟡 中

---

## 三、轻微问题（可优化）

### 3.1 文本换行处理

**问题**: affix_panel.tscn 中 EmptyHint 文本
```gdscript
text = "该卡暂无词条
蓝图升星可获得新词条"
```
- 使用硬编码换行符，可能在不同屏幕尺寸下显示异常
- 建议使用 autowrap_mode

**优先级**: 🟢 低

### 3.2 掉落物品面板缺少尺寸

**问题**: drops_inventory_panel.tscn
- 没有定义 custom_minimum_size
- 可能导致显示异常或布局不稳定
- 建议添加合适的尺寸定义

**优先级**: 🟢 低

### 3.3 情报中心面板尺寸

**问题**: intelligence_hub_panel.tscn
- custom_minimum_size = Vector2(920, 620)
- 相对较大但可接受
- 建议考虑缩小到 Vector2(840, 580)

**优先级**: 🟢 低

---

## 四、设计一致性建议

### 4.1 统一命名规范
- 关闭按钮: 统一使用 "关闭" 或 "✕"
- 标题格式: 统一使用 "图标 + 标题" 格式

### 4.2 统一颜色主题
建议使用以下颜色方案：
- 主色调: Color(0, 0.941, 1) - 青色
- 强调色: Color(0.545, 0.361, 0.965) - 紫色
- 成功色: Color(0.2, 0.8, 0.4) - 绿色
- 警告色: Color(1, 0.843, 0) - 金色
- 危险色: Color(1, 0.4, 0.4) - 红色

### 4.3 统一间距标准
- 面板边距: 12-20px
- 元素间距: 6-10px
- 小间距: 4-6px

---

## 五、修复状态

### 第一批（紧急）- ✅ 已完成
1. ✅ card_enhancement_panel.tscn - 缩小尺寸: 1200x640 → 1000x580
2. ✅ achievement_panel.tscn - 修复偏移量: 改用居中布局，600x500
3. ✅ level_select_panel.tscn - 缩小尺寸: 900x700 → 760x580

### 第二批（重要）- ✅ 已完成
4. ✅ backpack_panel.tscn - 减少Grid列数: 17 → 12
5. ✅ modification_panel.tscn - 添加样式: 添加完整样式定义和主题
6. ✅ 创建UI设计规范文档

### 第三批（优化）- ✅ 已完成
7. ✅ affix_panel.tscn - 修复文本换行: 移除硬编码换行符
8. ✅ drops_inventory_panel.tscn - 添加尺寸: 800x520，居中布局
9. ✅ intelligence_hub_panel.tscn - 缩小尺寸: 920x620 → 840x580

---

## 六、测试建议

### 测试分辨率
- 1280x720 (基准)
- 1920x1080
- 1366x768

### 测试场景
- 打开所有UI面板，检查是否有超出屏幕的内容
- 检查文字是否清晰可读
- 检查按钮是否易于点击
- 检查滚动是否流畅
- 检查面板切换是否正常

---

---

## 七、v7.x 面板统一改造审计（2026-08-15）

**背景**: 2026-06-09 首轮审计后部分修复回潮（card_enhancement 尺寸回 1180x640、字号统一未达成），且 DesignTokens 采用率仅 22%、PANEL_SIZE 三档 0 引用、关闭按钮 3 种模式并存、leaderboard 为 PopupPanel 层级孤儿。本轮做视觉升级 + 设计统一（基础设施 + 12 重点面板）。

**基础设施（新增/扩展）:**

| 文件 | 内容 |
|------|------|
| `scenes/ui/components/panel_chrome.gd`（新增） | 统一面板外壳：accent 发光竖条 + 标题/副标题 + 右上 ✕（44x44、hover 红色发光），attach_to 一行接入 |
| `scripts/ui/panel_styles.gd` | +make_panel_frame（深空黑底+accent 边+圆角12+外发光+粗顶边）/ make_button_styles（四态）/ make_title_accent_bar / make_close_button_styles |
| `resources/design_tokens.gd` | +FONT_SIZE_XSMALL(10)/FONT_SIZE_BODY(14) 两档；+PANEL_ACCENTS 12 面板签名色 + get_panel_accent() |
| `scripts/signal_bus.gd` | +panel_opened/panel_closed(panel_id) 全局面板广播 |

**面板迁移（12 个，全部：PanelChrome + 三档尺寸 + DT 色板 + 按钮四态 + 字号归一）:**

| 面板 | 尺寸变化 | 签名色 | 附带修复 |
|------|---------|--------|---------|
| store | 520x420 → MEDIUM | 金 | tscn 清 6 个死 sub_resource；商品/符文/情报道具区全上四态按钮 |
| quest | 520x440 → MEDIUM | 青 | Tab 字色统一；接取/放弃按钮四态 |
| drops_inventory | 800x520 → SMALL | 橙 | 条目卡片化（原无背景） |
| achievement | 绝对偏移 600x500 → SMALL 居中 | 金 | 去 TitleRow/底部关闭 |
| settings | 480x540 → 480x560（保留紧凑） | 中性灰蓝 | 层级重构 Margin>VBoxMain>[Chrome,Scroll] 防 ✕ 随内容滚动 |
| occupation | 940x620 → MEDIUM | 青 | **修复关闭 bug**：原 _on_close 只藏面板自身，Overlay/Backdrop 卡屏；改发 closed 信号 + main.gd 接线 |
| faction | 760x600 → MEDIUM | 紫 | 势力列表/激活/解锁按钮四态；技能节点三态色收口 DT |
| intelligence_hub | 840x580 → MEDIUM | 紫 | 符文/符文之语卡色收口 DT |
| collection | 960 → MEDIUM | 科技青 | 稀有度色板收口 DT；列表行选中态用 pressed 高亮 |
| reinforcement | 960x600 → LARGE | 绿 | THEME_* 11 常量收口 DT；"← 成长首页"保持在 ✕ 左侧 |
| leaderboard | PopupPanel 560x500 → 常驻 Overlay MEDIUM | 金 | **迁出 PopupPanel**：main.tscn 建 LeaderboardOverlay 结构；main.gd 走 _toggle_overlay；game_manager/node_finder 路径链更新 |
| daily_task | — | — | **跳过**：孤儿场景（无任何实例化引用，日常任务实际显示在 quest_panel DailyTab） |

**契约收敛（main.gd）:**
- `_open_overlay` 14 分支 if/elif 链 → match + `_notify_panel_opened()` 通用分发（on_overlay_opened → refresh → show_panel → _refresh_all），仅保留 map/backpack/growth/afk 四特例。
- `_overlay_for_panel_key`/`_ensure_lazy_panel` 补 leaderboard 映射；关闭面板时广播 SignalBus.panel_closed。

**验证**: gdparse 全部通过；迁移面板 .gd 中 `Color(0.` 字面量清零（数据表 fallback 除外）；Godot headless 运行时检查 + 全项目 --check-only 见任务记录。

**遗留（后续批次）**: 四养成面板与 backpack（v7.x 已重设计，本轮未动）；help/upgrade/phase_master_skill/mvp/world_map 等未迁移面板；docs/界面一致性 HTML 与本文的进一步合并。

---

## 八、v7.x 全量面板扫尾（2026-08-15 第二批）

**范围判断**（按"以判断为准"授权）：剩余弹窗功能面板全量迁移；战斗 HUD 类（battle_hud/top_hud_bar/card_info/bottom_*/battle_* 等 14 个，非弹窗面板）与四养成面板（v7.x 签名色设计语言自成体系）明确排除。

**第二批迁移（7 个 + backpack 收口）:**

| 面板 | 处理 | 附带 |
|------|------|------|
| player_master | chrome+紫框架，删 TitleBar/底部关闭 | PANEL_ACCENTS 注册 player_master=紫 |
| help | chrome+青框架+SMALL 档（640x480→840x580），保留入场 fade/scale 动画 | 休眠面板（有 Overlay+注册但无打开入口），Tab 字色统一 |
| manufacture | 内嵌 AssemblePopup chrome 化+紫框架（宿主是 VBox 非面板）；动作按钮四态 solid；InfoPopup 保留 | ✕ 关闭=关整个制造界面语义保持；tscn 清 3 个死 action_btn 资源 |
| phase_master_skill | 纯代码面板：chrome+金框架+MEDIUM 档；技能点改挂 chrome 状态行；节点三态/稀有度色收口 DT | |
| afk | 仅视觉层：chrome+青框架；**三层可见性协议（Backdrop/Panel/self）保持不变**（main.gd 依赖） | tscn 清死 bg 资源 |
| mvp | 不做 chrome 化（结算演出层，CanvasLayer 200+胜负语义色），仅字面量收口 25 处 → DT | 胜负演出色 6 处保留 |
| backpack | 保留 v9.2 按-tab 签名色标题栏（优于通用 chrome），仅：关闭按钮统一 ✕ 44x44 四态（hover 红发光）+ 精确同值色收口（AMBER 系/CYAN_TECH/AMBER_SOFT 8 处） | **修复 HEAD 即存在的语法错误**：改造模块库 Tab 占位字符串裸换行（背包脚本此前无法编译） |

**孤儿面板确认跳过（5 个）**: daily_task（无实例化，功能在 quest_panel DailyTab）/ faction_store（无引用）/ upgrade（16 行空壳）/ synthesis（仅 gd 无引用）/ level_select（无引用，afk_level_selector 是另一文件）。

**新增 PANEL_ACCENTS**: player_master=紫 / help=青 / manufacture=紫 / mvp=金 / phase_master_skill=金。

**验证**: gdparse 全过；ui_unified_check 扩至 22 个脚本 + 20 个场景（含两批全部面板）。

---

## 九、v7.x 实机截图视觉审查 + 补图（2026-08-15 第三批）

**方法**: 新增 `scenes/tools/panel_tour.gd/.tscn` 截图巡览工具（窗口模式逐面板实例化→等待构建→截图存 `user://panel_tour/`，定时器驱动防单面板报错卡死），23 个面板全部实拍；AI 视觉模型逐张审查 + PIL 量化分析（内容包围盒/填充率/尺寸核对）。

**实拍发现并修复:**

| 问题 | 修复 |
|------|------|
| drops 物品格灰占位（TextureRect 无贴图=加载失败图标） | **AI 生成 7 个资源图标**（纳米/合金/晶体/能量/研究/许可/文献，agnes-image-2.1-flash，白底转透明→96px→`assets/ui/icons/res_*.png`）；材料格+文献格接线；许可按法则家族 tint；蓝图格接现有 icon_blueprint.svg |
| collection 列表纯文字无缩略图 | 列表行接 `UiAssetLoader.card_icon_for_list`（26px 缩略图） |
| modification/growth 左列缩略区是 16px 兵种字母占位（注释自认"占位图"） | 改用真实卡图（无图回退字母） |
| growth rarity_strip ColorRect 创建后从未挂载（死代码，稀有度条视觉缺失） | 删除死代码，改缩略框顶边 2px 表达 |
| store 行文字过小（视觉审查点名） | 行字号提升（名 13→15、信息/价 11→12、描述 10→11）；公司 Tab 34→38px、字号 12→13 |
| mvp 时长/星级基线不齐、击破分布标题左右不一致 | 双 label SHRINK_CENTER；分布标题居中 |
| mvp/growth 巡览空白（growth 根 visible=false；mvp 依赖 create() 入口） | 巡览工具补特例（_build/show_panel(null)/visible），两者实拍正常 |

**图标质量核验**: AI 视觉模型评审 7 图标横排样张——辨识度 4-5 星、风格统一（扁平霓虹）、无白边残留，零重生成。

**其它实拍结论**: 两批迁移面板尺寸/框架/✕ 渲染全部正确；daily_task 实拍为 132×108 破损小块（孤儿实锤，维持跳过）；settings 516×600、afk 692×764 特殊尺寸符合设计。

---

## 十、v10 背包卡图升级：一战段重生 + 缩略 384（2026-08-15 第四批）

**背景**: 背包实拍评审（造 11 张跨时代实例卡实拍）确认卡图 7/10，最大短板为**一战段与近未来段的画质断层**（早期卡近剪影、细节单薄），次为 256px 缩略偶发压缩感。

**任务 1 —— 一战段卡图重生（20 张，20/20 成功）:**

- **映射链权威化**: headless 跑 `tests/dump_wwi_icons.gd`（临时，已删）走 UiAssetLoader 真实解析链导出 `wwi_icon_map.json`——34 张 ww1 卡收敛为 **20 个视觉文件**（15 编号 vis_NNN + 5 命名 ww1_*.png，多卡共用图）。
- **重生**: `tools/regen_wwi_icons.py`——agnes-image-2.1-flash，提示词对齐 G 段（终焉守护者）描写密度 + 一战工业质感（铆接板缝/铆钉排布/泥污旧化/织物褶皱/皮质装具），严格 2D 正侧视面朝左。
- **部署**: 白底转透明→裁边缩放 512→enemy 原图 + player 水平翻转（复用 deploy_card_icons 管线规范），同步生成 384 缩略。
- **质检**: 视觉模型评审 6 张样张——细节密度 4-5 星、正侧视统一、抠图无白边，与"近未来级精细度"目标达标。
- 覆盖单位: 马克V/FT-17/马克II/精英马克V/A7V(Boss)/77mm 野战炮/81mm 迫击炮/要塞重炮/碉堡/骑兵/工兵/步枪兵/恩菲尔德王牌/MP18 突击兵×2/暴风精锐/MG08/维克斯/迫击炮组/福特救护车。

**任务 2 —— 缩略图 256→384:**

- `generate_card_icon_thumbnails.py --size 384` 全量重生成（270 张，enemy+player）。
- `ui_asset_loader.gd` THUMB_DIR_PREFIX 切换 `_thumb384/`（135 张同屏 ~80MB VRAM，可接受）；`_thumb256/`（14MB）无引用后删除。

**收尾管线**: `generate_card_foot_anchors.py` 重跑（新图 alpha 变化，脚/头锚点全量刷新）→ `--import` 全量入库 → 备份存档→造卡实拍→恢复存档（已验证零污染）。

**复验**: 背包实拍 + 视觉模型对比评审——一战卡"铆接装甲板缝/铆钉排布清晰可辨"，画质断层感明显减弱。

---

## 十一、v10.1 存量卡图边距审计与归一（2026-08-15 第五批）

**方法**: `tools/audit_card_margins.py` 全量扫描 enemy 原图 alpha 包围盒边距（约定：88% 留白 ≈ 每边 ~30px）。

**发现 20 张异常（三类）:**
| 类别 | 数量 | 文件 |
|------|------|------|
| 全出血（边距 0，内容顶满画布） | 5 | vis_009/010/028/032/033 |
| **1024 原图漏部署**（从未跑过 fit_square，直接 1024 入库） | 14 | E 段堡垒 vis_074~081 全部、vis_017/020/021/022/024、fut_inf_x9 |
| 临界（13px） | 1 | vis_034 |

**修复**: `tools/fix_edge_card_icons.py`——统一走 88% 留白正方形管线（裁边→88%→居中填充 512），每张同步 enemy 保存 + player 水平翻转重生成 + 384 缩略。E 段堡垒首次获得 512 规范版（顺带消除 4MB/张 VRAM 浪费）。复扫 **0 张贴边/临界**；脚/头锚点重跑 + --import；视觉复验"留白均匀、无裁切、无贴边"。

---

## 十二、v10.2 改造模块图标审计与修复（2026-08-15 第六批）

**范围**: `assets/ui/icons/mod_icons/`（85 张）在改造面板（modification_panel 28×28 模块卡）与背包改造 Tab（backpack INTEL 条目）两处的消费链。

**静态审计（通过）**: 85 个 icon 字段 ↔ 85 张 png ↔ 85 个 .import，零缺失/零孤儿；两处消费端均有 `ResourceLoader.exists` 守备 + 稀有度字母占位兜底。

**发现的真问题（视觉实拍确认）**: **85 张图标全部是白底不透明图**（alpha 全 255）——生成批次当年漏跑白底转透明，深色 UI 的 26×28 小格里渲染为刺眼白色方块；另有 3 张 1024×1024 未归一（mod_overdrive/mod_resonance/mod_special）。

**修复**: `tools/fix_mod_icons.py`——白底转透明（亮度 240→0 / 200→255 平滑过渡）+ 内容居中 84% 留白 + 统一 512×512。复扫 0 张不透明残留；`--import` 重导。

**复验（实拍）**: 备份存档 → 造 11 张卡 + 13 张跨兵种改造图纸 → 实拍背包改造 Tab + 改造面板模块区 → 恢复存档（零污染）。视觉模型确认两处"图标透明底正常、无白方块、无缺图、无字母占位"。

---

## 十三、v10.3 改造图标实心底修复（2026-08-15 第七批）

**用户反馈**: "有些改造透明背景有些是方形不透明""不只这2个"（相位护盾发生器/燃气轮机等）。

**根因（检测盲区）**: 85 张中有 **19 张是"实心单色烘焙底"**（灰绿/米黄/蓝灰等各不相同）——白底转透明对它们完全无效；且此前的"裁边+居中"处理给它们包了一圈透明边，**骗过了边缘不透明率检测**（只看最外 4px），视觉样张里深色底配深灰展示底也看不出来。含用户点名的 mod_shield（相位护盾发生器）/mod_engine（燃气轮机）。

**正确检测法**: 内容 bbox 内部实心率 >0.93 且四角不透明 → 实心方块底（真图标主体充满孔洞，率低）。

**修复**: 19 张全部 AI 重生成（agnes-image-2.1-flash，白底管线→透明，与其余 66 张风格归一；2 张网络抖动重试成功）。`tools/regen_solid_bg_mod_icons.py` 沉淀。复检实心底 **0 张**；`--import` 重导；含点名 mod 的背包改造 Tab 实拍复验。

**沉淀**: 实心率检测并入图标体检流程（audit_mod_bg 的边缘检测已被证明可被透明包边绕过）。

---

## 十四、v10.4 改造图标全量重生成·终结方案（2026-08-15 第八批）

**用户三轮反馈**: ①"有些透明有些方形不透明" → 19 张实心底修复；②"突击步枪化/冲锋枪改造/工程铲还有好多方形" → 定位**第三类缺陷：雾状底**（浅色底亮度 200~235 被白转透明打成 alpha 20~150 的半透明白雾，深色 UI 上呈奶白方雾，mod_digging 实锤：bbox 填充 98%/中位 alpha 47/亮度方差仅 28）。

**判断**: 三轮打地鼠证明历史批次来源混杂（白底/实心底/雾底三类），阈值修补永远追不全且白转透明本身会误伤浅色主体（打成半透明）。**放弃修补，85 张全量重生成**。

**执行**: `tools/regen_all_mod_icons.py`——85 个语义提示词全覆盖（磁盘↔提示词双向校验零差）、统一"深色主体+霓虹青蓝高光+纯白背景"提示词 → agnes-image-2.1-flash 生成 → 白转透明 → 84% 留白 512 部署。85/85 成功（中途修复一处脚本读序 bug）。

**三重终检全零**: ①bbox 实心方块 0 张；②半透明雾（10≤α≤150 占比>25%）0 张；③深底合成人眼近似样张干净。`--import` 重导；含全部点名 mod（相位护盾/燃气轮机/冲锋枪/突击步枪/工程铲）的背包改造 Tab 实拍复验通过。

---

## 十五、v10.5 符文图标审计与烤底修复（2026-08-15 第九批）

**用户诉求**: "检查符文图标设计，与游戏风格是否合适"。

**资产概况**: `assets/runes/{common,rare,epic,legendary}/` 共 98 张 PNG，映射 54 个符文定义（`data/runes.gd:icon_path_for` 自稀有度优先、legendary 全套兜底，无缺图）。消费方：`resource_slot_item`（稀有度瓷砖底+modulate 染色）、`bottom_instrument_bar` 槽位、`intelligence_hub_panel` 列表。

**设计判定（契合）**: 整体为"圆形彩绘宝石+中心符号+霓虹高光、圆外透明"风格，与深色霓虹科幻 UI 契合；图标内部颜色编码**类别**（攻击红/防御青/能量金/机动橙），稀有度由 UI 边框+modulate 承担——职责分离清晰，非缺陷。形状多样性（圆/八边形/菱形）属设计变化。

**缺陷（3 张烤底）**: `common/rune_energy_03`、`common/rune_mobility_01`、`epic/rune_attack_06` 带烘焙死的深色方形底（普通=深藏青 #191C21、史诗=深紫 #1C0E30，四角 alpha=255）。在深色审查底板上肉眼难辨（视觉模型初判"正常"），但 `resource_slot_item` 按稀有度 modulate 后烤底被染色，在稀有度瓷砖底上显形为深色方块——与改造图标同源缺陷，只是暴露场景更隐蔽。

**修复**: 不重生成（保留原画，与其余 95 张风格 100% 一致）——`tools/fix_rune_baked_bg.py`：径向环带方差检测圆盘边界（energy_03=424/512、mobility_01=412/512、attack_06=448/497；全程扫描防圆盘内部安静环带提前截断）→ 圆形羽化遮罩抠出 → 统一 995×995（主流尺寸）。

**复验**: 全量复审实心方块 **0 张**（98/98 圆外透明）；稀有度瓷砖+modulate 模拟图（与 resource_slot_item 同参数）三张修复位无缝融合、石体完整无裁切；`--import` 重导（exit 0）。

**沉淀**: 烤底类缺陷在深色审查底板上会"隐形"——图标审计必须模拟真实消费场景（底色+染色）复核，不能只看深底合成图。

---

## 十六、v10.6 符文圆盘尺寸归一（2026-08-15 第十批）

**用户反馈**: "符文在相位仪中大小不对"。

**定位**: 全量测量 98 张的圆盘直径占比——93 张贴边（1.0），**5 张只有 ~0.82**（1024 批次的 attack_03/defense_01/attack_07/defense_05/mobility_03，均为 common/rare 早期易得符文）。装进相位仪槽位后比同排符文小一圈，肉眼可辨。

**修复**: `tools/fix_rune_small_discs.py`——alpha 包围盒裁剪 → 放大到圆盘 ~98% 贴边 → 统一 995×995（与主流一致）。5/5 通过（dia 0.81-0.84 → 0.99-1.00，四角透明校验通过）。

**复验**: 全量缺陷 0（98 张全部圆外透明 + 直径占比 ≥0.9）；尺寸统一 98×(995,995)；`--import` 重导；相位仪栏实拍（4 槽装 3 修复 + 1 对照）视觉确认尺寸完全一致。

---

## 十七、v10.7 相位仪栏 13 槽满载图标右裁修复（2026-08-15 第十一批）

**用户反馈**: "符文在相位仪中右边会有图不全，战斗卡在相位仪中右方也会少"。

**根因（构建时序）**: `SlotIcon` 锚定铺满 `SlotIconClip`（`clip_contents=true`），其 `custom_minimum_size` 在 `_update_slot_panel`/`_build_slot_panel` 时按**当时的** `_slot_width`（初值 90）写死为 84×60；随后 deferred 的 `_fit_slots_to_bar()` 把 13 槽（green9+rune4）收窄到 ~72px，但图标 min 尺寸不刷新——锚定子节点被钳在 84px 宽、超出 ~70px 裁剪容器的部分被 `clip_contents` 切掉。战斗卡/符文共用同一 SlotIcon，所以两者右侧都缺。窗口 resize 触发 `_fit_slots_to_bar` 同样复发。

**修复**: `bottom_instrument_bar.gd` 新增 `_resync_slot_icon_min_sizes(available_h)`，在 `_fit_slots_to_bar()` 更新槽位尺寸后按新 `_slot_width` 重写每个槽 SlotIcon 的 min 尺寸（艺术区 = 宽-6 / 高-4，与 _update_slot_panel 同公式）。

**复验**: rune_bar_shot 工具升级为 13 槽满载实拍（9 卡 + 4 符文，1280×720）——修复前卡图/符文右侧被裁，修复后全部完整居中（视觉确认坦克双侧履带完整、符文圆盘正圆居中）。

---

## 十八、v13.1 战斗攻击方向感与阵营辨识（2026-08-16 第十二批）

**用户反馈**: "战斗中有些动画没有方向感也不知道那方是进攻方，谁进攻谁"。

**梳理结论**: 方向性原语已齐全（枪口火带方向/穿透光线/雷电弧/激光束/终极弹道），弹道类攻击方向感良好。缺口在三处：
1. **命中特效不分阵营**——`_impact_color` 只按武器类型+兵种取色，`is_player` 参数收到但未使用，双方打出的爆炸/火花同色，密集交火时无法分辨谁打的。
2. **伤害数字不分阵营**——normal 全白色、critical 全红色，敌人身上跳红数字与"我方被打"语义混淆。
3. **技能伤害无方向反馈**——卡牌周期技能单体伤害 `take_damage(damage, null)` 传 null 攻击者：受击无击退、无方向血溅（两者都依赖 attacker 定方向），纯粹"凭空掉血"。

**四处修复:**

| # | 文件 | 改动 |
|---|------|------|
| 1 | `vfx_impact_factory.gd` | 命中冲击环混入攻击方阵营色 55%（我方=青蓝/敌方=橙红，`SIDE_COLOR_*` 常量 + `side_color()`）；火花/碎片保持武器本色（武器辨识优先，阵营信息只承载在环上）。新增 `spawn_attack_tracer()`：攻击方→受击方阵营色细线（0.16s 淡出，<40px 不画，复用 beam 池）——无弹道的瞬发/技能伤害的方向感补足 |
| 2 | `card_periodic_skill_engine.gd` | 单体伤害以离目标最近的我方单位为视觉攻击源：拉追踪线 + 把攻击源传给 take_damage（激活既有的击退+方向血溅链路） |
| 3 | `damage_number_display.gd` | 新增阵营双色样式：`dmg_out`（我方输出=青）/`dmg_in`（敌方输出=暖红）/`critical_out`（敌方身上暴击=金色，红色留给"我方被打"语义）；`create_damage_number` 加可选 side 参数（缺省 "" 完全兼容旧调用） |
| 4 | `battle_hud.gd` | `unit_damaged` 信号自带受害方阵营（无友伤 → 受害方反推攻击方），`_on_unit_damaged` 直传 side；直接调用路径按 player_units/enemy_units 分组兜底；判定不了（基地/无分组）保持 neutral 白 |

**设计决策:**
1. 阵营色只承载在冲击环上（不动火花/碎片的武器本色）——此前刚修过"武器全同色"的辨识问题（v8.x），不能再丢武器特征。
2. 暴击红→金只改敌方受害侧——玩家侧暴击保持红色激情，敌方侧金色消除"敌人跳红数字像敌方动作"的歧义。
3. AoE/炮击不加追踪线——已有警告标记+抛物线弹道（天降方向语义明确），只有"无弹道凭空掉血"的单体伤害需要补。
4. DOT 数字不动——dot_* 样式按伤害元素分色（烧/毒/EMP/纳米）语义更优先。

**复验**: vfx_side_shot 工具实拍（左列我方青环×4 武器 / 右列敌方橙红环×4 / 双向追踪线 / 左青金右暖红伤害数字）——视觉确认全部符合：左列青色命中环、右列橙红、追踪线双色反向、数字配色正确。注：工具场景的 `_process` 签名必须为 `-> void`（`-> bool` 是 `--script` 模式 SceneTree 脚本惯例，场景节点上会导致虚函数不被调用、场景挂死）。

**报告结束**
