# 统一相位仪池 Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** 将玩家/敌方两套分离的相位仪数据合并为统一 GDScript 池，双方共通，ability 由 owner 决定方向。

**Architecture:** 玩家 schema（`phase_instruments.gd._make_def`）吸收敌方 26 款；删敌方 JSON + legacy；两 abilities 文件合并为 owner-aware 单引擎（双 owner 并存）；`enemy_phase_field_driver` 改读统一池字段。Big bang 一次到位。

**Tech Stack:** Godot 4.5 GDScript（RefCounted 静态数据类）、GdUnit4 测试、SignalBus。

**Spec:** `docs/superpowers/specs/2026-07-16-unified-phase-instrument-pool-design.md`

---

## 执行约定

- **Big bang**：全部 13 任务完成后游戏才完整可跑。中间任务仅做 `--check-only` 语法验证。
- **Commit**：每个 Task 末尾 commit 步骤 **⚠ 需用户确认**（CLAUDE.md: "No commits without user instruction"）。执行者暂停问用户。
- **Godot 路径**：`GODOT="/d/godot/Godot_v4.5.1.exe"`（memory 修正：非 CLAUDE.md 的 `D:/Downloads/Godot`，已失效）。**不加** `--rendering-driver opengl3`（headless 卡死）。
- **GDScript v4.5 陷阱**（memory）：避免 preload 自引用 tscn；静态上下文禁止 `Node is Tween` 等运行时类型判断。
- **数据表引用**：26 款相位仪的 id/star/level 完整表见 spec §4.3。本计划给全变体样例，其余按表填。

## File Structure

| 文件 | 职责 | 操作 |
|---|---|---|
| `data/phase_instruments.gd` | 统一相位仪池（玩家 35 + 敌方 26 = 61 款）+ ability 工厂函数 | Modify |
| `data/enemy_phase_equipment.gd` | 装备查表入口（相位仪部分委托统一池） | Modify |
| `data/enemy_equipment_specials.gd` | legacy fallback | Modify（删 LEGACY_PHASE_INSTRUMENTS） |
| `data/json/enemy_phase_masters.json` | 30 master 数据 | Modify（改 phase_instrument id） |
| `data/enemy_phase_masters_{ww1,ww2,cold,modern,future}.gd` | GDScript fallback | Modify（同步改 id） |
| `scenes/units/enemy_phase_field_driver.gd` | 敌方基地战斗驱动 | Modify（3 处读法） |
| `managers/battle/phase_instrument_abilities.gd` | owner-aware 单引擎 | Modify（合并敌方逻辑） |
| `managers/battle/battle_manager.gd` | 战斗编排 | Modify（6 调用点→3） |
| `scripts/battle/attack_calculator.gd` | 攻击计算 | Modify（get_active_ability 加 owner） |
| `scenes/units/bullet.gd` | 子弹 | Modify（同上） |
| `scenes/ui/leaderboard/leaderboard_presenter.gd` | 排行榜 UI | Modify（删翻译表） |
| `scenes/ui/card_info_panel.gd` | 卡信息 UI | Modify（special_effects→special_traits） |
| `scripts/master_power_evaluator.gd` | 战力评分 | Modify（读法改） |
| `managers/battle/enemy_phase_instrument_abilities.gd` | 旧敌方引擎 | **Delete** |
| `data/json/enemy_phase_instruments.json` | 旧敌方相位仪 JSON | **Delete** |
| `tests/unit/data/test_phase_instruments_unified.gd` | 统一池数据测试 | Create |
| `tests/enemy_instrument_abilities_smoke.gd` | 单引擎 smoke | Modify |

---

## Task 1: phase_instruments.gd — 加 ability_rage_buff + 补 ability 函数 star 分支

**Files:**
- Modify: `data/phase_instruments.gd`（ability 工厂函数区，约 line 128-257）

敌方款带 ability 的有 6 款（steel_mk3/mk4/god、flame_mk4、void_mk4/god），star 分别 6/7/7/7/7/7。需确保 ability 函数覆盖这些 star。

- [ ] **Step 1: 加 ability_rage_buff(star) 工厂函数**

在 `ability_fortress_bulwark` 函数后（约 line 258 前）插入：

```gdscript
## 9. 狂暴（owner-aware：PLAYER 持有→buff 我方，ENEMY 持有→buff 敌方）
## 周期性激活：临时提升攻速/攻击。敌方原 enemy_rage_buff 统一为此 id。
static func ability_rage_buff(star: int) -> Dictionary:
	var interval: float = 15.0
	var duration: float = 5.0
	var atk_mult: float = 1.4
	var spd_mult: float = 1.25
	match star:
		3: interval = 20.0; duration = 4.0; atk_mult = 1.2; spd_mult = 1.15
		5: interval = 18.0; duration = 4.5; atk_mult = 1.3; spd_mult = 1.2
		6: interval = 16.0; duration = 5.0; atk_mult = 1.35; spd_mult = 1.22
		7: interval = 12.0; duration = 6.0; atk_mult = 1.5; spd_mult = 1.3
	return {
		"id": "rage_buff",
		"name": "狂暴激涌",
		"type": "periodic",
		"params": {"interval": interval, "duration": duration, "atk_mult": atk_mult, "spd_mult": spd_mult},
		"description": "每%d秒激活狂暴：目标单位 %d 秒内攻击+%d%%、攻速+%d%%" % [int(interval), int(duration), int((atk_mult - 1.0) * 100), int((spd_mult - 1.0) * 100)],
	}
```

