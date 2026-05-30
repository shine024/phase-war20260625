# 📋 《相位战争》v5.1 清理与修复 — 详细执行计划

> **生成日期**：2026-05-30
> **基于**：全量代码审计（精确到行号）
> **前提**：v5.0 POST_AUDIT_EXECUTION_PLAN 全部完成
> **目标**：修复 BUG、消除技术债务、清理废弃代码

---

## 一、问题总览

| # | ID | 优先级 | 类别 | 问题 | 文件数 | 预估 |
|---|-----|--------|------|------|--------|------|
| 1 | BUG-1 | 🔴P0 | 逻辑BUG | enhance_level Lv10加成是死代码 | 2 | 15min |
| 2 | BUG-2 | 🔴P0 | 路径BUG | 硬编码绝对路径 `F:/godot fair duel/...` | 3 | 15min |
| 3 | DEP-1 | 🟠P1 | 废弃残留 | `_agent_log` 12处重复实现 | 12 | 1h |
| 4 | DEP-2 | 🟠P1 | 废弃残留 | `DEFAULT_MOD_OPTIONS` 旧改造定义保留 | 2 | 15min |
| 5 | DEP-3 | 🟠P1 | 废弃残留 | `LawShardManager` 已废弃仍注册存档 | 1 | 15min |
| 6 | DEP-4 | 🟠P1 | 废弃残留 | `star_level` 仍在制造/掉落流程活跃写入 | 3 | 30min |
| 7 | DAT-1 | 🟠P1 | 数据不一致 | `cold_rpg` 放在二战区块 | 1 | 10min |
| 8 | DAT-2 | 🟠P1 | 数据不一致 | `omega_platform` 与 `fut_colossus` 数据完全相同 | 1 | 30min |
| 9 | LOG-1 | 🟡P2 | 代码质量 | scenes/ 116处 `print()` 残留 | 21 | 2h |
| 10 | LOG-2 | 🟡P2 | 代码质量 | scripts/ 42处 `print()` 残留 | 8 | 1h |
| 11 | SAV-1 | 🟡P2 | 存档隐患 | 存档键名全部硬编码字符串 | 1 | 1h |
| 12 | SIZ-1 | 🟡P2 | 大文件 | 18个文件超过800行 | 18 | 40h |
| **合计** | | | | **~45** | **~47h** |

---

## 二、🔴 Phase P0：立即修复（BUG，~30min）

---

### BUG-1：enhance_level Lv10 加成永远不生效（死代码）

**根因**：`if enhance_level >= 9` 在 `elif enhance_level >= 10` 之前。当 `enhance_level == 10` 时已满足 `>= 9`，`elif` 分支永远不执行。

**影响**：Lv10 强化倍率应为 1.60，实际永远只给 1.50。

**修复点1/3** — `scripts/battle/attack_calculator.gd`

```gdscript
# === 当前代码（L59-63）===
	# 5. 强化加成(百分比)
	if attacker_enhance_level > 0:
		var enhance_mult = 1.0 + float(attacker_enhance_level) * 0.05
		if attacker_enhance_level >= 9:
			enhance_mult = 1.50  # Lv9 nonlinear
		elif attacker_enhance_level >= 10:
			enhance_mult = 1.60  # Lv10 nonlinear
		final_damage *= enhance_mult

# === 修复后 ===
	# 5. 强化加成(百分比)
	# Lv1-8: 1.0 + level × 0.05; Lv9: 1.50; Lv10: 1.60
	if attacker_enhance_level > 0:
		var enhance_mult: float
		if attacker_enhance_level >= 10:
			enhance_mult = 1.60  # Lv10
		elif attacker_enhance_level >= 9:
			enhance_mult = 1.50  # Lv9
		else:
			enhance_mult = 1.0 + float(attacker_enhance_level) * 0.05
		final_damage *= enhance_mult
```

**修复点2/3** — `scripts/battle/attack_calculator.gd` L127-131（`calculate_damage_with_range` 函数内，相同代码重复）

