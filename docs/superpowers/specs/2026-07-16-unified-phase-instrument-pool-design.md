# 统一相位仪池设计（玩家/敌方共通）

**日期**：2026-07-16
**状态**：待实施
**分支**：feat/v6.14-system-integration
**迁移策略**：big bang（一次到位）

---

## 1. 背景与问题

项目有两套**分离**的相位仪数据，id 空间、schema、消费方全部互不相通：

| 维度 | 玩家版 | 敌方版 |
|---|---|---|
| 数据源 | `data/phase_instruments.gd`（`_build_all()` 35 款） | `data/json/enemy_phase_instruments.json`（26 款，含 `enemy_equipment_specials.gd` legacy fallback） |
| schema | `slot_counts` / `properties` / `special_traits` / `active_ability`（函数生成） | `base_stats` / `atk_bonus`·`hp_bonus`·`def_bonus` / `special_effects` / `active_ability`（死参） |
| 消费方 | `PhaseInstrumentManager` + `PhaseInstrumentAbilities` | `EnemyPhaseFieldDriver` + `EnemyPhaseInstrumentAbilities` |
| ability id | 裸 id（`nano_swarm` 等，打敌/buff己） | `enemy_` 前缀（`enemy_nano_swarm` 等，打己/buff敌） |

现状核实：30 位敌方相位师 **30/30 全引用敌方 JSON 款**，**0 引用**玩家 `pi_*`；敌方 JSON **0 个** `pi_*` 条目；玩家表 **0 个**敌方款。两套零交集。

### 探索发现：大量死数据

消费链路核查（driver/manager/abilities/UI/评分）证实：

- **敌方 `base_stats` 整套是死数据**：`max_hp`/`energy_capacity`/`defense`/`attack_power`/`attack_speed`/`magic_power`/`all_stats_boost` —— driver **从不读**。omega_instrument 的 `max_hp=4000` 从未进战斗。仅展示卡 `_card_resource_from_phase_instrument` 用于 summary。
- **敌方 `special_effects` 56 个 id 全无战斗实现**：纯 UI 翻译展示（`leaderboard_presenter._translate_special_tag` + `card_info_panel`）。
- **玩家 `special_traits` 纯 UI 展示**：无 match 分支，不参与战斗。
- 敌方相位仪"是战斗实体（有血量攻防）"是**假象**——相位仪只影响产兵，自身非战斗单位。

### 真正进战斗的字段仅 4 类

| 字段类 | 玩家 | 敌方 | 对齐性 |
|---|---|---|---|
| 属性乘区 | `properties.pi_atk/pi_def/pi_hp`（×0.05 百分比） | `atk_bonus/hp_bonus/def_bonus`（×0.05 百分比） | **语义完全相同** —— 天然合并桥梁 |
| `active_ability` | 裸 id（打敌） | `enemy_` 前缀（打己） | 结构同，id 空间分离 |
| 限兵 | `slot_counts.green`（战斗卡槽） | `unit_capacity` | 两套机制 |
| 槽位框架 | `slot_counts` + `energy_recovery_rate` + `spawn_range_ratio` | 不存在 | 玩家独有 |

## 2. 目标

两套合并为**统一相位仪池**，玩家与敌方共通。敌方相位师可装备任意相位仪（含原玩家高级款），玩家亦可获得/装备原敌方款。补"独特相位仪"而非"补技能"——技能由相位仪自带的 `active_ability` 承载。

## 3. 核心决策

| 决策点 | 选定 | 理由 |
|---|---|---|
| ability 方向 | **owner-aware 单引擎** | 真正共通，消除两文件镜像重复；方向由持有方（owner）决定 |
| 数据形式 | **全 GDScript** | 符合 CLAUDE.md Data-as-code 原则（"无 JSON/CSV"）；ability 函数生成天然适配；敌方 JSON 本是偏离 |
| id 策略 | **全改 `pi_` 前缀** | id 空间完全统一 |
| 迁移策略 | **big bang 一次到位** | 结果最干净，单次完成 |