- [ ] **Step 2: ability_nano_swarm 补 star 7 分支**

找到 `ability_nano_swarm(star)`（约 line 207），其 `match star:` 当前只有 4/6。补 7：

```gdscript
match star:
	4: duration = 12.0; hp_pct_per_sec = 0.015
	6: duration = 20.0; hp_pct_per_sec = 0.018
	7: duration = 25.0; hp_pct_per_sec = 0.020   # 新增：void_god 用
```

- [ ] **Step 3: 核 ability_artillery_barrage / ability_mega_shield 覆盖**

`ability_artillery_barrage` 当前 match 4/6/7（已覆盖敌方 flame_mk4 star7）。`ability_mega_shield` 当前 match 6/7 + 默认 4（覆盖敌方 steel_mk3 star6）。无需改，仅核对。

- [ ] **Step 4: 语法验证**

```bash
GODOT="/d/godot/Godot_v4.5.1.exe"
"$GODOT" --headless --path "." --check-only
```
Expected: 无解析错误退出码 0。

- [ ] **Step 5: ⚠ Commit（需用户确认）**

```bash
git add data/phase_instruments.gd
git commit -m "feat(phase-instrument): add ability_rage_buff factory + nano_swarm star7 branch"
```

---

## Task 2: phase_instruments.gd — _build_all() 追加 26 款敌方相位仪

**Files:**
- Modify: `data/phase_instruments.gd._build_all()`（return 前，约 line 471 前）

`_make_def` 签名：`(id, name, faction_id, is_generic, star, acquire_rule, special_traits=[], active_ability={})`。敌方款全部 `faction_id="generic"`、`is_generic=true`、`acquire_rule="phase_master_drop"`（敌方相位师装备源）。`_make_def` 自动按 star 派生 slot_counts/properties/energy_recovery_rate/spawn_range_ratio（选 B：丢弃原 atk_bonus 数值）。

- [ ] **Step 1: 追加 4 系 mk1-god（20 款）+ hybrid（5 款）+ omega（1 款）**

在 `_build_all()` 的 `return out` 前，先加注释：

```gdscript
	# v7.x 敌方相位师相位仪迁入（26 款，原 enemy_phase_instruments.json）
	# is_generic=true：不绑公司布局；faction_id="generic"；acquire_rule="phase_master_drop"
	# id/star/level 见 spec §4.3。properties 按 star 派生（选 B）。
```

然后追加**全变体样例**（覆盖 mk1/mk4/god/hybrid/omega/带ability 所有形态）：

```gdscript
	# ── STEEL 系（steel_guardian_mk1..god → pi_steel_01..05）──
	out.append(_make_def("pi_steel_01", "钢铁卫士·初阶", "generic", true, 3, "phase_master_drop",
		["钢肤·初：产兵防御小幅强化"]))
	out.append(_make_def("pi_steel_02", "钢铁卫士·进阶", "generic", true, 5, "phase_master_drop",
		["方阵防御：产兵防御中幅强化"]))
	out.append(_make_def("pi_steel_03", "钢铁卫士·专家", "generic", true, 6, "phase_master_drop",
		["要塞精通：产兵防御大幅强化"], ability_mega_shield(6)))
	out.append(_make_def("pi_steel_04", "钢铁卫士·大师", "generic", true, 7, "phase_master_drop",
		["不朽要塞：产兵防御极强"], ability_rage_buff(7)))
	out.append(_make_def("pi_steel_05", "钢铁之神", "generic", true, 7, "phase_master_drop",
		["神威：产兵全属性极强"], ability_rage_buff(7)))
```

**其余 21 款按 spec §4.3 命名表 + 上方模式填入**（FLAME/THUNDER/VOID 各 5 款同 STEEL 模式；THUNDER 全系无 ability；FLAME_mk4=artillery_barrage(7)、FLAME_god 无 ability；VOID_mk4/god=nano_swarm(7)；5 个 hybrid 无 ability；omega 无 ability）。hybrid 与 omega 样例：

```gdscript
	# ── HYBRID 混合系（无 ability）──
	out.append(_make_def("pi_steelflame_01", "熔铸卫士", "generic", true, 5, "phase_master_drop",
		["熔锻：钢与焰的产兵强化"]))
	out.append(_make_def("pi_thundersteel_01", "电磁卫士·初", "generic", true, 5, "phase_master_drop",
		["导电：雷与钢的产兵强化"]))
	out.append(_make_def("pi_voidflame_01", "熵增炎魔", "generic", true, 5, "phase_master_drop",
		["熵焰：虚与焰的产兵强化"]))
	out.append(_make_def("pi_steelthunder_01", "电磁卫士·高阶", "generic", true, 6, "phase_master_drop",
		["风暴锻造：钢与雷的产兵强化"]))
	out.append(_make_def("pi_flamevoid_01", "混沌炎魔仪", "generic", true, 6, "phase_master_drop",
		["维度燃烧：焰与虚的产兵强化"]))
	# ── OMEGA ──
	out.append(_make_def("pi_omega_01", "奥米茄相位仪", "generic", true, 7, "phase_master_drop",
		["完美和谐：全属性终极强化"]))
```

