# Phase War -- 背包视觉提升计划

> 目标：让背包中"战斗卡"、"改造"、"符文"三个标签下的卡片/条目在 80x120 小格内呈现更强的层次感、稀有度区分和交互反馈，整体风格与现有 Neon Battle HUD 保持一致。

---

## 一、现状诊断

### 1.1 当前结构

```
BackpackPanel (TabContainer)
  Tab 0: 战斗卡  -> GridContainer (8列) -> BackpackCardItem (80x120 PanelContainer)
           每个格子: Icon(TextureRect 72x72) + NameLabel + LvLabel
           边框: _apply_card_border_flat() 按稀有度设边框+shadow
           叠层: CardBackgroundUi(势力底图) + CardFrameUi(稀有度PNG框)
  Tab 1: 资源    -> GridContainer -> ResourceSlotItem (同结构)
  Tab 2: 改造    -> GridContainer -> Intel/Mod 列表项(Button动态创建)
  Tab 3: 属性提升 -> GridContainer -> StatBoostSlotItem
  Tab 4: 符文    -> GridContainer + 右侧 RuneInfoPanel(VBox)
```

### 1.2 核心问题

| # | 问题 | 影响 |
|---|------|------|
| P1 | 所有卡片使用完全相同的网格布局，视觉上"扁平化"，稀有度差异仅靠边框颜色体现 | 玩家难以快速扫描出高价值卡牌 |
| P2 | 改造标签下是纯文字按钮列表（Button.new()），没有图标、没有卡片形态、没有稀有度视觉编码 | 改造条目看起来像菜单选项而非游戏资产 |
| P3 | 符文标签的格子只有基础面板样式，符文之语激活状态无视觉提示 | 符文系统存在感极低 |
| P4 | Hover 效果单一（仅背景色变化），缺少微动画和深度感 | 交互反馈冷淡 |
| P5 | 等级/星级信息仅以一行小字呈现，未与视觉层次融合 | 养成进度不直观 |
| P6 | 空槽位与有卡牌的槽位视觉对比弱 | 背包容量感知模糊 |
| P7 | 势力底图和稀有度框存在，但在 80x120 小格内叠加后显得杂乱 | 信息过载 |

### 1.3 约束条件

- 背包格固定 80x120px（SLOT_SIZE），不可放大
- 8列网格，6px间距，面板宽度约 680px
- 性能敏感：每帧可能有 50+ 个卡片实例，不能有逐帧 _draw() 或粒子
- 现有 CardFrameUi / CardBackgroundUi 体系必须兼容
- 风格：深色科幻霓虹（#060A14 底色，青色/紫色霓虹点缀）

---

## 二、设计原则

1. **稀有度优先**：通过背景渐变、光晕、边框粗细三层编码稀有度，而非仅靠边框色
2. **信息分层**：图标 > 名称 > 等级/星级 > 费用，每层有明确的字号/颜色/位置规范
3. **微交互**：Hover 时卡片上浮 + 边框发光增强，点击时有缩放回弹
4. **类型差异化**：战斗卡/改造/符文各有独立的视觉语言，互不混淆
5. **零额外渲染开销**：所有效果用 StyleBoxFlat + Tween + z_index 实现，不用 CPUParticles2D

---

## 三、分模块改造方案

### 3.1 战斗卡标签（CombatCardsTab）

#### 3.1.1 卡片背景层级重构

**现状**：纯色底 + 稀有度边框 + 势力底图(透明PNG) + 稀有度框(透明PNG) = 4层叠加，80x120格内混乱

**方案**：精简为 3 层，按稀有度分组

```
层级从下到上：
L0: 面板底色（StyleBoxFlat.bg_color）-- 按稀有度不同底色
L1: 势力底图（CardBackgroundOverlay）-- 透明度统一降至 0.15（原默认）
L2: 稀有度框（CardFrameOverlay）-- 保持不变
```

具体底色方案：