## 4. 设计

### 4.1 统一 schema 字段映射

敌方 26 款迁入 `phase_instruments.gd._build_all()`，统一用玩家字段结构，复用 `_make_def`：

| 字段 | 统一处理 |
|---|---|
| `id` | 全改 `pi_` 前缀（命名规则见 §4.3） |
| `name` / `rarity` | 保留 |
| `star`（玩家 1-7） | **敌方款赋 star**：mk1→3 / mk2→5 / mk3→6 / mk4·god·omega→7。ability 函数与槽位布局按 star 分级 |
| `level`（敌方 5-30） | 保留作"出现等级"，master 评分 + driver 用（与 star 解耦，两语义） |
| `faction_id`（玩家公司势力） | **敌方款填 `"generic"`，`is_generic=true`**（不绑公司槽位布局）。敌方法则系（steel/flame/thunder/void）作 flavor 留 name/special_traits |
| `slot_counts` | 敌方款按 star 走 `_STAR_LAYOUT` 默认布局填 |
| `properties`（pi_atk/pi_def/pi_hp...） | **按 star 重算**（选 B），丢弃原 `atk_bonus/hp_bonus/def_bonus` 数值，统一靠 `build_default_shop_properties(star)` + `get_standard_property_value` 派生 |
| `active_ability` | 改调工厂函数，裸 id，owner-aware（见 §4.2）。params 按 star 生成，**丢弃原 JSON 死参** |
| `unit_capacity`（敌方限兵） | **删**，统一用 `slot_counts.green`；`enemy_phase_field_driver.gd:181-184` 改读 green |
| `base_stats`（死数据） | **删**；展示卡 `_card_resource_from_phase_instrument` 改用 star/properties 生成 summary |
| `special_effects`（0 战斗实现） | **转 `special_traits` 中文描述**；UI 统一走 special_traits，删 `_translate_special_tag` 56 条翻译表 |
| `energy_recovery_rate` / `spawn_range_ratio` | 敌方款按 star 派生（复用 `_make_def` 现有逻辑） |

**冲突点决议**：
1. **faction 体系**：敌方款 `is_generic=true`，不绑公司势力。敌方法则系作 flavor，不进 `faction_id` 逻辑。
2. **star vs level**：两字段并存。star 驱动 ability/槽位/属性强度；level 驱动出现等级/评分。
3. **限兵**：删 `unit_capacity`，统一 `slot_counts.green`。
4. **死字段**：`base_stats` 删；`special_effects` 转 `special_traits` 文案。

### 4.2 owner-aware abilities 单引擎

合并 `managers/battle/phase_instrument_abilities.gd` + `enemy_phase_instrument_abilities.gd` → 单引擎，删敌方版。

**关键：双方 ability 可同时激活**（玩家持相位仪 ability，敌方 driver 也持）。`_active_ability` 单变量不够，改按 owner 分键：

- `_player_active` / `_enemy_active` 两份（替代各自 `_active_ability`）
- `_periodic_timers` 按 `"player:artillery"` / `"enemy:rage"` 前缀分键
- nano_swarm 剩余时间 / barrage 队列 / rage 状态 —— 各按 owner 一份

**入口加 owner：**

```gdscript
enum Owner { PLAYER, ENEMY }
static func on_battle_start(source: Node, battlefield: Node, owner: Owner) -> void
static func update(delta: float) -> void          # 内部同时驱动双 owner
static func get_active_ability(owner: Owner) -> Dictionary
static func reset_state() -> void
```

**方向抽象（核心，替代硬编码 `_get_player_units`/`_get_enemy_units`）：**

```gdscript
static func _get_targets(owner: Owner) -> Array:   # 打击目标
    return _get_units("PlayerUnits") if owner == Owner.ENEMY else _get_units("EnemyUnits")
static func _get_allies(owner: Owner) -> Array:    # buff 对象
    return _get_units("EnemyUnits") if owner == Owner.ENEMY else _get_units("PlayerUnits")
```