> 命名表（id → star）完整对照 spec §4.3。FLAME_01..05 = star 3/5/6/7/7；THUNDER_01..05 = 3/5/6/7/7；VOID_01..05 = 3/5/6/7/7。

- [ ] **Step 2: 写数据测试**

Create `tests/unit/data/test_phase_instruments_unified.gd`：

```gdscript
extends GdUnitTestSuite

const PhaseInstruments = preload("res://data/phase_instruments.gd")

func test_enemy_migrated_ids_exist() -> void:
	var ids := ["pi_steel_01", "pi_steel_05", "pi_flame_04", "pi_void_05",
				"pi_thunder_03", "pi_steelflame_01", "pi_omega_01"]
	for id in ids:
		var d: Dictionary = PhaseInstruments.get_by_id(id)
		assert(d != null and not d.is_empty(), "缺失统一池 id: %s" % id)
		assert_bool(d.get("is_generic", false)).is_true()

func test_enemy_instruments_have_slot_counts() -> void:
	var d: Dictionary = PhaseInstruments.get_by_id("pi_steel_03")
	var sc: Dictionary = d.get("slot_counts", {})
	assert_int(int(sc.get("green", 0))).is_greater(0)

func test_enemy_active_ability_ids_bare() -> void:
	# steel_03 = mega_shield, void_05 = nano_swarm（裸 id，无 enemy_ 前缀）
	var s3: Dictionary = PhaseInstruments.get_by_id("pi_steel_03").get("active_ability", {})
	assert_str(str(s3.get("id", ""))).is_equal("mega_shield")
	var v5: Dictionary = PhaseInstruments.get_by_id("pi_void_05").get("active_ability", {})
	assert_str(str(v5.get("id", ""))).is_equal("nano_swarm")

func test_player_instruments_still_present() -> void:
	assert_bool(not PhaseInstruments.get_by_id("pi_generic_01").is_empty()).is_true()
	assert_bool(not PhaseInstruments.get_by_id("pi_special_rage").is_empty()).is_true()
```

- [ ] **Step 3: 跑测试验证通过**

```bash
"$GODOT" --headless --path "." --script "tests/gdunit4_runner.gd"
```
Expected: 新测试全 PASS。

- [ ] **Step 4: ⚠ Commit（需用户确认）**

```bash
git add data/phase_instruments.gd tests/unit/data/test_phase_instruments_unified.gd
git commit -m "feat(phase-instrument): migrate 26 enemy instruments into unified GDScript pool"
```

---

## Task 3: EnemyPhaseEquipment.get_phase_instrument 委托统一池

**Files:**
- Modify: `data/enemy_phase_equipment.gd`（line 14, 17, 201-204）

- [ ] **Step 1: 改 get_phase_instrument 委托 PhaseInstruments**

`data/enemy_phase_equipment.gd:201-204` 当前：

```gdscript
static func get_phase_instrument(instrument_id: String) -> Dictionary:
	if PHASE_INSTRUMENTS.has(instrument_id):
		return PHASE_INSTRUMENTS[instrument_id]
	return {}
```

改为：

```gdscript
static func get_phase_instrument(instrument_id: String) -> Dictionary:
	# v7.x: 委托统一相位仪池（敌方 master 的 phase_instrument 现用 pi_ id）
	return PhaseInstruments.get_by_id(instrument_id)
```

在文件顶部 const 区（line 5-7 附近）加 preload：

```gdscript
const PhaseInstruments = preload("res://data/phase_instruments.gd")
```

- [ ] **Step 2: 语法验证**

```bash
"$GODOT" --headless --path "." --check-only
```
Expected: 退出码 0。

- [ ] **Step 3: ⚠ Commit（需用户确认）**

```bash
git add data/enemy_phase_equipment.gd
git commit -m "refactor(enemy-equipment): delegate get_phase_instrument to unified pool"
```

---

## Task 4: master 数据改 phase_instrument 引用 id（30 处 ×2 双轨）

**Files:**
- Modify: `data/json/enemy_phase_masters.json`（30 处 `equipment.phase_instrument` 值）
- Modify: `data/enemy_phase_masters_ww1.gd` / `_ww2.gd` / `_cold.gd` / `_modern.gd` / `_future.gd`（GDScript fallback `ERA_MASTERS` 同步）

**id 映射表**（spec §4.3 完整）：