```gdscript
# === 当前代码（L127-131）===
	if attacker_enhance_level > 0:
		var enhance_mult = 1.0 + float(attacker_enhance_level) * 0.05
		if attacker_enhance_level >= 9:
			enhance_mult = 1.50
		elif attacker_enhance_level >= 10:
			enhance_mult = 1.60
		final_damage *= enhance_mult

# === 修复后（与上方相同）===
	if attacker_enhance_level > 0:
		var enhance_mult: float
		if attacker_enhance_level >= 10:
			enhance_mult = 1.60
		elif attacker_enhance_level >= 9:
			enhance_mult = 1.50
		else:
			enhance_mult = 1.0 + float(attacker_enhance_level) * 0.05
		final_damage *= enhance_mult
```

**修复点3/3** — `scenes/units/bullet.gd`

```gdscript
# === 当前代码（L366-372）===
	if shooter_stats != null and shooter_stats.enhance_level > 0:
		var enhance_mult := 1.0 + float(shooter_stats.enhance_level) * 0.05
		if shooter_stats.enhance_level >= 9:
			enhance_mult = 1.50
		elif shooter_stats.enhance_level >= 10:
			enhance_mult = 1.60
		damage *= enhance_mult

# === 修复后 ===
	if shooter_stats != null and shooter_stats.enhance_level > 0:
		var enhance_mult: float
		if shooter_stats.enhance_level >= 10:
			enhance_mult = 1.60
		elif shooter_stats.enhance_level >= 9:
			enhance_mult = 1.50
		else:
			enhance_mult = 1.0 + float(shooter_stats.enhance_level) * 0.05
		damage *= enhance_mult
```

**修复后应同步检查**：`managers/card_enhancement_manager.gd` L28 的 `get_power_multiplier()` — 此函数已正确实现（`if level >= 9: return 1.50 if level == 9 else 1.60`），无 bug。

---

### BUG-2：硬编码绝对路径

**根因**：3个文件的 `_agent_log()` 函数硬编码 `"F:/godot fair duel/phase-war/debug-585b52.log"`。

**修复点1/3** — `managers/save_manager.gd` L105-120

```gdscript
# === 当前代码（L105-120）===
#region agent log
func _agent_log(hypothesis_id: String, message: String, data: Dictionary) -> void:
	var f := FileAccess.open("F:/godot fair duel/phase-war/debug-585b52.log", FileAccess.WRITE_READ)
	if f == null:
		return
	f.seek_end()
	var payload := {
		"sessionId": "585b52",
		"runId": "manufacture_law_v1",
		"hypothesisId": hypothesis_id,
		"location": "save_manager.gd",
		"message": message,
		"data": data,
		"timestamp": Time.get_ticks_msec()
	}
	f.store_line(JSON.stringify(payload))
	f.close()
#endregion

# === 修复后 ===
## @deprecated agent log 已迁移到 DebugLogger；此函数保留空壳防止调用方报错
func _agent_log(_hypothesis_id: String, _message: String, _data: Dictionary) -> void:
	pass
```

**修复点2/3** — `scenes/ui/manufacture_panel.gd` L24-43

```gdscript
# === 当前代码（L24-43）===
#region agent log
func _agent_log(hypothesis_id: String, message: String, data: Dictionary) -> void:
	var f := FileAccess.open("F:/godot fair duel/phase-war/debug-585b52.log", FileAccess.WRITE_READ)
	if f == null:
		return
	f.seek_end()
	var payload := {
		"sessionId": "585b52",
		"runId": "manufacture_law_v1",
		"hypothesisId": hypothesis_id,
		"location": "manufacture_panel.gd",
		"message": message,
		"data": data,
		"timestamp": Time.get_ticks_msec()
	}
	f.store_line(JSON.stringify(payload))
	f.close()
#endregion

# === 修复后 ===
func _agent_log(_hypothesis_id: String, _message: String, _data: Dictionary) -> void:
	pass
```

**修复点3/3** — `managers/phase_instrument_manager.gd` L57-75

