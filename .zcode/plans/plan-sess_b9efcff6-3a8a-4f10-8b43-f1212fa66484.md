# Phase War 界面一致性修复计划（P0/P1/P2 全做 + 金边重生科技风 PNG）

基于 `docs/界面一致性/visual_audit_report.html` + 三轮代码精确定位调查。已与用户确认：金色雕花 PNG 边框**重新生成科技风 PNG**；修复范围 **P0/P1/P2 全做**。

调查中修正报告两处误判：①顶部"调试栏"是 Godot 编辑器 F5 播放窗口工具条（非游戏内 UI），代码无需改；②`regan` 拼写错误不存在（源数据是正确的 `ally_fort_regen`）。

分 6 阶段，每阶段可独立验证、独立提交。预计 7 个阶段全部落地。

---

## 阶段 A：金色雕花边框 → 科技风 PNG（用户选定重生方案）

**根因**：`scripts/generate_battle_card_frames.py` 的 RARITIES prompt 用了 gold/ornate/ceremonial/engravings/crests/maximum ornamentation 等词，AI 产出华丽奇幻风。

**做法**：重写 prompt 为统一科技极简风——所有稀有度用"深色金属底 + 稀有度色发光线条 + 几何转角"的统一语言，**区分度靠颜色 + 发光强度，而非华丽程度**（这样不会回归"金边最华丽"的问题）。

| 稀有度 | 科技风配色（与统一后的 GC 稀有度色一致，见阶段 C） | 发光强度 |
|--------|---------------------------------------------------|---------|
| common | 枪铁灰 #6b7691 | 无发光，纯线条 |
| uncommon | 钢绿 #22c55e | 弱边缘光 |
| rare | 电蓝 #38bdf8 | 中边缘光 |
| epic | 紫 #c084fc | 强发光 + 转角节点 |
| legendary | 琥珀 #f59e0b | 强发光 + 脉冲转角 |
| mythic | 红 #ef4444 | 最强发光 + 全边脉冲 |

**改动文件：**
- `scripts/generate_battle_card_frames.py` — 重写 RARITIES 字典的 color_scheme/border_style/glow_level/ornament_level，统一改为"clean geometric tech frame, thin energy lines, angular corner brackets, flat metal panels, circuit-trace accents"；删除所有 gold/ornate/ceremonial/engraving/crest/maximum ornamentation 字样；复用 `regenerate_bad_frames.py` 的 NEGATIVE prompt；输出目录改 `assets/cards/frames/`（直接覆盖运行时路径）；新增 mythic 条目（当前缺）。
- `scripts/regenerate_bad_frames.py` — 同步更新 prompt 风格 + 加 mythic（保持与主脚本一致，作迭代修复用）。
- `scripts/ui_asset_loader.gd:281-287` `card_frame_path_for()` — 移除 mythic→legendary 回退（`r == "mythic": r = "legendary"`），让 mythic 用独立 PNG。

**执行**：运行重写后的 `generate_battle_card_frames.py` 生成 6 张 PNG 覆盖 `assets/cards/frames/`，人工/截图审查风格统一后定稿。

---

## 阶段 B：P0 调试信息泄露 / 占位图 / 翻译

| # | 文件 | 改动 |
|---|------|------|
| B1 | `scripts/ui/mod_effect_labels.gd:16-144` | 翻译表 match 补 3 条：`crit_mark_chance`→"暴击标注"、`crit_mark_bonus`→"标注暴伤"、`crit_mark_duration`→"标注持续"（命名口径参考 `module_effect_handler.gd:92` 注释） |
| B2 | `scripts/ui_asset_loader.gd:223-237` `load_tex()` | 开头加导入有效性校验：把 `Battlefield.gd:339-350` 的 `_is_import_marked_invalid` 逻辑抽成 `UiAssetLoader._is_import_valid(path)` 公共方法，`load_tex` 失败返回 null（不渲染橙色 missing-texture） |
| B2 | `scenes/ui/resource_slot_item.gd:225-226,279-281`、`modification_panel.gd:499-501,970-972`、`backpack_card_item.gd:1473`、`mod_slot_item.gd:39` | 裸 `load(icon_path)` 全改 `UiAssetLoader.load_tex(icon_path)`（转型失败返回 null，优雅降级） |
| B3 | `scenes/battlefield/Battlefield.gd:288-302` `_show_final_battle_subtitle()` | 裸 Label 包进 PanelContainer + StyleBoxFlat（bg `Color(0,0,0,0.55)` + 内边距 + 圆角），参考同文件 `_show_level_info_popup` 的面板范式 |

