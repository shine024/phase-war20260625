# 统一情报面板修订计划

> **创建日期**: 2026-06-01
> **状态**: 待审核
> **目标**: 移除所有悬停情报面板，只保留点击情报面板，三处点击共用一个 `CardInfoPanel`，背包场景多显示拆解按钮，面板展示战斗卡全部相关情报。

---

## 一、目标陈述

### 1.1 核心变更

| 现状 | 目标 |
|------|------|
| 背包卡片悬浮 → 弹出 CardInfoPanel | **移除** — 悬停不再弹出任何信息 |
| 相位仪槽位悬浮 → 弹出 CardInfoPanel | **移除** — 悬停不再弹出任何信息 |
| 战场单位悬浮 → 弹出 CardInfoPanel | **移除** — 悬停不再弹出任何信息 |
| 背包卡片点击 → CardDetailPopup + CardInfoPanel | **保留** — 使用统一面板，带拆解按钮 |
| 相位仪槽位点击 → BackpackPanel 弹窗 或自建 Window | **统一** — 使用统一面板，不带拆解按钮 |
| 战场单位点击 → UnitInfoPanel → CardInfoPanel | **保留** — 使用统一面板，不带拆解按钮 |

### 1.2 信息完整性

统一情报面板需展示战斗卡相关**所有情报**：

| 类别 | 字段 | 当前 CardInfoPanel 是否显示 |
|------|------|:---:|
| **基础信息** | | |
| 卡牌名称 | `display_name` | ✅ |
| 卡牌类型 | `card_type`（战斗卡/能量卡/法则卡） | ✅ |
| 战斗定位 | `combat_kind`（轻装/装甲/支援/空中/堡垒） | ✅ type_label |
| 稀有度 | `rarity` | ❌ **缺失** |
| 能量消耗 | `energy_cost` | ❌ **缺失** |
| 时代 | `era`（一战/二战/冷战/现代/近未来） | ❌ **缺失** |
| 武器标签 | `weapon_label`（步枪/机枪等） | ❌ **缺失** |
| **三维攻防** | | |
| 生命值 | HP（卡片模式: BackpackCombatPreview 估算值；单位模式: 当前/最大） | ✅ |
| 攻击力 | 对轻装/装甲/空中 三维攻击 | ✅ |
| 防御力 | 防轻装武器/防装甲武器/防空 三维防御 | ✅ |
| 射程 | `attack_range` | ✅ |
| 攻速 | `attack_interval` | ✅ |
| 移速 | `move_speed` | ✅ |
| 攻击准备/前摇 | `attack_X_windup` | ✅ 明确排除 |
| **特殊词条** | | |
| 减伤 | `damage_reduction` | ✅ 单位模式 |
| 闪避 | `dodge_chance` | ✅ 单位模式 |
| 暴击 | `crit_chance` / `crit_damage_bonus` | ✅ 单位模式 |
| 吸血 | `lifesteal` | ✅ 单位模式 |
| 穿甲 | `armor_penetration` | ✅ 单位模式 |
| 溅射 | `splash_damage` | ✅ 单位模式 |
| 连锁 | `chain_chance` | ✅ 单位模式 |
| 击杀护盾 | `shield_on_kill` | ✅ 单位模式 |
| 回血 | `hp_regen` | ✅ 单位模式 |
| 变异词条 | 6 种变异标记 | ✅ 单位模式 |
| **养成信息** | | |
| 星级/强化 | `enhance_level` + `BlueprintManager` | ✅ desc_label |
| 进化阶段 | `evolution_stage` | ❌ **缺失** |
| 进化路径 | `evolution_paths` | ❌ **缺失** |
| 突破次数 | `BlueprintManager.get_card_breakthroughs` | ❌ **缺失** |
| 等级/Lv | `BlueprintManager.get_card_xp_progress` | ❌ **缺失** |
| **势力变体** | | |
| 势力 | `faction_id` | ❌ **缺失** |
| 势力等级 | `faction_level` | ❌ **缺失** |
| **战场附加信息**（仅单位模式） | | |
| 军衔角标 | `RankDisplayUi.resolve_from_unit` | ✅ |
| 被动法则加成 | `PhaseLawManager.equipped_passive_laws` | ✅ |
| 主动法则 | `PhaseLawManager.equipped_active_laws` | ✅ |
| **描述** | | |
| 规则描述 | `description` | ✅ |
| 风味文本 | `flavor_text` | ✅ |
| **操作按钮** | | |
| 拆解 | 仅背包场景 | ✅ |
| 装备到相位仪 | 法则卡/能量卡在背包场景 | ✅（保留） |
| 关闭 | 背包弹窗模式 | ✅ |