```gdscript
# === 当前代码（L57-75）===
#region agent log
func _agent_log(hypothesis_id: String, message: String, data: Dictionary) -> void:
	var f := FileAccess.open("F:/godot fair duel/phase-war/debug-585b52.log", FileAccess.WRITE_READ)
	if f == null:
		return
	f.seek_end()
	var payload := {
		"sessionId": "585b52",
		"runId": "equip_slow_v1",
		"hypothesisId": hypothesis_id,
		"location": "phase_instrument_manager.gd",
		"message": message,
		"data": data,
		"timestamp": Time.get_ticks_msec()
	}
	f.store_line(JSON.stringify(payload))
	f.close()
#endregion

# === 修复后 ===
func _agent_log(_hypothesis_id: String, _message: String, _data: Dictionary) -> void:
	pass
```

---

## 三、🟠 Phase P1：尽快修复（废弃残留 + 数据不一致，~2.5h）

---

### DEP-1：`_agent_log` 12处重复实现 — 全部清理为空壳

除 BUG-2 中的3个绝对路径文件外，还有9个文件使用相对路径的 `_agent_log`。全部替换为空壳：

| # | 文件 | 行号 | session | 当前路径 |
|---|------|------|---------|---------|
| 1 | `scenes/units/bullet.gd` | L44-62 | `1776fa` | `debug-1776fa.log`（相对） |
| 2 | `scenes/units/construct_unit.gd` | L129-147 | `1776fa` | `debug-1776fa.log`（相对） |
| 3 | `scenes/ui/resource_bar.gd` | L16-33 | `8fcb79` | `debug-8fcb79.log`（相对） |
| 4 | `scenes/ui/battle_click_overlay.gd` | L19-37 | `1776fa` | `debug-1776fa.log`（相对） |
| 5 | `scenes/main.gd` | L45-62 | `1776fa` | `debug-1776fa.log`（相对） |
| 6 | `managers/active_law_effects.gd` | L16-34 | `1776fa` | `debug-1776fa.log`（相对，static func） |
| 7 | `managers/energy_manager.gd` | L14-31 | `8fcb79` | `debug-8fcb79.log`（相对） |
| 8 | `managers/phase_law_manager.gd` | L49-62 | `95dad8` | 委托 DebugLog 节点 |
| 9 | `scenes/main.gd` | L65-82 | `67fe53` | `debug-67fe53.log`（相对，函数名 `_agent_log_67fe53`） |

**统一替换方案**：每个文件中的 `_agent_log` / `_agent_log_67fe53` 函数体替换为 `pass`，保留函数签名避免调用方报错。

---

### DEP-2：`DEFAULT_MOD_OPTIONS` 旧改造定义

**问题**：`managers/blueprint_manager.gd` L93-105 保留了 9 种旧版 MOD 定义（`MOD_ATK_DMG` 等旧 ID），注释说 `@deprecated Phase 3.3`。

**检查引用**：搜索 `DEFAULT_MOD_OPTIONS` 仅有定义处1处引用，无读取。

**改动**：
- 文件：`managers/blueprint_manager.gd`
- 行号：L91-105
- 操作：删除 `DEFAULT_MOD_OPTIONS` 整个常量块（15行）
- 保留上方注释中的 TODO 记录移至 tech-debt-register.md

---

### DEP-3：`LawShardManager` 已废弃仍注册存档

**问题**：`law_shard_manager.gd` 仍存在于项目且在 3 个位置被引用：

| 文件 | 行号 | 引用 |
|------|------|------|
| `managers/save_manager.gd` | L55 | `["/root/LawShardManager", "law_shards"]` |
| `managers/save_manager.gd` | L87 | `"LawShardManager"` |
| `managers/save_manager.gd` | L451 | `_collect_manager_state(fresh, "/root/LawShardManager", "law_shards")` |

**操作**：注释掉这3处引用，保留注释说明原因：

```gdscript
# L55: 将
["/root/LawShardManager", "law_shards"],  ## legacy migration — LawShard 已废弃
# 改为
## ["/root/LawShardManager", "law_shards"],  # legacy — LawShard 已废弃 (v5.1 移除)

# L87: 将
"LawShardManager",  ## legacy migration — LawShard 已废弃
# 改为
## "LawShardManager",  # legacy — LawShard 已废弃 (v5.1 移除)

# L451: 将
_collect_manager_state(fresh, "/root/LawShardManager", "law_shards")  ## legacy migration — LawShard 已废弃
# 改为
## _collect_manager_state(fresh, "/root/LawShardManager", "law_shards")  # legacy — LawShard 已废弃 (v5.1 移除)
```