| 旧 | 新 | 旧 | 新 |
|---|---|---|---|
| steel_guardian_mk1 | pi_steel_01 | void_walker_mk1 | pi_void_01 |
| steel_guardian_mk2 | pi_steel_02 | void_walker_mk2 | pi_void_02 |
| steel_guardian_mk3 | pi_steel_03 | void_walker_mk3 | pi_void_03 |
| steel_guardian_mk4 | pi_steel_04 | void_walker_mk4 | pi_void_04 |
| steel_guardian_god | pi_steel_05 | void_walker_god | pi_void_05 |
| flame_destroyer_mk1 | pi_flame_01 | hybrid_steel_flame_mk1 | pi_steelflame_01 |
| flame_destroyer_mk2 | pi_flame_02 | hybrid_thunder_steel_mk1 | pi_thundersteel_01 |
| flame_destroyer_mk3 | pi_flame_03 | hybrid_void_flame_mk1 | pi_voidflame_01 |
| flame_destroyer_mk4 | pi_flame_04 | hybrid_steel_thunder_mk1 | pi_steelthunder_01 |
| flame_destroyer_god | pi_flame_05 | hybrid_flame_void_mk1 | pi_flamevoid_01 |
| thunder_storm_mk1 | pi_thunder_01 | omega_instrument | pi_omega_01 |
| thunder_storm_mk2 | pi_thunder_02 | | |
| thunder_storm_mk3 | pi_thunder_03 | | |
| thunder_storm_mk4 | pi_thunder_04 | | |
| thunder_storm_god | pi_thunder_05 | | |

- [ ] **Step 1: JSON 全局替换（每个旧 id → 新 id，30 处）**

用 Edit `replace_all: true` 对 `data/json/enemy_phase_masters.json` 逐个 id 替换（共 26 个唯一旧 id，部分 id 被 0 或多 master 引用）。例：

```
old: "steel_guardian_mk1"  new: "pi_steel_01"   replace_all: true
...（对 26 个旧 id 各做一次）
```

- [ ] **Step 2: 5 个 GDScript fallback 同步替换**

对 `enemy_phase_masters_{ww1,ww2,cold,modern,future}.gd` 每个文件，同样对出现的旧 id `replace_all`。每文件涉及的 id 子集（grep 确认）：
- ww1: steel_mk1/mk2, flame_mk1/mk2, thunder_mk1, void_mk1
- ww2: thunder_mk2/mk3, void_mk2/mk3, steel_mk3, flame_mk3
- cold: hybrid_steel_flame/thunder_steel/void_flame, steel_mk4, flame_mk4, thunder_mk4
- modern: void_mk4, hybrid_steel_thunder/flame_void, steel_mk4, flame_mk4, thunder_mk4
- future: void_mk4, steel_god, flame_god, thunder_god, void_god, omega

- [ ] **Step 3: 验证无残留旧 id**

```bash
grep -rn "steel_guardian\|flame_destroyer\|thunder_storm\|void_walker\|hybrid_.*_mk1\|omega_instrument" data/enemy_phase_masters*.gd data/json/enemy_phase_masters.json
```
Expected: 无输出（0 残留）。

```bash
"$GODOT" --headless --path "." --check-only
```
Expected: 退出码 0。

- [ ] **Step 4: ⚠ Commit（需用户确认）**

```bash
git add data/json/enemy_phase_masters.json data/enemy_phase_masters_*.gd
git commit -m "refactor(enemy-masters): rename phase_instrument refs to unified pi_ ids"
```

---

## Task 5: enemy_phase_field_driver.gd — 改 3 处读法

**Files:**
- Modify: `scenes/units/enemy_phase_field_driver.gd:181-184, 1099-1117` + setup 数据源

- [ ] **Step 1: unit_capacity → slot_counts.green**

`enemy_phase_field_driver.gd:181-184` 当前（据探索报告）：

```gdscript
var _cap: int = int(_instrument_data.get("unit_capacity", _unit_limit))
... mini(_unit_limit, _cap)
```

改为读统一池 slot_counts.green：

```gdscript
var _sc: Dictionary = _instrument_data.get("slot_counts", {})
var _cap: int = int(_sc.get("green", _unit_limit))
... mini(_unit_limit, _cap)
```

> 先 Read 该文件 175-190 区确认精确行与上下文，再 Edit。

- [ ] **Step 2: atk_bonus/hp_bonus/def_bonus → properties.pi_atk/pi_hp/pi_def**

`enemy_phase_field_driver.gd:1099-1117` 的 `_apply_enemy_phase_instrument_bonus` 当前读 `atk_bonus`/`hp_bonus`/`def_bonus` 三值各 ×0.05。改为读 `properties`：

```gdscript
static func _apply_enemy_phase_instrument_bonus(stats) -> void:
	# v7.x: 读统一池 properties（pi_atk/pi_def/pi_hp），值已是百分比小数（如 0.06）
	var props: Array = _instrument_data.get("properties", [])
	var atk_pct: float = 0.0
	var def_pct: float = 0.0
	var hp_pct: float = 0.0
	for p in props:
		match String(p.get("id", "")):
			"pi_atk": atk_pct = float(p.get("value", 0.0))
			"pi_def": def_pct = float(p.get("value", 0.0))
			"pi_hp":  hp_pct  = float(p.get("value", 0.0))
	# 应用到产兵 stats（原 ×0.05 系数废除，properties value 已是最终百分比）
	# [在此调用原 stats 乘区逻辑，用 atk_pct/def_pct/hp_pct 替代原 atk_bonus*0.05]
```