| 稀有度 | 底色 | 边框 | Glow | 角标 |
|--------|------|------|------|------|
| Common | #1A1E28 (0.12,0.12,0.16) | 1px 灰 | 无 | 无 |
| Uncommon | #14201A | 1.5px 绿 | 2px 柔光 | 无 |
| Rare | #121A28 | 2px 蓝 | 3px 柔光 | 左上角 cost badge |
| Epic | #1A1428 | 2px 紫 | 4px 柔光 | cost badge + 右上角星级 |
| Legendary | #282014 | 2.5px 金 | 6px 脉冲 | cost + 星级 + 金色底纹 |
| Mythic | #281420 | 3px 粉 | 8px 脉冲 | cost + 星级 + 粉紫渐变底纹 |

#### 3.1.2 图标区域优化

**现状**：72x72 图标 + 名称 + 等级，名称和等级挤在一起

**方案**：IconRow 内部改为 HBox 布局

```
IconRow (HBoxContainer):
  |-- [Icon] 70x70 (expand fill, centered)
  |-- [NameLabel] right, rarity-colored font, max 1 line
  |-- [CostBadge] top-left of host (已有)
  |-- [StarBadge] top-right of host (新增)
```

底部信息栏（独立于 IconRow）：
```
BottomBar (HBoxContainer, 固定在卡片底部 28px):
  |-- [LvLabel] left, 10px, dim gray "Lv.5"
  |-- [StarIndicator] center, 9px, gold "★★★☆☆"
  |-- [TypeIcon] right, 12px, combat_kind emoji
```

#### 3.1.3 Hover 动效

```gdscript
# 在 _gui_input MOUSE_ENTERED 时:
var tween := create_tween()
tween.tween_property(self, "modulate", Color(1, 1, 1, 1.1), 0.1)
# 同时切换 StyleBoxFlat 为 hover 版本（增大 shadow + 提高 border alpha）

# MOUSE_EXITED:
tween.tween_property(self, "modulate", Color(1, 1, 1, 1), 0.15)
# 恢复原始样式
```

#### 3.1.4 拖拽预览增强

**现状**：拖拽时显示原卡片缩略图

**方案**：拖拽预览增加 rarity 色边 + 半透明背景

### 3.2 改造标签（Intel/ModificationTab）

#### 3.2.1 改造条目卡片化

**现状**：纯 Button.new() + VBox + Label，没有任何卡片视觉特征

**方案**：创建 `modification_slot_item.tscn`，复用 BackpackCardItem 的结构但简化

```
ModificationSlotItem (PanelContainer, 80x120):
  |-- VBox
      |-- ContentMargin (3px)
          |-- InnerVBox
              |-- IconRow (VBox)
                  |-- ModIcon (TextureRect, 56x56) -- 改造图标居中
                  |-- ModName (Label, 10px, rarity-colored)
              |-- BottomRow (HBoxContainer)
                  |-- ModType (Label, 9px, dim) -- "装甲/武器/通用"
                  |-- Spacer (Control, expand)
                  |-- InstallStatus (Label, 9px) -- "已安装"/"可安装"/"冲突"
```

#### 3.2.2 改造状态编码

| 状态 | 边框色 | 背景 | 图标 | 文字 |
|------|--------|------|------|------|
| 可安装 | Rarity 色 | 正常 | 无 | 绿色 "可安装" |
| 已安装 | 绿色 | 绿色微光底 | ✓ 徽标 | 绿色 "已装备" |
| 不适用 | 灰色 | 降低透明度 0.5 | ⊘ 徽标 | 灰色 "不适用" |
| 冲突/槽满 | 红色 | 红色微光底 | ✗ 徽标 | 红色 "冲突" |
| 图纸未解锁 | 暗灰 | 极暗底 | ? 徽标 | 暗灰 "未解锁" |

#### 3.2.3 改造稀有度底纹

与战斗卡一致，按改造稀有度设置不同的背景底色和 glow：