**注意**：暂不删除 `law_shard_manager.gd` 文件（避免破坏项目配置的 autoload 注册），仅断开存档引用。

---

### DEP-4：`star_level` 废弃字段仍在活跃写入

**审计发现**：`star_level` 在以下3个文件的**核心业务流程**中被写入：

| 文件 | 行号 | 上下文 |
|------|------|--------|
| `managers/blueprint_manager.gd` | L585 | 蓝图制造：`out_card.star_level = star` |
| `scenes/ui/manufacture_panel.gd` | L277 | 制造面板：`manufactured_card.star_level = BlueprintManager.get_blueprint_star(card_id)` |
| `scenes/ui/manufacture_panel.gd` | L291 | 制造面板：`card.star_level = BlueprintManager.get_blueprint_star(card.card_id)` |
| `managers/drop_manager.gd` | L136 | 掉落出卡：`dropped_card.star_level = star` |
| `managers/drop_manager.gd` | L302 | 掉落兜底：`card.star_level = 1` |

**决策**：**不做删除**，但明确文档化。

**操作**：在 `card_resource.gd` 的 `@deprecated` 注释中补充说明：

```gdscript
# === 当前代码（L140）===
# @deprecated v5.0: 星级系统已删除，改用 enhance_level
@export var star_level: int = 1

# === 修改后 ===
## 蓝图星级 1-9★（Blueprint Star Level）
## v5.0 虽标记 @deprecated，但仍被 BlueprintManager/DropManager/ManufacturePanel 活跃写入
## 作为蓝图属性（非强化等级），承载「研究点升星」的产出值
## 不建议删除；新代码如无特殊需求不应读写此字段
@export var star_level: int = 1
```

---

### DAT-1：`cold_rpg` 放在二战区块

**文件**：`data/default_cards.gd`

**当前**：L57（位于二战区块注释之后、`ww2_m81` 之前）

**操作**：
1. 删除 L57 的 `cold_rpg` 行
2. 在冷战区块（`cold_ak47` 之前）插入

```gdscript
# 在 "# ==================== 冷战单位（20个）====================" 注释后
# "cold_ak47" 之前插入：
list.append(_unit("cold_rpg", "RPG火箭筒组", 2, 0, 170, 3, 2, 14, 180, 18, 0.9, 0.2, 0.1, 120, 0.4, 0.45, 0.2, 0, 0, 0, 0, 15, 5, 5))
```

---

### DAT-2：`omega_platform` 与 `fut_colossus` 数据完全相同

**文件**：`data/default_cards.gd` L137-138

**现状**：
```gdscript
list.append(_unit("omega_platform", "全装型机动舱", 4, 1, 1590, 1, 5, 30, 2000, 100, 0.33, 0.4, 0.2, 550, 0.25, 0.6, 0.3, 80, 0.33, 0.4, 0.2, 150, 250, 80))
```

与 `fut_colossus`（L131）完全相同：`power=1590, hp=2000, 全部攻防数值相同`。

**建议操作**（需用户确认）：

- **方案A（推荐）**：保留但标注，在 L137 注释中说明：
```gdscript
# omega_platform（全装型机动舱）— 与 fut_colossus 数据相同
# 保留用于存档兼容：早期版本以此ID创建的蓝图不会失效
```
- **方案B**：删除 `omega_platform` 行，在存档迁移中增加 `omega_platform → fut_colossus` 的 ID 映射

---

## 四、🟡 Phase P2-1：print() 清理（~3h）

### 4.1 scenes/ 目录（116处）

#### 🔴 高优先清理（单文件 >10处）

**`scenes/ui/global_save_button.gd`** — 17处 print