---

## 二、受影响文件清单

### 2.1 需修改的文件

| # | 文件路径 | 改动类型 | 改动说明 |
|---|---------|---------|---------|
| 1 | `scenes/ui/card_info_panel.gd` | **重写** | 扩展卡片模式显示（加稀有度/能量/时代/武器/词条摘要/养成信息），新增"场景模式"参数控制拆解按钮可见性 |
| 2 | `scenes/ui/card_info_panel.tscn` | **修改** | 新增稀有度标签节点、能量消耗节点、养成信息区 |
| 3 | `scenes/ui/backpack_panel.gd` | **修改** | `show_card_detail` 传入"背包模式"标志，拆解按钮改由面板内部管理 |
| 4 | `scenes/ui/backpack_panel.tscn` | **修改** | `CardDetailPopup` 结构简化：只保留 PopupPanel 壳 + CloseButton，内嵌 CardInfoPanel 实例 |
| 5 | `scenes/ui/phase_slot.gd` | **修改** | 移除悬浮情报面板逻辑（`_on_mouse_entered/_on_mouse_exited` → 不再调用 `_show_card_info_panel`），保留点击发射 `slot_clicked` 信号 |
| 6 | `scenes/ui/backpack_card_item_actions.gd` | **修改** | 移除 `on_mouse_entered`/`on_mouse_exited`/`show_card_info_panel`/`hide_card_info_panel` 全部悬浮逻辑 |
| 7 | `scenes/ui/backpack_card_item.gd` | **修改** | 移除 `_affix_hover_seq` 等悬浮相关变量，断开 `mouse_entered/mouse_exited` 信号连接 |
| 8 | `scenes/ui/phase_instrument_panel.gd` | **修改** | 点击槽位不再调 `BackpackPanelScript.open_card_detail`（背包弹窗），改为使用统一面板 + "卸下"按钮 |
| 9 | `scenes/ui/unit_info_panel.gd` | **微调** | 传入"战场模式"标志（隐藏拆解按钮） |
| 10 | `scenes/ui/battle_click_overlay.gd` | **微调** | 确认无残留悬浮相关代码 |
| 11 | `scenes/ui/bottom_instrument_bar.gd` | **修改** | 底部栏卡牌点击不再调用 `BackpackPanelScript.open_card_detail`，改用统一面板 |

### 2.2 可删除/废弃的代码

| 位置 | 代码 | 原因 |
|------|------|------|
| `backpack_card_item.gd` L25 | `ENABLE_HOVER_AFFIX_TOOLTIP` | 悬浮功能整体移除 |
| `backpack_card_item.gd` L26 | `ENABLE_CARD_HOVER_TOOLTIP_TEXT` | 悬浮功能整体移除 |
| `backpack_card_item.gd` | `_affix_hover_seq` / `_AFFIX_HOVER_DELAY_SEC` | 悬浮防抖逻辑移除 |
| `backpack_card_item_actions.gd` | 全部 `on_mouse_entered`/`on_mouse_exited`/`show_card_info_panel`/`hide_card_info_panel` | 悬浮功能整体移除 |
| `phase_slot.gd` | `_show_card_info_panel`/`_hide_card_info_panel`/`_is_hovering`/`CardInfoPanel`/`CardInfoPanelScene` const | 悬浮功能整体移除 |
| `phase_instrument_panel.gd` | `_show_detail_popup_for_card()` 方法 | 被统一面板替代 |

### 2.3 不需要修改的文件

| 文件 | 原因 |
|------|------|
| `scenes/ui/unit_info_panel.tscn` | 已是最小结构（1×1 空壳），无需改动 |
| `scenes/ui/backpack_combat_preview.gd` | 作为统计计算工具保留，CardInfoPanel 继续调用 |
| `resources/unit_stats.gd` | 数据模型无变化 |
| `resources/card_resource.gd` | 数据模型无变化 |

---

## 三、详细实施步骤

### 阶段 A：移除悬停情报面板（3 个文件）

#### A1. `scenes/ui/backpack_card_item.gd`