**ability_id 裸化统一 5 个：**

| 统一 id | 来源 | 行为（按 owner 反转目标） |
|---|---|---|
| `nano_swarm` | `nano_swarm` / `enemy_nano_swarm` | 持续 %max_hp 掉血 → targets |
| `artillery_barrage` | `artillery_barrage` / `enemy_artillery_barrage` | 曲射炮击 → targets |
| `mega_shield` | `mega_shield` / `enemy_shield_bulwark`（合并） | 护盾 → allies |
| `nuclear_bombardment` | `nuclear_bombardment`（敌方原无） | 全体伤害 → targets |
| `rage_buff` | `enemy_rage_buff`（玩家原无） | 攻速/攻击 buff → allies |

**补工厂函数**：`phase_instruments.gd` 加 `ability_rage_buff(star)`（敌方独有 → 通用，玩家款将来也能用）。`enemy_shield_bulwark` 并入 `mega_shield`（同是加护盾，params 都含 `shield_amount`）。

**battle_manager 调用点改 6→3：**

| 原行 | 改为 |
|---|---|
| `:316` `PhaseInstrumentAbilities.on_battle_start(PhaseInstrumentManager, battle_scene)` | `+ OWNER.PLAYER` |
| `:654` `EnemyPhaseInstrumentAbilities.on_battle_start(_enemy_phase_driver, battlefield)` | `PhaseInstrumentAbilities.on_battle_start(_enemy_phase_driver, battlefield, OWNER.ENEMY)` |
| `:127` + `:130` 双 `update` | 合一 `update(delta)` |
| `:332` + `:334` 双 `reset_state` | 合一 `reset_state()` |

**其它消费方：**
- `scripts/battle/attack_calculator.gd:318` + `scenes/units/bullet.gd:763` → `get_active_ability(OWNER.PLAYER)`（弹道读玩家 ability 不变）
- `tests/enemy_instrument_abilities_smoke.gd` → 改测单引擎 `OWNER.ENEMY`

**VFX**：配色按 owner（玩家蓝/橙，敌方红/暗紫），保留现有特效逻辑，加 owner 选色参数。

### 4.3 数据迁移与 id 命名

敌方 26 款（4 系 × mk1-4+god = 20 + 5 hybrid + 1 omega），被 30 位 master 引用。

**pi_ 新 id 命名表：**

| 旧 id | 新 id | star | level |
|---|---|---|---|
| steel_guardian_mk1 / mk2 / mk3 / mk4 / god | `pi_steel_01..05` | 3/5/6/7/7 | 5/12/18/25/29 |
| flame_destroyer_mk1..god | `pi_flame_01..05` | 3/5/6/7/7 | 6/13/19/26/30 |
| thunder_storm_mk1..god | `pi_thunder_01..05` | 3/5/6/7/7 | 7/14/20/27/30 |
| void_walker_mk1..god | `pi_void_01..05` | 3/5/6/7/7 | 8/15/21/28/30 |
| hybrid_steel_flame_mk1 (Lv16) | `pi_steelflame_01` | 5 | 16 |
| hybrid_thunder_steel_mk1 (Lv17) | `pi_thundersteel_01` | 5 | 17 |
| hybrid_void_flame_mk1 (Lv18) | `pi_voidflame_01` | 5 | 18 |
| hybrid_steel_thunder_mk1 (Lv24) | `pi_steelthunder_01` | 6 | 24 |
| hybrid_flame_void_mk1 (Lv25) | `pi_flamevoid_01` | 6 | 25 |
| omega_instrument | `pi_omega_01` | 7 | 30 |

规则：`pi_<法则系>_<NN>`，NN 按 mk 递进，god=05。与玩家 `pi_aegis_01` 同构。`is_generic=true`。

**迁入 `_build_all()` 处理**：
- `properties` 按 star 重算（`build_default_shop_properties(star)`）
- `active_ability` 改调工厂函数，删 `enemy_` 前缀
- `special_effects` 字符串 → 翻译成 `special_traits` 中文描述
- 删 `base_stats` / `unit_capacity`