| 行号 | 内容 | 操作 |
|------|------|------|
| L10 | `初始化开始` | 删除 |
| L19 | `子节点引用获取完成` | 删除 |
| L22 | `按钮信号已连接` | 删除 |
| L36-40 | 5处可见性/锚点/偏移打印 | 全部删除 |
| L49 | `初始化完成` | 删除 |
| L118 | `快速存档按钮被按下` | 删除 |
| L146 | `存档成功` | 改为 `if OS.is_debug_build(): print(...)` |
| L149 | `存档失败` | 保留（错误日志） |
| L162 | `快速读档触发` | 删除 |
| L187 | `读档成功` | 改为条件日志 |
| L190 | `读档失败` | 保留（错误日志） |
| L258-263 | 6处位置更新打印 | 全部删除 |

**`scenes/game_launcher.gd`** — 21处 print

| 行号 | 内容 | 操作 |
|------|------|------|
| L56 | `开始游戏启动序列` | 保留（启动关键日志） |
| L97 | `加载游戏资源` | 保留 |
| L126 | `加载游戏数据` | 保留 |
| L154 | `验证数据完整性` | 保留 |
| L170 | `初始化游戏系统` | 保留 |
| L194 | `加载存档数据` | 保留 |
| L204 | `游戏启动完成!` | 保留 |
| L267, L278, L291, L313 | 重试/新游戏/加载/进入场景 | 保留（启动流程） |
| L320, L332 | 退出/清理 | 保留 |
| L363, L379, L383, L396, L403, L416, L436 | 设置面板相关 | **删除** |

**`scenes/ui/custom_drag_card_item.gd`** — 11处

| 行号 | 操作 |
|------|------|
| L74, L100, L107, L132, L140, L149, L156, L160, L162, L168, L174 | **全部删除**（拖拽调试日志） |

**`scenes/world_map.gd`** — 13处

| 行号 | 操作 |
|------|------|
| L96, L113, L118, L119, L121, L123, L127 | **删除**（_ready 调试） |
| L178, L196 | **保留**（缓存日志有诊断价值） |
| L284 | **保留**（构建完成） |
| L378, L380, L382 | **删除**（场景切换调试） |

**`scenes/ui/backpack_card_item.gd`** — 10处

| 行号 | 操作 |
|------|------|
| L1104, L1116, L1119, L1123, L1129, L1132, L1142, L1151 | **全部删除**（鼠标事件调试） |

**`scenes/main.gd`** — 10处

| 行号 | 操作 |
|------|------|
| L114, L118, L121 | **删除**（_ready 初始化日志） |
| L478 | **保留**（法则同步日志） |
| L931 | **保留**（管理器加载日志） |
| L934 | **保留**（管理器未找到警告） |
| L941, L950, L956 | **删除**（新集成调试） |

#### 🟡 中优先清理（单文件 ≤7处）

| 文件 | 行号 | 操作 |
|------|------|------|
| `scenes/ui/save_slot_manager.gd` | L190,208,226,260,302,319,337 | **保留**（存档操作日志有诊断价值） |
| `scenes/title_screen.gd` | L142,155 | **保留**（启动流程） |
| `scenes/ui/notification_overlay.gd` | L209,214,219 | **删除**（面板导航调试） |
| `scenes/ui/leaderboard_panel.gd` | L504,516 | **删除**（模拟战斗日志） |
| `scenes/ui/leaderboard/leaderboard_panel.gd` | L436,444 | **删除**（同上） |
| `scenes/ui/achievement_panel.gd` | L269,290,295 | **保留**（成就领取日志） |
| `scenes/ui/faction_store_panel.gd` | L57,71,224,232 | **删除**（商店调试） |
| `scenes/ui/bottom_instrument_bar.gd` | L44,55 | **删除**（_ready 日志） |
| `scenes/ui/phase_instrument_panel.gd` | L201 | **保留**（装备结果日志） |
| `scenes/ui/level_select_panel.gd` | L196 | **保留**（关卡选择日志） |
| `scenes/ui/battle_click_overlay.gd` | L209 | **删除**（部署调试） |
| `scenes/ui/manufacture_panel.gd` | L274,284 | **保留**（制造结果日志） |
| `scenes/effects/battle_effects_system.gd` | L94 | **保留**（初始化日志） |
| `scenes/units/enemy_phase_field_driver.gd` | L109 | **保留**（相位师生成日志） |
| `scenes/units/construct_unit.gd` | L245,903 | **删除**（预览调试） |