**当前状态**：
- L25: `ENABLE_HOVER_AFFIX_TOOLTIP := false`（已关闭，但代码存在）
- L26: `ENABLE_CARD_HOVER_TOOLTIP_TEXT := false`
- 变量: `_affix_hover_seq`, `_AFFIX_HOVER_DELAY_SEC`
- `mouse_entered` / `mouse_exited` 信号连接到 `BackpackCardItemActions`

**改动**：
1. 删除 `ENABLE_HOVER_AFFIX_TOOLTIP`、`ENABLE_CARD_HOVER_TOOLTIP_TEXT` 变量
2. 删除 `_affix_hover_seq`、`_AFFIX_HOVER_DELAY_SEC` 变量
3. 在 `_ready()` 或初始化中**移除** `mouse_entered.connect(_on_mouse_entered)` 和 `mouse_exited.connect(_on_mouse_exited)` 的连接（或保留连接但在回调中直接 return）
4. 删除对 `BackpackCardItemActions.on_mouse_entered/on_mouse_exited` 的调用

#### A2. `scenes/ui/backpack_card_item_actions.gd`

**当前状态**：4 个静态方法全部是悬浮逻辑

**改动**：
- 删除 `on_mouse_entered()`、`on_mouse_exited()`、`show_card_info_panel()`、`hide_card_info_panel()` 4 个方法
- 删除 `CardInfoPanel`、`CardInfoPanelScene` const
- 如果该文件变为空文件，考虑直接删除

#### A3. `scenes/ui/phase_slot.gd`

**当前状态**：
- `mouse_entered` → `_on_mouse_entered` → `_show_card_info_panel()`
- `mouse_exited` → `_on_mouse_exited` → `_hide_card_info_panel()`
- `_show_card_info_panel` / `_hide_card_info_panel` 完整方法
- 引用 `CardInfoPanel` / `CardInfoPanelScene`

**改动**：
1. 移除 `CardInfoPanel` / `CardInfoPanelScene` const
2. 移除 `_is_hovering` 变量
3. 移除 `_ready()` 中的 `mouse_entered.connect(_on_mouse_entered)` 和 `mouse_exited.connect(_on_mouse_exited)`
4. 删除 `_on_mouse_entered()`、`_on_mouse_exited()`、`_show_card_info_panel()`、`_hide_card_info_panel()` 方法

---

### 阶段 B：统一点击情报面板（5 个文件）

#### B1. `scenes/ui/card_info_panel.gd` — 核心重写

**当前卡片模式显示（`_refresh_card_display`）只显示 5 项**：
- name_label, type_label, summary_label, desc_label, flavor_label

**需新增显示**：
1. **稀有度** — 在名称行旁边或下方显示稀有度文字（带颜色）
2. **能量消耗** — `⚡{cost}` 显示
3. **时代** — `era` 对应 "一战/二战/冷战/现代/近未来"
4. **武器标签** — `weapon_label`（步枪/机枪/迫击炮等）
5. **词条摘要** — 复用已有的 `_build_affix_summary_lines(stats)` 逻辑（当前仅单位模式调用）
6. **养成信息** — 等级、突破次数、进化阶段

**新增公共方法**：
```gdscript
## 设置面板模式（控制操作按钮可见性）
func set_panel_mode(mode: int) -> void:
    # MODE_BACKPACK = 0  → 显示拆解按钮 + 装备按钮（法则/能量卡）
    # MODE_PHASE_INSTRUMENT = 1  → 不显示操作按钮
    # MODE_BATTLEFIELD = 2  → 不显示操作按钮
```

**改动 `_refresh_card_display(card)`**：
- 扩展 type_label 格式：`"战斗卡 — 装甲／坦克 · 一战 · 步枪"`
- summary_label 保持 `BackpackCombatPreview.build_line(card)` 估算值
- desc_label 增加：词条摘要（如有）、养成等级、进化阶段
- 调用 `set_panel_mode()` 之前设置的 `_current_mode` 决定是否显示操作按钮

**新增节点引用**：
- `rarity_label: Label` — 稀有度文字（带颜色）
- `cost_label: Label` — 能量消耗

#### B2. `scenes/ui/card_info_panel.tscn` — 新增节点