> 先 Read 1095-1120 确认原 stats 写入语句（max_hp/三维攻防/weapon_slots.damage），保留写入目标，仅改数值来源。选 B：properties value 直接用，不再 ×0.05。

- [ ] **Step 3: setup 数据源已是 PhaseInstruments（Task 3 委托后自动生效）**

driver setup 调 `EnemyPhaseEquipment.get_phase_instrument(id)` → Task 3 已委托 `PhaseInstruments.get_by_id`。返回的字典含 `slot_counts`/`properties`/`active_ability`（玩家 schema）。无需改 driver 调用点，仅 Step 1-2 改读字段。核对 driver:222-223 active_ability 缓存（读 `_instrument_data["active_ability"]`），统一池该字段仍是 dict，OK。

- [ ] **Step 4: 语法验证**

```bash
"$GODOT" --headless --path "." --check-only
```
Expected: 退出码 0。

- [ ] **Step 5: ⚠ Commit（需用户确认）**

```bash
git add scenes/units/enemy_phase_field_driver.gd
git commit -m "refactor(enemy-driver): read slot_counts.green + properties from unified pool"
```

---

## Task 6: phase_instrument_abilities.gd — owner-aware 单引擎

**Files:**
- Modify: `managers/battle/phase_instrument_abilities.gd`（全文改造，保留各 ability 实现体）
- 这是最大改动。保留玩家版各 ability 实现体（_apply_nano_swarm_tick / _fire_artillery_shot / _apply_mega_shield / _fire_nuclear_bombardment），改造状态与方向。

- [ ] **Step 1: 加 Owner enum + 双 owner 状态**

文件顶部 static var 区替换 `_active_ability` 单变量为双 owner：

```gdscript
enum Owner { PLAYER, ENEMY }

static var _player_active: Dictionary = {}
static var _enemy_active: Dictionary = {}
static var _periodic_timers: Dictionary = {}   # key: "player:<ab>" / "enemy:<ab>"
static var _nano_remaining: Dictionary = {}    # "player"/"enemy" -> float
static var _barrage_queue: Dictionary = {}     # "player"/"enemy" -> Array
static var _rage_state: Dictionary = {}        # "player"/"enemy" -> {active, expire_at, applied[]}
static var _battle_active: bool = false
static var _battlefield: Node = null
static var _start_fired: Dictionary = {}       # "player"/"enemy" -> bool
```

- [ ] **Step 2: 方向抽象 _get_targets / _get_allies**

替换原 `_get_player_units` / `_get_enemy_units` 的硬编码用法。加：

```gdscript
static func _get_targets(owner: Owner) -> Array:
	# 打击目标：PLAYER 持有打敌方，ENEMY 持有打玩家
	return _get_units("EnemyUnits") if owner == Owner.PLAYER else _get_units("PlayerUnits")

static func _get_allies(owner: Owner) -> Array:
	# buff 对象：反之
	return _get_units("PlayerUnits") if owner == Owner.PLAYER else _get_units("EnemyUnits")

static func _owner_key(owner: Owner) -> String:
	return "player" if owner == Owner.PLAYER else "enemy"

static func _owner_active(owner: Owner) -> Dictionary:
	return _player_active if owner == Owner.PLAYER else _enemy_active
```

保留 `_get_units(group_node_name, driver_name)` 原样。

- [ ] **Step 3: 改入口签名**

```gdscript
static func on_battle_start(source: Node, battlefield: Node, owner: Owner) -> void:
	if owner == Owner.PLAYER:
		_player_active = _read_ability(source)
	else:
		_enemy_active = _read_ability(source)
	_battlefield = battlefield
	_battle_active = true
	_start_fired[_owner_key(owner)] = false
	_fire_start_abilities(owner)

static func _read_ability(source: Node) -> Dictionary:
	if source == null:
		return {}
	if source.has_method("get_active_ability"):
		return source.get_active_ability()
	return {}

static func get_active_ability(owner: Owner) -> Dictionary:
	return _owner_active(owner)

static func update(delta: float) -> void:
	if not _battle_active:
		return
	# 双 owner 各自驱动
	for owner in [Owner.PLAYER, Owner.ENEMY]:
		var ab: Dictionary = _owner_active(owner)
		if ab.is_empty():
			continue
		_update_owner(owner, ab, delta)

static func _update_owner(owner: Owner, ab: Dictionary, delta: float) -> void:
	var key: String = _owner_key(owner)
	var atype: String = String(ab.get("type", ""))
	var aid: String = String(ab.get("id", ""))
	# nano_swarm 持续
	var nano_left: float = float(_nano_remaining.get(key, 0.0))
	if nano_left > 0.0:
		_nano_remaining[key] = nano_left - delta
		_apply_nano_swarm_tick(owner, ab, delta)
	# rage 过期检查
	_check_rage_expire(owner)
	if atype == "periodic":
		_tick_periodic(owner, aid, ab, delta)

static func reset_state() -> void:
	for owner in [Owner.PLAYER, Owner.ENEMY]:
		_expire_rage_if_active(owner)
	_player_active.clear()
	_enemy_active.clear()
	_periodic_timers.clear()
	_nano_remaining.clear()
	_barrage_queue.clear()
	_rage_state.clear()
	_start_fired.clear()
	_battle_active = false
	_battlefield = null
```