### 4.2 scripts/ 目录（42处）

| 文件 | 行号 | 操作 |
|------|------|------|
| `scripts/save_utils.gd` | L7,13,19,25,31,40,47 | **保留**（文件I/O错误日志有诊断价值） |
| `scripts/error_handler.gd` | L89,97,116 | **保留**（错误处理系统） |
| `scripts/master_power_evaluator.gd` | L541-589 (19处) | **保留**（排行榜打印是主要输出方式） |
| `scripts/ui_beautifier.gd` | L80,178,197 | **删除**（初始化日志） |
| `scripts/intel_manual.gd` | L118 | **保留**（加载完成日志） |
| `scripts/export_combat_stats.gd` | L12,13,35,38 | **保留**（导出工具脚本） |
| `scripts/performance_utils.gd` | L237 | **改为** `if OS.is_debug_build(): print(...)` |
| `scripts/battle_performance_monitor.gd` | L29,33 | **改为** `if OS.is_debug_build(): print(...)` |

---

## 五、🟡 Phase P2-2：存档键名常量化（~1h）

### 文件：`managers/save_manager.gd`

#### 步骤1：在 L22 之前添加常量块

```gdscript
## ─── 存档数据键名常量 ───
const SK_SCHEMA_VERSION: String = "__schema_version"
const SK_BLUEPRINT: String = "blueprint"
const SK_BASIC_RESOURCES: String = "basic_resources"
const SK_PHASE_LAW: String = "phase_law"
const SK_QUEST: String = "quest"
const SK_FACTION_SYSTEM: String = "faction_system"
const SK_AFFIX_DATA: String = "affix_data"
const SK_LEVEL_PROGRESS: String = "level_progress"
const SK_DROP_MANAGER: String = "drop_manager"
const SK_GAME: String = "game"
const SK_CURRENT_LEVEL: String = "current_level"
const SK_PHASE_SLOTS: String = "phase_slots"
const SK_PHASE_SLOTS_ORDER: String = "phase_slots_order"
const SK_PHASE_INSTRUMENT: String = "phase_instrument"
const SK_BACKPACK_EXTRA_IDS: String = "backpack_extra_ids"
const SK_LORE: String = "lore"
const SK_STAT_BOOST: String = "stat_boost"
const SK_ACHIEVEMENT: String = "achievement"
const SK_DAILY_TASK: String = "daily_task"
const SK_STATISTICS: String = "statistics"
const SK_CARD_ENHANCEMENT: String = "card_enhancement"
const SK_LAW_SHARDS: String = "law_shards"
const SK_TUTORIAL_PROGRESS: String = "tutorial_progress"
const SK_STORY_PROGRESS: String = "story_progress"
const SK_CHARACTERS: String = "characters"
const SK_CHALLENGE_RECORDS: String = "challenge_records"
const SK_CARD_COLLECTION: String = "card_collection"
const SK_LEADERBOARD: String = "leaderboard"
const SK_LEGACY_COMPANY_REP: String = "_legacy_company_rep"
```

#### 步骤2：替换 save_game() 中的硬编码键名

| 行号 | 当前 | 替换为 |
|------|------|--------|
| L492 | `data["__schema_version"]` | `data[SK_SCHEMA_VERSION]` |
| L496 | `data["blueprint"]` | `data[SK_BLUEPRINT]` |
| L498 | `data["basic_resources"]` | → 常量 |
| L499 | `data["phase_law"]` | → 常量 |
| L500 | `data["quest"]` | → 常量 |
| L501 | `data["faction_system"]` | → 常量 |
| L502 | `data["affix_data"]` | → 常量 |
| L503 | `data["level_progress"]` | → 常量 |
| L504 | `data["drop_manager"]` | → 常量 |
| L507 | `data["game"] = {"current_level": ...}` | `data[SK_GAME] = {SK_CURRENT_LEVEL: ...}` |
| L510 | `data["phase_slots"]` / `data["phase_slots_order"]` | → 常量 |
| L512 | `data["phase_instrument"]` | → 常量 |
| L515 | `data["backpack_extra_ids"]` | → 常量 |