在 `VBox` 中插入：
```
HeaderPanel (已有)
  NameLabel (已有)
  + RarityCostRow (新增 HBoxContainer)
  +   RarityLabel (新增 Label, 左对齐, 带稀有度颜色)
  +   CostLabel (新增 Label, 右对齐, 橙色 ⚡{cost})
TypeLabel (已有, 扩展内容)
RankBadgeHost (已有)
StatsBox / SummaryLabel (已有)
DescLabel (已有, 扩展内容)
FlavorLabel (已有)
ActionButtons (已有)
CloseButton (已有)
```

#### B3. `scenes/ui/backpack_panel.gd` — 简化详情弹窗

**改动 `show_card_detail(card, source_item)`**：
1. 调用 `_detail_info_panel.set_panel_mode(CardInfoPanel.MODE_BACKPACK)`
2. 移除手动创建拆解/装备/关闭按钮的代码（这些改由 CardInfoPanel 内部根据模式自动管理）
3. 关闭按钮保留在 `CardDetailPopup` 层（因为关闭按钮关闭的是 popup 而非面板）

**改动 `_init_detail_info_panel(popup)`**：
- 保持不变（通过 `CardInfoPanelScene.instantiate()` 创建完整面板）

**注意**：`_refresh_popup_affixes()` 仍需保留，因为词条信息由 AffixManager 动态生成。

#### B4. `scenes/ui/phase_instrument_panel.gd` — 改用统一面板

**当前点击流程**：
1. `_on_slot_clicked` → `_show_slot_card_detail(card)`
2. → `BackpackPanelScript.open_card_detail(card, null)` → 打开背包弹窗
3. 如果背包不存在 → `_show_detail_popup_for_card(card)` → 手动创建 Window

**新流程**：
1. `_on_slot_clicked` → `_show_slot_card_detail(card)`
2. → 创建/复用全局 CardInfoPanel，调用 `show_card_info(card, position)`
3. → 设置 `set_panel_mode(MODE_PHASE_INSTRUMENT)` — 不显示拆解按钮
4. 在 ActionButtons 区添加"卸下此卡"按钮（相位仪特有）

**删除**：`_show_detail_popup_for_card()` 整个方法（约100行手写UI代码）

#### B5. `scenes/ui/bottom_instrument_bar.gd` — 改用统一面板

**当前点击流程**：
1. `_show_instrument_slot_card_detail(card_id, source_panel)`
2. → `BackpackPanelScript.open_card_detail(card, source_panel)` → 打开背包弹窗
3. 如果背包不存在 → 查找 `backpack_panel` group → `show_card_detail(card, source_panel)`

**新流程**：
1. `_show_instrument_slot_card_detail(card_id, source_panel)`
2. → 创建/复用全局 CardInfoPanel，调用 `show_card_info(card, position)`
3. → 设置 `set_panel_mode(MODE_BATTLEFIELD)` — 不显示操作按钮

#### B6. `scenes/ui/unit_info_panel.gd` — 微调

**当前流程**：正确

**改动**：
- 在 `show_unit_info()` 之前调用 `info_panel.set_panel_mode(CardInfoPanel.MODE_BATTLEFIELD)`（确保不显示拆解按钮）

---

### 阶段 C：场景文件清理

#### C1. `scenes/ui/backpack_panel.tscn`

**CardDetailPopup 当前结构**：
```
CardDetailPopup (PopupPanel)
  Margin
    VBox
      Header (HBox)       ← 将被 _init_detail_info_panel 移除
        NameLabel
        CostLabel
      LevelLabel         ← 将被 _init_detail_info_panel 移除
      TypeLineLabel      ← 将被 _init_detail_info_panel 移除
      SummaryLabel       ← 将被 _init_detail_info_panel 移除
      HSeparator         ← 将被 _init_detail_info_panel 移除
      DescLabel          ← 将被 _init_detail_info_panel 移除
      FlavorLabel        ← 将被 _init_detail_info_panel 移除
      CloseButton        ← 保留
```

**目标结构**（直接在 .tscn 中定义，不再需要 `_init_detail_info_panel` 运行时清理）：
```
CardDetailPopup (PopupPanel)
  Margin
    VBox
      DetailInfoPanel (通过 .tscn sub-instance 嵌入 CardInfoPanel)
      AffixPlaceholder (可选, 由 _refresh_popup_affixes 管理)
      CloseButton
```