---

## 阶段 C：P1 配色体系统一（稀有度唯一源 + 清死代码）

**确立 `GC.get_rarity_color()`（`game_constants.gd:192`）为稀有度唯一权威源**（数值：common 灰/uncommon 绿/rare 蓝/epic 紫/legendary 琥珀/mythic 红，与阶段 A 科技风 PNG 配色一致）。

| # | 文件 | 改动 |
|---|------|------|
| C1 | `resources/game_constants.gd:192-200` | 校准为唯一权威值（与 design_tokens COLOR_RARITY_* 统一到灰/绿/蓝/紫/琥珀/红） |
| C2 | `resources/design_tokens.gd:197-202` | `COLOR_RARITY_*` 6 个 const 改为透传 `GC.get_rarity_color()`（保持常量名兼容现有引用，值随 GC），并 preload GC |
| C3 | `data/intel_manual_items.gd:83-91` | 删本地 `get_rarity_color()`，改转发 `GC.get_rarity_color()` |
| C4 | `scenes/ui/card_info_panel.gd:90-97` `RARITY_COLORS` | 删本地字典，header 色带改用 `GC.get_rarity_color()`（修复 legendary 误显粉色） |
| C5 | `data/runes.gd:40-45` `RARITY_COLORS` | 补 uncommon/mythic 档，数值对齐 GC（符文 4 档→6 档统一） |
| C6 | `scenes/ui/phase_instrument_selector.gd:211,184` | 荧光绿选中态文字改 `DT.COLOR_GREEN_UP`/边框改 `DT.COLOR_CYAN_TECH`，接入 design_tokens（替换 ~20 处硬编码 Color） |
| C7 | `scripts/ui_theme_manager.gd`、`scripts/ui_beautifier.gd`、`scripts/ui_theme_enhanced.gd`、`scenes/ui/enhanced_panel_base.gd` | 删 3 套死代码主题系统（grep 确认无外部引用后删除文件） |
| C8 | `managers/audio_manager.gd:8` + `resources/game_constants_clean.gd` | audio_manager 改 preload `game_constants.gd`；删 `game_constants_clean.gd` 历史残留 |

---

## 阶段 D：P1 布局结构统一

| # | 文件 | 改动 |
|---|------|------|
| D1 | `resources/design_tokens.gd` | 新增 `PANEL_SIZE_*` 常量：`PANEL_SIZE_LARGE(1180×640 养成面板)`、`PANEL_SIZE_MEDIUM(960×600)`、`PANEL_SIZE_SMALL(840×580)` 三档标准 |
| D2 | 各面板 tscn 根节点 `custom_minimum_size` | 养成面板（enhancement/modification/evolution/growth）统一 1180×640（已对齐，仅 backpack 1180×560 微调）；collection/reinforcement 960×600；intelligence_hub 840×580。硬编码尺寸改为 DT 常量引用（tscn 无法直接引用 const，则在 gd `_ready` 里 `custom_minimum_size = Vector2(DT.PANEL_SIZE_*)`） |
| D3 | `scenes/ui/modification_panel.tscn:350,399,472,481` | 改造站空白重排：MiddlePanel 设 `custom_minimum_size.x`；ActionDeck 上移；DetailPanel 默认态加占位提示文案（"选择左侧模块查看可装备单位"），消除右侧大片空白 |

---

## 阶段 E：P1 本地化（双语标题统一）