#### 步骤3：替换 _collect_noncritical_save_data() 中的键名

L443-454 中所有字符串键名替换为对应常量。

#### 步骤4：替换 _migrate_save_data() 中的键名

L643-662 中 `data["company"]`、`data["faction_system"]`、`data["__schema_version"]` 等替换为常量。

#### 步骤5：替换 load_game() 中的键名

所有 `data.get("xxx")` 的键名替换为常量。

---

## 六、🟡 Phase P2-3：大文件拆分计划（~40h）

### 6.1 数据文件（纯定义，低风险）— ~8h

#### `data/phase_master_roster.gd`（4085行）→ 5个文件

```
data/phase_master_roster.gd          → 保留为聚合文件（~50行）
data/phase_master_roster_ww1.gd     → 一战相位师（~800行）
data/phase_master_roster_ww2.gd     → 二战相位师（~800行）
data/phase_master_roster_cold.gd    → 冷战相位师（~800行）
data/phase_master_roster_modern.gd  → 现代相位师（~800行）
data/phase_master_roster_future.gd  → 近未来相位师（~800行）
```

主文件改为：
```gdscript
const RosterWW1 = preload("res://data/phase_master_roster_ww1.gd")
const RosterWW2 = preload("res://data/phase_master_roster_ww2.gd")
# ... 聚合查询函数不变，内部委托给子文件
```

#### `data/enemy_phase_masters.gd`（2195行）→ 5个文件

同上模式，按时代拆分。

#### `data/enemy_phase_equipment.gd`（1501行）→ 3个文件

```
data/enemy_phase_equipment.gd           → 聚合文件
data/enemy_equipment_weapons.gd        → 武器装备（~500行）
data/enemy_equipment_armor_modules.gd   → 装甲模块（~500行）
data/enemy_equipment_specials.gd        → 特殊装备（~500行）
```

#### `data/enemy_archetypes.gd`（1149行）→ 3个文件

按时代分组：ww1+ww2（~400行）、cold+modern（~400行）、future（~350行）。

#### `data/achievement_definitions_extended.gd`（904行）→ 3个文件

按类别：战斗成就、收集成就、养成/特殊成就。

### 6.2 逻辑文件（需保持API兼容）— ~32h

#### `scenes/units/construct_unit.gd`（1548行）→ 3个文件

```
scenes/units/construct_unit.gd           → 核心单位逻辑（~800行）
scripts/battle/construct_unit_ai.gd     → AI/攻击/选敌逻辑（~400行）
scripts/battle/construct_unit_deploy.gd → 部署幽灵/进度条（~300行）
```

**提取规则**：
- `construct_unit_ai.gd`：提取 `_choose_attack_target()`、`_perform_attack()`、攻击计时器逻辑、被动效果触发
- `construct_unit_deploy.gd`：提取 `start_as_deploy_ghost()`、`_calculate_deploy_delay()`、`_update_deploy_ghost()`、`_materialize_deploy_ghost()`

#### `scenes/ui/backpack_card_item.gd`（1505行）→ 3个文件

```
scenes/ui/backpack_card_item.gd          → 核心UI（~800行）
scenes/ui/backpack_card_item_drag.gd     → 拖拽处理（~400行）
scenes/ui/backpack_card_item_actions.gd   → 操作按钮/菜单（~300行）
```

#### `scenes/ui/leaderboard_panel.gd`（1209行）→ 2个文件

```
scenes/ui/leaderboard_panel.gd               → UI渲染（~700行）
scripts/systems/leaderboard_data_provider.gd → 数据获取/排序/模拟战斗（~500行）
```

#### `managers/save_manager.gd`（1191行）→ 3个文件

```
managers/save_manager.gd          → 核心存档逻辑（~700行）
scripts/systems/save_migration.gd → v1→v2→v3迁移链（~300行）
scripts/systems/save_constants.gd  → 键名常量 + 路径常量（~100行）
```

#### `managers/phase_instrument_manager.gd`（1121行）→ 2个文件