**改动**：
- 在 .tscn 中直接嵌入 `card_info_panel.tscn` 作为子场景实例（名 `DetailInfoPanel`）
- 删除 `Header`, `NameLabel`, `CostLabel`, `LevelLabel`, `TypeLineLabel`, `SummaryLabel`, `HSeparator`, `DescLabel`, `FlavorLabel` 这些将在运行时被 `_init_detail_info_panel` 移除的旧节点
- 保留 `CloseButton`（关闭弹窗用）
- 简化 `_init_detail_info_panel()`：不再需要移除旧节点，只需引用已存在的 DetailInfoPanel

---

## 四、面板模式与操作按钮设计

### 4.1 三种模式

| 模式 | 常量值 | 触发场景 | 操作按钮 |
|------|--------|---------|---------|
| `MODE_BACKPACK` | 0 | 背包卡片点击 | 拆解、装备（法则/能量卡） |
| `MODE_PHASE_INSTRUMENT` | 1 | 相位仪槽位点击 | 卸下此卡 |
| `MODE_BATTLEFIELD` | 2 | 战场单位点击 | 无 |

### 4.2 操作按钮生命周期

```
show_card_info() / show_unit_info() 被调用
  → _current_mode 已通过 set_panel_mode() 设置
  → _clear_action_buttons()  清空旧按钮
  → 刷新内容（_refresh_card_display 或 _refresh_unit_display）
  → 根据 _current_mode 自动添加按钮：
      MODE_BACKPACK → 添加拆解按钮 + 装备按钮（法则/能量卡）+ 关闭按钮
      MODE_PHASE_INSTRUMENT → 添加卸下按钮
      MODE_BATTLEFIELD → 不添加按钮
```

### 4.3 按钮回调

| 按钮 | 回调 | 当前实现位置 |
|------|------|------------|
| 拆解 | `_presenter.on_dismantle_button_pressed(card)` | `backpack_presenter.gd` |
| 装备到相位仪 | `_presenter.on_equip_button_pressed(card)` | `backpack_presenter.gd` |
| 卸下此卡 | `PhaseInstrumentManager.unequip_card(slot_index)` | `phase_instrument_panel.gd` |
| 关闭 | `popup.hide()` / `hide_panel()` | 调用方 |

**问题**：CardInfoPanel 作为全局单例，拆解/装备回调需要访问 `_presenter` 和 `_card` 引用。
**方案**：CardInfoPanel 通过**信号** `action_requested(action: String, card: CardResource)` 发出请求，由调用方连接信号处理具体逻辑。

```gdscript
# card_info_panel.gd
signal action_requested(action: String, card: CardResource)

# 调用方（backpack_panel.gd）
_detail_info_panel.action_requested.connect(_on_detail_action_requested)

func _on_detail_action_requested(action: String, card: CardResource) -> void:
    match action:
        "dismantle": _presenter.on_dismantle_button_pressed(card)
        "equip": _presenter.on_equip_button_pressed(card)
        "unequip": PhaseInstrumentManager.unequip_card(...)
        "close": CardDetailPopup.hide()
```

---

## 五、卡片模式信息显示扩展详细设计

### 5.1 名称行

```
┌─────────────────────────────────┐
│ ★★★  帝国虎式坦克                │  ← NameLabel（16px，青色）
│ [史诗]  ⚡ 15                    │  ← 新增 RarityCostRow
└─────────────────────────────────┘
```

- NameLabel: 保持现有（`card.display_name`）
- RarityLabel: `card.get_formatted_rarity()` 或纯文字 + 颜色
- CostLabel: `"%d⚡" % int(card.energy_cost)`（能量卡显示 `+%d⚡` 获得量）

### 5.2 类型行

```
战斗卡 — 装甲／坦克 · 一战 · 步枪
```

- 格式: `{card_type_name} — {combat_kind_name} · {era_name} · {weapon_label}`
- 能量卡: `能量卡 · 提供 {energy_grant} 能量`
- 法则卡: `法则卡 · {phase_law_name}`

### 5.3 三维攻防摘要

保持现有 `BackpackCombatPreview.build_line(card)` 格式：
```
战斗中：HP 250｜攻 18/12/8｜防 6/10/4｜射程 120｜攻速 1.20｜移速 60
```

### 5.4 描述区