- [ ] **Step 4: 各 ability 实现体改 owner 参数**

把原 `_apply_nano_swarm_tick` / `_fire_artillery_shot` / `_apply_mega_shield` / `_fire_nuclear_bombardment` 的内部 `_get_enemy_units()` / `_get_player_units()` 调用替换为 `_get_targets(owner)` / `_get_allies(owner)`，并从敌方版（`enemy_phase_instrument_abilities.gd`）搬运 `rage_buff` 逻辑（`_activate_rage_buff` / `_apply_rage_to_unit` / `_expire_rage_buff` / `_create_rage_aura`），同样 owner 化。

ability_id match 用裸 id：

```gdscript
static func _fire_start_abilities(owner: Owner) -> void:
	var key: String = _owner_key(owner)
	if bool(_start_fired.get(key, false)):
		return
	_start_fired[key] = true
	var ab: Dictionary = _owner_active(owner)
	var aid: String = String(ab.get("id", ""))
	if String(ab.get("type", "")) != "on_battle_start":
		return
	match aid:
		"nano_swarm":
			_start_nano_swarm(owner, ab)
		"mega_shield":
			_apply_mega_shield(owner, ab)
		# nuclear_bombardment / rage_buff 是 periodic，不在此
```

- [ ] **Step 5: VFX 配色按 owner**

nano_swarm 云、shield dome、artillery explosion、rage aura —— 加 owner 选色参数。玩家蓝/橙，敌方红/暗紫。原玩家版配色作 `Owner.PLAYER` 默认；敌方版配色（红/暗紫）从 `enemy_phase_instrument_abilities.gd` 搬入作 `Owner.ENEMY` 分支。

> 先 Read 两 abilities 文件全文对照，确保 VFX 函数与 ability 实现体不遗漏。敌方版各 `_create_*` 函数整体搬入玩家版，加 `owner` 参数选色。

- [ ] **Step 6: 语法验证**

```bash
"$GODOT" --headless --path "." --check-only
```
Expected: 退出码 0。

- [ ] **Step 7: ⚠ Commit（需用户确认）**

```bash
git add managers/battle/phase_instrument_abilities.gd
git commit -m "refactor(abilities): merge into owner-aware single engine (dual-owner)"
```

---

## Task 7: battle_manager.gd — 6 调用点改 3

**Files:**
- Modify: `managers/battle/battle_manager.gd:127, 130, 316, 332, 334, 654`

- [ ] **Step 1: 合并 update / reset_state 双调用**

`:127` + `:130`（两行 `PhaseInstrumentAbilities.update(delta)` + `EnemyPhaseInstrumentAbilities.update(delta)`）合并为单行：

```gdscript
	PhaseInstrumentAbilities.update(delta)
```
删 `:130` 行。

`:332` + `:334`（两行 `reset_state`）合并为：

```gdscript
	PhaseInstrumentAbilities.reset_state()
```
删 `:334` 行。

- [ ] **Step 2: on_battle_start 加 owner 参数**

`:316`：

```gdscript
	PhaseInstrumentAbilities.on_battle_start(PhaseInstrumentManager, battle_scene, PhaseInstrumentAbilities.Owner.PLAYER)
```

`:654`：

```gdscript
		PhaseInstrumentAbilities.on_battle_start(_enemy_phase_driver, battlefield, PhaseInstrumentAbilities.Owner.ENEMY)
```

- [ ] **Step 3: 语法验证 + smoke**

```bash
"$GODOT" --headless --path "." --check-only
"$GODOT" --headless --path "." --script "tests/star_config_smoke.gd"
```
Expected: 退出码 0；smoke PASS。

- [ ] **Step 4: ⚠ Commit（需用户确认）**

```bash
git add managers/battle/battle_manager.gd
git commit -m "refactor(battle-manager): single owner-aware abilities engine calls"
```

---

## Task 8: attack_calculator + bullet — get_active_ability 加 owner

**Files:**
- Modify: `scripts/battle/attack_calculator.gd:318`
- Modify: `scenes/units/bullet.gd:763`

- [ ] **Step 1: 改两处调用**

`attack_calculator.gd:318`：

```gdscript
	var ability: Dictionary = PhaseInstrumentAbilities.get_active_ability(PhaseInstrumentAbilities.Owner.PLAYER)
```

`bullet.gd:763`：

```gdscript
		var ability: Dictionary = PhaseInstrumentAbilities.get_active_ability(PhaseInstrumentAbilities.Owner.PLAYER)
```