```
managers/phase_instrument_manager.gd        → 核心管理（~700行）
managers/phase_instrument_loadout_sync.gd  → 装备/卸下/同步逻辑（~400行）
```

#### `scenes/main.gd`（966行）→ 3个文件

```
scenes/main.gd                      → 主控制器（~500行）
scripts/systems/main_battle_setup.gd → 战前准备（~250行）
scripts/systems/main_reward.gd       → 战后结算/奖励（~200行）
```

#### `scenes/effects/battle_effects_system.gd`（928行）→ 2个文件

```
scenes/effects/battle_effects_system.gd → 特效管理（~500行）
scenes/effects/battle_audio_system.gd    → 音效管理（~400行）
```

#### `scenes/ui/backpack_panel.gd`（927行）→ 2个文件

```
scenes/ui/backpack_panel.gd               → UI核心（~600行）
scripts/systems/backpack_filter_sort.gd   → 筛选/排序（~300行）
```

#### `scenes/ui/bottom_instrument_bar.gd`（907行）→ 2个文件

```
scenes/ui/bottom_instrument_bar.gd    → UI渲染（~500行）
scenes/ui/instrument_bar_drag.gd      → 槽位拖放（~400行）
```

#### `managers/blueprint_manager.gd`（865行）→ 进一步提取

已有 `managers/evolution/` 子模块，进一步提取：

```
managers/blueprint_manager.gd           → facade + 核心（~600行）
scripts/systems/rarity_helpers.gd       → 稀有度查询（~100行）
scripts/systems/attribute_growth.gd     → 属性成长计算（~150行）
```

#### `scenes/ui/card_enhancement_panel.gd`（802行）→ 2个文件

```
scenes/ui/card_enhancement_panel.gd    → UI核心（~500行）
scenes/ui/enhancement_animation.gd     → 强化动画/粒子效果（~300行）
```

#### `scenes/ui/leaderboard/leaderboard_panel.gd`（847行）

与 `scenes/ui/leaderboard_panel.gd`（1209行）重复——评估是否合并或统一为一个。

---

## 七、执行顺序

```
Week 1: P0 + P1
  Day 1: BUG-1 (Lv10死代码) + BUG-2 (绝对路径)
  Day 1: DEP-1 (12处_agent_log清空) + DEP-2 (DEFAULT_MOD_OPTIONS删除)
  Day 2: DEP-3 (LawShard断开) + DEP-4 (star_level注释) + DAT-1 (cold_rpg归位)
  Day 2: DAT-2 (omega_platform确认) — 需用户决策

Week 2: P2-1 (print清理)
  Day 3: global_save_button.gd (17处) + custom_drag_card_item.gd (11处)
  Day 3: backpack_card_item.gd (10处) + main.gd (10处)
  Day 4: game_launcher.gd (21处) + world_map.gd (13处)
  Day 4: 其余单文件 ≤7处的 print

Week 2-3: P2-2 (存档键名常量化)
  Day 5: save_manager.gd 常量化

Week 3-6: P2-3 (大文件拆分)
  Day 6-7: 数据文件拆分（5个文件，~8h）
  Day 8-12: 逻辑文件拆分（8个文件，~32h）
```

---

## 八、里程碑

| 里程碑 | 完成标志 | 预计日期 |
|--------|---------|---------|
| **M1**：BUG清零 | Lv10加成生效、绝对路径消除 | Day 1 |
| **M2**：废弃清理 | 12处_agent_log空壳化、DEFAULT_MOD_OPTIONS删除、LawShard断开 | Day 2 |
| **M3**：数据一致 | cold_rpg归位、omega_platform确认 | Day 2 |
| **M4**：日志整洁 | scenes/ 116处 + scripts/ 42处 print清理 | Day 4 |
| **M5**：存档安全 | save_manager 键名常量化 | Day 5 |
| **M6**：数据瘦身 | 5个数据大文件拆分完成 | Day 7 |
| **M7**：逻辑瘦身 | 8个逻辑/UI大文件拆分完成，API兼容 | Day 12 |

---

> **文档版本**：v1.0
> **生成工具**：DeepV Code Agent
> **状态**：待执行
> **总预估工时**：~47h（不含大文件拆分的测试验证）