```
装甲军团的主力战车，拥有出色的装甲和火力。
(原有 description)

【词条属性】
减伤 15% · 暴击 8%（1.7x）

【养成】
Lv.5 (突破 2) · 进化阶段 E1 · ★★★

【星级强化（★3）】
- 平台 HP+10%
- 武器 攻击+5%
```

### 5.5 风味文本

保持现有 `flavor_label`。

---

## 六、实施顺序与依赖关系

```
阶段 A（移除悬浮）
  A1 backpack_card_item.gd          ← 无依赖
  A2 backpack_card_item_actions.gd  ← 无依赖
  A3 phase_slot.gd                  ← 无依赖

阶段 B（统一点击）
  B1 card_info_panel.tscn           ← 无依赖
  B2 card_info_panel.gd             ← 依赖 B1
  B3 backpack_panel.gd              ← 依赖 B2（新模式常量）
  B4 phase_instrument_panel.gd      ← 依赖 B2（新模式常量 + 信号）
  B5 bottom_instrument_bar.gd       ← 依赖 B2（新模式常量 + 信号）
  B6 unit_info_panel.gd             ← 依赖 B2（新模式常量）

阶段 C（场景清理）
  C1 backpack_panel.tscn            ← 依赖 B2, B3
```

### 建议执行顺序

1. **B1 + B2** — 先扩展 card_info_panel（.tscn + .gd），这是核心
2. **A1 + A2 + A3** — 然后移除悬浮（可独立，不影响点击）
3. **B3 + C1** — 背包弹窗改用新面板模式
4. **B4** — 相位仪点击改用新面板
5. **B5** — 底部栏点击改用新面板
6. **B6** — 战场面板微调

---

## 七、风险与注意事项

### 7.1 全局单例冲突

三个调用方（背包、相位仪、战场）共享同一个全局 `CardInfoPanel`（挂在 `SceneTree.root`）。
**风险**：背包弹窗内的 `_detail_info_panel` 是独立实例（嵌入在 CardDetailPopup 中），与全局单例不是同一个。
**确认**：这是正确的——背包弹窗有自己的面板实例；相位仪和战场共用全局悬浮式面板。

### 7.2 相位仪"卸下"按钮需要 slot_index

CardInfoPanel 不知道当前显示的卡在相位仪的哪个槽位。
**方案**：`set_panel_mode()` 增加可选参数 `context_data: Dictionary`，传递 `{"slot_index": 3}`，卸下按钮回调时读取。

### 7.3 背包弹窗 vs 全局面板

- **背包弹窗**：`CardDetailPopup`(PopupPanel) 内嵌 `_detail_info_panel`（CardInfoPanel 实例） → 有关闭按钮 → 关闭弹窗
- **相位仪/战场**：全局 `CardInfoPanel` 挂在 root → 无弹窗 → 点击空白处关闭

两种模式的面板实例独立，不冲突。

### 7.4 底部栏 tooltip

`bottom_instrument_bar.gd` 使用的是 Godot 原生 `tooltip_text`（非 CardInfoPanel），**不受本次变更影响**。

### 7.5 向后兼容

- `BackpackPanelScript.open_card_detail()` 静态方法仍保留（相位仪/底部栏可能仍调用），但内部改为使用新面板
- `_show_detail_popup_for_card()` 删除后，`phase_instrument_panel.gd` 的 fallback 不再需要（背包弹窗和新面板都可用）

---

## 八、验证清单

- [ ] 背包卡片悬浮 → 无任何面板弹出
- [ ] 相位仪槽位悬浮 → 无任何面板弹出
- [ ] 战场单位悬浮 → 无任何面板弹出
- [ ] 背包卡片点击 → 弹出统一情报面板（含稀有度/能量/时代/武器/词条/养成），有拆解按钮
- [ ] 相位仪槽位点击 → 弹出统一情报面板，有卸下按钮，无拆解按钮
- [ ] 战场单位点击 → 弹出统一情报面板，无操作按钮
- [ ] 底部栏卡牌点击 → 弹出统一情报面板，无操作按钮
- [ ] 拆解按钮功能正常（拆解后关闭弹窗、刷新背包）
- [ ] 装备到相位仪按钮功能正常（法则卡/能量卡）
- [ ] 卸下按钮功能正常（相位仪槽位清空）
- [ ] 面板在屏幕边缘不溢出
- [ ] 法则卡/能量卡显示正确（非战斗卡的类型行）
- [ ] 无运行时报错（Node not found 等）