> 这两处读玩家相位仪 ability 影响弹道/攻击计算，owner 固定 PLAYER。

- [ ] **Step 2: 语法验证**

```bash
"$GODOT" --headless --path "." --check-only
```
Expected: 退出码 0。

- [ ] **Step 3: ⚠ Commit（需用户确认）**

```bash
git add scripts/battle/attack_calculator.gd scenes/units/bullet.gd
git commit -m "refactor(attack): pass PLAYER owner to get_active_ability"
```

---

## Task 9: UI — 删 special_effects 翻译表，改 special_traits

**Files:**
- Modify: `scenes/ui/leaderboard/leaderboard_presenter.gd:473-489`
- Modify: `scenes/ui/card_info_panel.gd:1300-1303`

- [ ] **Step 1: 删 leaderboard_presenter._translate_special_tag**

`leaderboard_presenter.gd:473-489` 的 `_translate_special_tag` 函数（56 条翻译）删除。其调用点改为直接用 `special_traits`。

> 先 Read 460-500 区，找 `_translate_special_tag` 调用方，改为读 `inst_cfg.get("special_traits", [])`。

- [ ] **Step 2: card_info_panel 改读 special_traits**

`card_info_panel.gd:1300-1303` 当前：

```gdscript
	var se = inst_cfg.get("special_effects", [])
	... 翻译后 join 显示
```

改为：

```gdscript
	var st = inst_cfg.get("special_traits", [])
	... 直接 join 显示（已是中文）
```

- [ ] **Step 3: 语法验证**

```bash
"$GODOT" --headless --path "." --check-only
```
Expected: 退出码 0。

- [ ] **Step 4: ⚠ Commit（需用户确认）**

```bash
git add scenes/ui/leaderboard/leaderboard_presenter.gd scenes/ui/card_info_panel.gd
git commit -m "refactor(ui): drop special_effects translation, use special_traits"
```

---

## Task 10: master_power_evaluator — 改读统一池字段

**Files:**
- Modify: `scripts/master_power_evaluator.gd:644`

- [ ] **Step 1: 改读法**

`master_power_evaluator.gd:644` 当前读敌方相位仪 raw cfg（如 `base_stats`/`atk_bonus`）。改为读统一池字段（`properties`/`active_ability`/`star`）。

> 先 Read 630-660 区确认原评分公式用哪些字段，对应改成统一池字段（base_stats 废除→不读或改 star；atk_bonus→properties pi_atk 求和）。选 B：评分基于 star + properties。

- [ ] **Step 2: 语法验证**

```bash
"$GODOT" --headless --path "." --check-only
```
Expected: 退出码 0。

- [ ] **Step 3: ⚠ Commit（需用户确认）**

```bash
git add scripts/master_power_evaluator.gd
git commit -m "refactor(evaluator): score from unified pool fields (star + properties)"
```

---

## Task 11: 删旧文件 + legacy 常量

**Files:**
- Delete: `managers/battle/enemy_phase_instrument_abilities.gd`
- Delete: `data/json/enemy_phase_instruments.json`
- Modify: `data/enemy_equipment_specials.gd`（删 `LEGACY_PHASE_INSTRUMENTS`）
- Modify: `data/enemy_phase_equipment.gd`（删 `PHASE_INSTRUMENTS`/`LEGACY_PHASE_INSTRUMENTS` 常量引用，line 14, 17, 20-23）

- [ ] **Step 1: 删两文件**

```bash
git rm managers/battle/enemy_phase_instrument_abilities.gd
git rm data/json/enemy_phase_instruments.json
```

- [ ] **Step 2: 删 enemy_equipment_specials.gd 的 LEGACY_PHASE_INSTRUMENTS**

> 先 Read 该文件找 `LEGACY_PHASE_INSTRUMENTS` 定义，删除整个 const 字典。注意保留该文件其它内容（LEGACY_ENERGY_CARDS 等）。

- [ ] **Step 3: 清 enemy_phase_equipment.gd 残留引用**

删 line 14（`PHASE_INSTRUMENTS` static var）、line 17（`ENERGY_CARDS` 保留，但 `_INSTRUMENTS_JSON_PATH` 删）、line 20-23（`LEGACY_PHASE_INSTRUMENTS` const 别名）。保留 `WAR_PLATFORMS`/`WAR_WEAPONS`/`ENERGY_CARDS`。

> Read line 1-35 全文，精确删除相位仪相关行，保留平台/武器/能量卡部分。

- [ ] **Step 4: 全局核实无残留引用**

```bash
grep -rn "EnemyPhaseInstrumentAbilities\|enemy_phase_instruments.json\|LEGACY_PHASE_INSTRUMENTS" --include="*.gd" --include="*.tscn" .
```
Expected: 无输出（仅可能的注释/文档除外）。

```bash
"$GODOT" --headless --path "." --check-only
```
Expected: 退出码 0。

- [ ] **Step 5: ⚠ Commit（需用户确认）**

```bash
git add -A
git commit -m "chore(phase-instrument): delete enemy abilities/json + legacy constants"
```

---

