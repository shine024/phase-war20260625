# 背包战斗卡/改造/符文面板 HTML 对齐修订方案

## 修订目标

按 `docs/design_mockups/背包面板重设计.html` 的设计语言，把背包 3 个 Tab（战斗卡/改造/符文）的代码实现严格对齐 HTML 设计稿，**修好之前"卡图不显示"的根因 bug**。

## 核心发现（根因）

**Icon 不显示的根因**：`resource_slot_item.gd` 三处（_ready L63 / _refresh_lore L268 / _refresh_rune L456）写 `stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_COVERED`，但**注释说 COVERED、字面量却是 `5`**。Godot 4 枚举 `STRETCH_KEEP_ASPECT_CENTERED=5`（留白模式），`STRETCH_KEEP_ASPECT_COVERED=6`（填满模式）。CENTERED 模式让 512×512 原图在 56×56 容器里只显示中间一小块 → "闪一下就看不到"。

`backpack_card_item.gd` 同样问题：三处写 `STRETCH_KEEP_ASPECT_COVERED` 但字面量是 `5`（CENTERED）。

## 修订范围（3 个文件）

### 文件 1：`scenes/ui/resource_slot_item.gd`（改造 + 符文瓷砖）

**修复点 A：Icon stretch_mode 字面量 bug（核心）**
- `_ready` L63：`icon_rect.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_COVERED`（去掉字面量 `5`，用枚举常量）
- `_refresh_lore` L268：同上
- `_refresh_rune` L456：同上

**修复点 B：tscn 第 31 行 expand_mode**
- `expand_mode = 1`（EXPAND，会让 TextureRect 被父容器尺寸约束，可能导致压缩）→ `expand_mode = 2`（EXPAND_IGNORE_SIZE，让 TextureRect 忽略贴图固有尺寸自由布局）

### 文件 2：`scenes/ui/backpack_card_item.gd`（战斗卡格子）

**修复点 C：Icon stretch_mode 字面量 bug**
- `_ensure_compact_slot_structure` L604：`icon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_COVERED`（去掉字面量）
- `_layout_compact_art_clip` L645：同上
- `_apply_card_icon_to_clip` L664：同上

**修复点 D：name-line / stat-line 分离（HTML 设计稿要求）**
当前 `_build_bottom_info_line(c)` 把「兵种|Lv.x/10|改N/M|力N」4 段塞进行 LvLabel 一行。HTML 设计稿要求 footer 区域分两行：
- name-line：卡名（已有 CompactTextVBox/NameLabel）
- stat-line：`Lv.9 · 改7/9` + 战力 `2148`（左右对齐）

修订：把 CompactTextVBox 从单 NameLabel 扩展为 NameLabel + StatLine（HBoxContainer：左侧 Lv+改 / 右侧 战力），删除 LvLabel 的混合信息。

**修复点 E：instance-no 独立角标（HTML 设计稿要求）**
HTML 设计稿中实例编号 `#2` 是右下角独立小角标（`.instance-no`）。当前是卡名后缀字符串。
修订：新增 `_ensure_instance_no(c)` 装饰层，绝对定位右下角显示 `#N`（仅 instance_id 非空时）。

**修复点 F：空槽清理装饰（修潜在 bug）**
`_set_empty_style` 不隐藏 v9 装饰层，池化复用空槽时会残留。修订：在 `_set_empty_style` 末尾调 `_hide_decoration("RarityTopStrip")` 等 4 个隐藏。

### 文件 3：`scenes/ui/backpack_panel.gd`（数据准备）

**修复点 G：refresh_intel_tab 签名纳入 install_count**
当前签名只含 mod_id 集合，装配计数变化不刷新。修订：把 `mod_id#install_count` 拼接纳入签名。

**修复点 H：_add_rune_item 死代码移除**
L1475-1477 `if "modulate" in item:` 块计算 border_color 但没用，最后无条件 `item.modulate = WHITE` 覆盖了 extra_data 里的 darkened 效果。修订：删除该死代码块，保留 `modulate = WHITE`（让已装备瓷砖靠 extra_data.runwword_active 边框 + RuneEquippedDot 区分，不靠整体变暗）。

## 不改动的部分（向后兼容）

- **TabIndex 枚举 / 节点路径 / 对象池机制**：保持不变
- **CardResource 字段访问**：保持不变
- **MTG 视图分支**（`BACKPACK_USE_MTG_CARD_FACE=false` 默认不走）：保持不变
- **相位仪 Tab**：不在本次范围（用户没要求）
- **入场动画 / hover 动效**：保持不变

## 验证方式

修订完成后，启动游戏（非 headless）打开背包：
1. **战斗卡 Tab**：每张卡应显示卡图填满图标区（不再留白）+ name-line（卡名）+ stat-line（Lv/改 · 战力）+ 右下 #N 角标
2. **改造 Tab**：每个瓷砖显示改造图标填满（不再留白）+ 左侧色条 + 右上"N 卡"装配计数
3. **符文 Tab**：每个瓷砖显示符文图标填满 + 顶部菱形 + 底部星要求 + 紫色效果行

## 风险评估

- **低风险**：stretch_mode 字面量修复（注释已经写明意图 COVERED，只是字面量错）
- **低风险**：tscn expand_mode 修复（IGNORE_SIZE 是 TextureRect 标准做法）
- **中风险**：name-line/stat-line 分离（需要扩展 CompactTextVBox 结构，可能影响 NameLabel 现有引用）
- **中风险**：instance-no 新增装饰层（绝对定位，需调试 offset 不与其他装饰冲突）

## 工作量预估

约 8-12 处编辑，集中在 3 个文件。完成后用 Godot --check-only 验证语法 + 启动游戏实机验证视觉效果。