### 4.4 影响面与验证

**改动文件清单（~17 文件，含删 3）：**

数据层（6）：
- `data/phase_instruments.gd` — `_build_all()` +26 款；加 `ability_rage_buff(star)`；5 ability 工厂函数补齐敌方款 star（3/5/6/7）对应的 params 分支
- `data/json/enemy_phase_instruments.json` — **删**
- `data/enemy_phase_equipment.gd` — `get_phase_instrument` 委托 `PhaseInstruments.get_by_id`；`PHASE_INSTRUMENTS`/`LEGACY` 废弃
- `data/enemy_equipment_specials.gd` — `LEGACY_PHASE_INSTRUMENTS` 删
- `data/json/enemy_phase_masters.json` — 30 处 `phase_instrument` 值改 pi_
- `data/enemy_phase_masters_{ww1,ww2,cold,modern,future}.gd` — `ERA_MASTERS` 30 处同步（GDScript fallback）

战斗层（6）：
- `managers/battle/phase_instrument_abilities.gd` — 合并敌方逻辑，owner-aware 双 owner
- `managers/battle/enemy_phase_instrument_abilities.gd` — **删**
- `managers/battle/battle_manager.gd` — `:127/130/316/332/334/654` 6 调用点 → 3 owner 调用
- `scenes/units/enemy_phase_field_driver.gd` — `:181` unit_capacity→green；`:1099-1117` atk_bonus→properties.pi_atk；setup 数据源改 `PhaseInstruments`
- `scripts/battle/attack_calculator.gd:318` — `get_active_ability(PLAYER)`
- `scenes/units/bullet.gd:763` — `get_active_ability(PLAYER)`

UI/评分（3）：
- `scenes/ui/leaderboard/leaderboard_presenter.gd:473` — `_translate_special_tag` 56 条删
- `scenes/ui/card_info_panel.gd:1300` — special_effects → special_traits
- `scripts/master_power_evaluator.gd:644` — 读法改统一池字段

测试（1）：
- `tests/enemy_instrument_abilities_smoke.gd` — 改测单引擎 ENEMY owner

**验证**：
- **语法**：`--check-only`（按 memory 实际路径 `/d/godot/...`，**不加** `--rendering-driver opengl3` —— headless 卡死）
- **测试套件**：`tests/gdunit4_runner.gd` + `tests/star_config_smoke.gd`
- **单引擎 smoke**：`tests/enemy_instrument_abilities_smoke.gd` 改后跑
- **手动**：进战斗验双方 ability 同场触发（玩家持 `pi_nova_03` 炮击打敌 + 敌方 master 持 `pi_void_05` 虫群打己）

## 5. 风险

1. **双轨同步**：master JSON + GDScript fallback 必须同步改 30 处。漏一处 → JSON 缺失时 fallback 找不到 id。
2. **双 owner 计时隔离**：`_periodic_timers` 按前缀分键，勿让玩家炮击与敌方炮击串计时。
3. **VFX 配色**：按 owner 选色，勿把敌方炮击画成玩家蓝。
4. **pi_special_* 4 款**（`pi_special_rage/void/aegis/nova`，击败掉落）：`acquire_rule=phase_master_drop` 不变，引用的 ability 函数现通用，无冲突。

## 6. 非目标（scope 外）

- **master 数据存储形式不变**（仍 JSON + GDScript fallback），只改 `phase_instrument` 引用 id。
- **master 本体技能不动**：`active_spells`/`passive_spells`/`traits` 是相位师本体技能，非相位仪来源，不在本次范围。
- **玩家相位仪 UI/商店/槽位交互不动**。
- **符文系统（rune/runeword）不动**。
- **敌方平台/武器/能量卡装备**（`enemy_phase_equipment.gd` 的 `WAR_PLATFORMS`/`WAR_WEAPONS`/`ENERGY_CARDS`）不动 —— 仅相位仪部分委托统一池。