## Task 12: tests/enemy_instrument_abilities_smoke.gd — 改测单引擎

**Files:**
- Modify: `tests/enemy_instrument_abilities_smoke.gd:34, 38, 42, 47`

- [ ] **Step 1: 改调用为单引擎 + owner**

```gdscript
# 原 EnemyPhaseInstrumentAbilities.xxx → PhaseInstrumentAbilities.xxx(OWNER.ENEMY)
PhaseInstrumentAbilities.reset_state()
PhaseInstrumentAbilities.update(0.016)
var ability: Dictionary = PhaseInstrumentAbilities.get_active_ability(PhaseInstrumentAbilities.Owner.ENEMY)
PhaseInstrumentAbilities.on_battle_start(null, null, PhaseInstrumentAbilities.Owner.ENEMY)
```

> Read 该测试文件全文，所有 `EnemyPhaseInstrumentAbilities` 调用替换为 `PhaseInstrumentAbilities` + ENEMY owner。

- [ ] **Step 2: 跑 smoke 验证**

```bash
"$GODOT" --headless --path "." --script "tests/enemy_instrument_abilities_smoke.gd"
```
Expected: PASS。

- [ ] **Step 3: ⚠ Commit（需用户确认）**

```bash
git add tests/enemy_instrument_abilities_smoke.gd
git commit -m "test(abilities): migrate enemy smoke to single owner-aware engine"
```

---

## Task 13: 最终验证（语法 + 套件 + 手动）

**Files:** 无（仅运行验证）

- [ ] **Step 1: 全量语法检查**

```bash
"$GODOT" --headless --path "." --check-only
```
Expected: 退出码 0，无错误。

- [ ] **Step 2: 全量 GdUnit 套件**

```bash
"$GODOT" --headless --path "." --script "tests/gdunit4_runner.gd"
```
Expected: 全 PASS（含 Task 2 新增 test_phase_instruments_unified.gd）。

- [ ] **Step 3: star_config_smoke**

```bash
"$GODOT" --headless --path "." --script "tests/star_config_smoke.gd"
```
Expected: PASS。

- [ ] **Step 4: 手动战斗验证（游戏内）**

启动游戏（`"$GODOT" --path "."`），进战斗，核：
1. 玩家持 `pi_nova_03`（炮击 ability）→ `artillery_barrage` 打敌方单位（橙/蓝 VFX）
2. 敌方 master（如 future 时代持 `pi_void_05`）→ `nano_swarm` 打玩家单位（红/暗紫 VFX）
3. 同场双方 ability 独立计时，不串扰
4. 敌方出兵数受 `slot_counts.green` 限（替代原 unit_capacity）
5. 排行榜/卡信息 UI 正常显示 special_traits 中文

- [ ] **Step 5: ⚠ 最终 Commit（需用户确认）**

若有手动验证修复：

```bash
git add -A
git commit -m "fix(phase-instrument): post-validation tweaks from manual battle test"
```

---

## Self-Review

**1. Spec coverage:**
- §4.1 schema 映射 → Task 2（数据迁入）+ Task 5（driver 读法）✓
- §4.2 owner-aware 单引擎 → Task 6 + Task 7 + Task 8 + Task 12 ✓
- §4.3 id 命名 26 款 → Task 2（_build_all）+ Task 4（master 引用）✓
- §4.4 影响面 17 文件 → 全部任务覆盖 ✓
- 风险点 1（双轨同步）→ Task 4 Step 3 grep 验证 ✓
- 风险点 2（双 owner 隔离）→ Task 6 双 owner 分键 ✓
- 风险点 3（VFX 配色）→ Task 6 Step 5 ✓
- 非目标（master 存储/master 本体技能/玩家 UI 交互/符文/平台武器能量卡）→ 计划未触碰 ✓

**2. Placeholder scan:**
- Task 5/9/10/11 含 "先 Read 确认" 指令 —— 这些是因目标行需读后精确匹配（非 placeholder，给定了改法与字段）。
- Task 2 其余 21 款 "按 spec §4.3 + 模式填" —— spec §4.3 含完整命名表，5 个变体样例覆盖全部形态（mk1/mk4/god/hybrid/omega/带ability），可执行。
- 无 "TBD/TODO/implement later"。

**3. Type consistency:**
- `Owner` enum 全程 `Owner.PLAYER`/`Owner.ENEMY`，`_owner_key` 返回 "player"/"enemy" —— Task 6/7/8/12 一致。
- `get_active_ability(owner: Owner)` 签名 —— Task 6 定义，Task 8/12 调用一致。
- pi_ id 命名 —— Task 2 定义、Task 4 映射表、Task 12 测试一致。
- ability 裸 id（mega_shield/nano_swarm/artillery_barrage/rage_buff/nuclear_bombardment）—— Task 1/2/6 一致。

**4. 已知执行注意:**
- Task 6 最大，需 Read 两 abilities 文件全文对照后改造，建议单独 subagent + 充分时间。
- Task 4 双轨 30 处，机械但量大，建议脚本辅助（可写临时 python 批替换，用后删）。