```gdscript
# modification_slot_item.gd
func set_mod(mod_id: String, mod_data: Dictionary, status: String) -> void:
    var rarity: String = mod_data.get("rarity", "common")
    var rarity_col: Color = GC.get_rarity_color(rarity)
    # 设置面板底色
    var style := _get_rarity_style(rarity)
    add_theme_stylebox_override("panel", style)
    # 设置名称颜色
    name_label.add_theme_color_override("font_color", rarity_col)
```

### 3.3 符文标签（RunesTab）

#### 3.3.1 符文格子增强

**现状**：与其他标签共用 BackpackCardItem，但符文不是 CardResource，显示简陋

**方案**：创建 `rune_slot_item.tscn`，专用符文视觉

```
RuneSlotItem (PanelContainer, 80x120):
  |-- VBox
      |-- ContentMargin
          |-- RuneIconArea (Control, 70x70)
              |-- RuneIcon (TextureRect, centered)
              |-- RuneGlow (ColorRect, z_index=-1, 径向渐变模拟发光)
          |-- RuneName (Label, 10px, purple)
      |-- RuneStatsRow (HBoxContainer, bottom 28px)
          |-- RuneSetCount (Label, 9px, gold) -- "套装: 3/6"
          |-- Spacer
          |-- ActiveIndicator (Label, 9px) -- "激活" or "未激活"
```

#### 3.3.2 符文激活状态视觉

```
激活的符文：
  - 紫色外发光 (StyleBoxFlat.shadow_color = purple, shadow_size = 4)
  - 图标周围有微弱粒子效果（预烘焙的发光纹理，非实时粒子）
  - 底部 Gold 条显示"已激活"

未激活的符文：
  - 普通灰色边框
  - 图标透明度 0.6
  - 底部显示"需要 X 个同类符文激活"
```

#### 3.3.3 符文之语面板联动

当符文之语被激活时，右侧 RuneInfoPanel 的对应条目增加：
- 金色边框高亮
- 效果描述使用 RichTextLabel BBCode 彩色标注数值
- 顶部增加一个总览条："符文之语 [名称] 已激活"（紫色底+金色字）

### 3.4 全局统一增强

#### 3.4.1 空槽位视觉

**方案**：空槽位不再是简单的灰色面板，而是显示：
- 虚线边框（StyleBoxFlat.border_width + 自定义虚线纹理，或用 4 个短线 ColorRect 拼）
- 中央 "+" 号图标（淡灰色）
- Hover 时显示 tooltip："拖入卡牌" 或 "空格位"

#### 3.4.2 网格分隔线

在 GridContainer 的每个 item 之间增加微妙的分隔效果：
- 利用 GridContainer 的 h_separation/v_separation = 6px
- 在 scroll container 背景上绘制微弱的网格线（使用 ColorRect + _draw() 在 ScrollContainer 父节点上）

#### 3.4.3 标签页切换动效

```gdscript
# TabContainer tab_changed 信号:
func _on_tab_changed(tab_idx: int) -> void:
    var tween := create_tween()
    tween.tween_property(scroll_container, "modulate:a", 0.7, 0.05)
    tween.tween_property(scroll_container, "modulate:a", 1.0, 0.15)
```

#### 3.4.4 批量获得卡牌时的入场动画

新卡进入背包时：
```gdscript
func _add_card_item(grid, card, at_top=false) -> void:
    var item = _create_card_item(card)
    item.modulate.a = 0
    item.scale = Vector2(0.8, 0.8)
    grid.add_child(item)
    var tween := create_tween()
    tween.tween_property(item, "modulate:a", 1.0, 0.2)
    tween.tween_property(item, "scale", Vector2(1, 1), 0.2).set_trans(Tween.TRANS_BACK)
```

---

## 四、实施优先级与阶段

### Phase 1 -- 立竿见影（1-2天）

| 任务 | 文件 | 工作量 |
|------|------|--------|
| 改造条目卡片化 (modification_slot_item.tscn) | scenes/ui/modification_slot_item.* | 中 |
| 改造状态编码 (颜色/图标/文字) | modification_panel.gd | 小 |
| 改造稀有度底色 | modification_slot_item.gd | 小 |
| 空槽位增强 (+号图标+虚线边框) | backpack_card_item.gd | 小 |