**统一格式**：推广 growth/modification/evolution 已用的"中文主标题 + 英文副标题双 Label"模式（主标题大字 + 副标题小字科技青色）。

| 面板 | 当前 | 改后 |
|------|------|------|
| card_enhancement | 单 Label "战术强化站  TACTICAL..." 双空格拼接 | 拆双 Label |
| collection | 单 Label "卡牌图鉴 COLLECTION" 空格拼接 | 拆双 Label |
| backpack | 单 Label "战斗卡阵列 · COMBAT ROSTER" 中点拼接（gd:263 + tscn:105 重复） | 拆双 Label，删 gd 重复字面量 |
| reinforcement | 单 Label "💪 强化面板"（无英文） | 加英文副标题 "REINFORCEMENT" |
| intelligence_hub | 单 Label "情报中心"（无英文） | 加英文副标题 "INTEL HUB" |

涉及文件：`card_enhancement_panel.tscn`、`collection_panel.tscn`、`backpack_panel.tscn`+`.gd`、`reinforcement_panel.tscn`、`intelligence_hub_panel.tscn`。

（项目无 i18n 机制且建翻译表是纯增量工作，本轮不做翻译表框架，仅统一现有双语格式。）

---

## 阶段 F：P2 字体与全局 Theme

| # | 文件 | 改动 |
|---|------|------|
| F1 | 新建 `resources/ui/default_theme.tres`（Theme 资源） | 设默认 font = Rajdhani-Regular（`DT.FONT_PATH_BODY`）+ default_font_size = DT.FONT_SIZE_MEDIUM；Button/Label 默认字号阶 |
| F2 | `project.godot` | `[gui]` 段加 `theme/custom = "res://resources/ui/default_theme.tres"`，全项目 Label 未 override 时自动用 Theme 默认 |
| F3 | 四养成面板 tscn | 清理 `theme_override_font_sizes` 硬编码（4 个文件，让它们继承全局 Theme，仅保留标题/数据等需特大的 override） |

**范围控制说明**：38 个 tscn 全量清理字号 override 工作量极大且易错，本轮 F3 只清四养成面板（最核心、改动收益最高）。其余面板通过 F1/F2 的全局 Theme 默认值获得基线改善（未 override 的 Label 自动用 Rajdhani + 标准字号），剩余 override 留待后续按需清理。这样用最小改动覆盖最大收益，避免一轮铺太大风险失控。

---

## 验证策略（每阶段）

- **阶段 A**：生成后用截图审查（`tools/enemy_card_review.html` 同款方式或游戏内背包截图）确认 6 档边框风格统一为科技极简、无奇幻华丽残留。
- **阶段 B-F**：每阶段改完跑 `Godot --headless --check-only`（确认无语法错误、133 卡构建通过）；阶段 C 后额外 grep 确认稀有度色无残留本地定义；阶段 D 后游戏内截图核对弹窗尺寸。
- **整体验证**：全部完成后启动游戏（`godot-run` skill）逐面板截图比对修复前后。

## 风险与回退
- 阶段 A PNG 生成质量有不确定性（AI 产出），prompt 需迭代，保留 `regenerate_bad_frames.py` 作修复入口；不满意可回退旧 PNG（git 跟踪）。
- 阶段 C 删死代码前 grep 确认零外部引用；阶段 C8 改 audio_manager 引用后必须跑 check-only。
- 阶段 F 全局 Theme 是新增项目级配置，若引发字体异常可注释 `project.godot` 的 theme 行立即回退。

## 执行顺序
A（金边）→ B（P0）→ C（配色）→ D（布局）→ E（本地化）→ F（字体）。A 和 B 无依赖可并行启动，但 A 依赖 C 的配色定稿（PNG 配色需与统一稀有度色一致），故实际 C 的配色校准先于 A 的 prompt 定稿。建议执行序：**C1 配色校准 → A 金边重生 → B P0 → C2-C8 配色清理 → D 布局 → E 本地化 → F 字体**。