**预期效果**：改造标签从"菜单列表"变为"卡片网格"，视觉一致性大幅提升

### Phase 2 -- 深度优化（2-3天）

| 任务 | 文件 | 工作量 |
|------|------|--------|
| 战斗卡背景层级重构 (底色/边框/glow) | backpack_card_item.gd | 中 |
| 战斗卡 Hover 动效 (Tween) | backpack_card_item.gd | 小 |
| 战斗卡底部信息栏 (Lv + Star + Type) | backpack_card_item.tscn + .gd | 中 |
| 符文专用格子 (rune_slot_item.tscn) | scenes/ui/rune_slot_item.* | 中 |
| 符文激活/未激活状态视觉 | backpack_panel.gd (refresh_runes_tab) | 小 |

**预期效果**：战斗卡和符文的稀有度识别度大幅提升，交互反馈更丰富

### Phase 3 -- 精细打磨（1-2天）

| 任务 | 文件 | 工作量 |
|------|------|--------|
| 批量获得卡牌入场动画 | backpack_panel.gd (_add_card_item) | 小 |
| 标签页切换微动效 | backpack_panel.gd (_on_tab_changed) | 小 |
| 拖拽预览增强 | backpack_card_item_drag.gd | 小 |
| 全局网格分隔线效果 | backpack_panel.tscn | 小 |
| 性能测试与调优 | -- | 中 |

**预期效果**：细节体验完善，整体流畅度验证

---

## 五、技术注意事项

### 5.1 性能

- 所有视觉效果使用 StyleBoxFlat 缓存（静态字典），避免每帧 new
- Hover 动效用 Tween 而非 _process()
- 不使用 CPUParticles2D（背包场景粒子预算为 0）
- 符文发光用预烘焙的 glow texture（res://assets/effects/rune_glow.png），不用实时 shader

### 5.2 兼容性

- 改造卡片化需保持与现有 modification_panel 的信号连接（pressed -> _on_mod_selected）
- 战斗卡的 CardFrameUi / CardBackgroundUi 体系不变，只调整底色和边框
- 所有新创建的 tscn 必须遵循 Godot 节点声明顺序（先下后上）

### 5.3 美术需求

| 资源 | 规格 | 用途 |
|------|------|------|
| rune_glow.png | 128x128, 径向渐变紫色 | 符文激活发光 |
| empty_slot_plus.svg | 32x32 | 空槽位 + 号 |
| status_badge_installed.svg | 16x16 | 已安装 ✓ |
| status_badge_conflict.svg | 16x16 | 冲突 ✗ |
| status_badge_incompatible.svg | 16x16 | 不适用 ⊘ |
| star_gold.svg | 12x12 | 星级指示 |

---

## 六、验收标准

1. 打开背包面板，改造标签下的条目不再是纯文字按钮，而是带有图标和状态的卡片格
2. 战斗卡中 Legendary/Mythic 稀有度的卡牌在网格中明显区别于 Common 卡牌（底色+边框+光晕三层差异）
3. 鼠标 Hover 任意卡片时，有可见的上浮/发光效果（0.1-0.2秒过渡）
4. 符文标签中，已激活的符文有紫色发光效果，未激活的暗淡显示
5. 空槽位有明显的 "+" 标识，与有卡牌的槽位区分清晰
6. 背包打开时，新加入的卡牌有淡入动画
7. Godot --check-only 或实际运行时无性能回退（FPS 不低于改造前）

---

## 七、参考设计

- 现有 DesignTokens 配色体系（COLOR_ACCENT_CYAN / COLOR_ACCENT_PURPLE / COLOR_GOLD）
- 现有 GC.get_rarity_color() 返回的 6 种稀有度色
- 现有 CardFrameUi PNG 卡框（5:8 比例透明中心）
- 现有 CardBackgroundUi 势力底图
- HTML 预览模式：可用浏览器打开 scenes/tools/card_ui_preview.tscn 导出的 HTML 查看效果
