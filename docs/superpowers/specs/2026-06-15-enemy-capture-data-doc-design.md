# 敌人卡统一 + 缴获卡数据完善 + 资料文档

**状态**: Proposed
**日期**: 2026-06-15
**范围**: 数据补充 + 文档（不重构代码架构、不改刷怪/掉落/关卡逻辑）

---

## 1. 背景与目标

### 现状

战场敌人分 5 段，共 109 个 archetype（见 `data/enemy_unit_manifest.gd`）：

| 段位 | 常量 | 数量 | 数据源 |
|------|------|------|--------|
| A 原平台线 | `FOE_PLATFORM_CARD_IDS` | 28 | `_get_foe_stats()`（经 `_FOE_ID_TO_PLATFORM` 映射） |
| B 特殊/精英 | `FOE_SPECIAL_CARD_IDS` | 6 | `_get_foe_stats()`（直接键） |
| C 固定战场 | `FIXED_ENEMY_IDS` | 36 | `data/json/enemy_archetypes.json` |
| D 补充池 | `POOL_ENEMY_IDS` | 29 | `_pool_stats_for_kind()`（按 index 算 era/kind） |
| E 堡垒 | `FORT_ENEMY_IDS` | 10 | `data/default_cards.gd` 堡垒 `_unit()` 条目 |

缴获卡 `captured_<archetype_id>` 由 `data/captured_unit_cards.gd` 在运行时从 `archetype_config` **动态构建**，注册进 `DefaultCards` 缓存。**无独立可查的静态数据**，策划无法在不改 archetype 的情况下单独调缴获卡数值。

缴获卡面 `vis_player_036~071`（36 张）= C 段 36 个战场敌人的玩家视角卡面，对应 36 张 `captured_enemy_* / captured_elite_* / captured_boss_*`。

### 用户目标

1. 缴获卡面那 36 个定位为"任务专属敌人"（只任务出现，非主线波次主力）。
2. 所有敌人卡统一呈现为"敌人卡"，去掉"补充池/固定原型"等段位技术命名，按出现场景组织。
3. 缴获卡补独立完整静态数据，可独立调平衡。
4. 生成所有敌人（+缴获卡）的完整属性数据资料文档。

---

## 2. 范围边界

**做**：
- 新增 `data/captured_card_stats.gd`（109 张缴获卡全量静态数据表）。
- 改 `CapturedUnitCards._build_captured_card()`：静态表覆盖优先，缺则 fallback 现有动态逻辑。
- 新增 `docs/敌人与缴获卡_完整数据资料.md`（统一资料文档）。

**不做**：
- 不重构敌人数据架构（manifest 5 段常量保留）。
- 不改刷怪 / 掉落 / 关卡 / 任务逻辑。
- 不改 UI。
- 不删现有动态生成逻辑（保留作 fallback，保证向后兼容）。

**平衡原则**：静态表初始值 = 现有动态逻辑计算结果，**不改变游戏平衡**；静态表的意义在于"固化后可独立调"。C 段 JSON 只有单值 `defense`（动态构建时三维防御读 0）的现状如实复刻，文档标注为后续完善点，不在本次擅自改动数值。

---

## 3. 设计

### A. 新文件 `data/captured_card_stats.gd`

```
class_name CapturedCardStats
extends RefCounted
```

- 纯静态数据表 + 一个查询函数，无运行时副作用。
- `const CAPTURED_STATS: Dictionary` — key 为 `captured_<archetype_id>`，共 109 条。
- 每条 value 为 Dictionary，字段对齐 `CardResource` 实际被 `_build_captured_card` 写入的属性：

| 字段 | 类型 | 说明 |
|------|------|------|
| `display_name` | String | 显示名 |
| `era` | int | 时代 0~4 |
| `combat_kind` | int | CombatKind 0~4 |
| `base_hp` | float | 基础 HP |
| `range_value` | int | 射程档（= round(attack_range/100), min 1） |
| `attack_speed` | float | 攻速（= 1/attack_interval） |
| `attack_light` | float | 对轻攻击 |
| `attack_armor` | float | 对装甲攻击 |
| `attack_air` | float | 对空攻击 |
| `defense_light` | float | 对轻防御 |
| `defense_armor` | float | 对装甲防御 |
| `defense_air` | float | 对空防御 |
| `weapon_type` | int | WeaponType |
| `deploy_speed` | int | 部署速度 |
| `base_speed` | float | 移速（由 cfg.speed 推算） |
| `power` | int | 战力 |
| `weapon_label` | String | 武器标签 |
| `type_line` | String | "时代 — 缴获类型" |
| `appear_scope` | String | 出现定位标签（见 §4） |

- `static func get_stats(card_id: String) -> Dictionary`：命中返回该 dict（**深拷贝**，防调用方误改常量），未命中返回 `{}`。

### B. 改 `data/captured_unit_cards.gd`

在 `_build_captured_card(drop_id, display_name, cfg)` **函数开头**插入覆盖查询：

```gdscript
var override: Dictionary = CapturedCardStats.get_stats(drop_id)
if not override.is_empty():
    return _build_from_static(drop_id, override)
```

- 新增私有 `_build_from_static(drop_id, stats) -> CardResource`：直接用静态字段填 `CardResource`，跳过原动态推导（attack 三维分配、speed 推算、power 计算等全部用静态值）。
- 静态表未命中 → 走原动态逻辑（`cfg` 为空时仍从 `EnemyArchetypes.get_config` 取，保持现状）。
- 顶部加 `const CapturedCardStats = preload("res://data/captured_card_stats.gd")`。

**最小侵入**：仅新增一个分支 + 一个私有函数，不改动现有动态路径。

### C. 资料文档 `docs/敌人与缴获卡_完整数据资料.md`

结构：

1. **总览**：109 敌人 + 109 缴获卡，按时代（一战/二战/冷战/现代/近未来）计数表；按"出现定位"计数表。
2. **第一篇 战场敌人**：5 时代章节。每章按类型分组（步兵 / 载具 / 阵地 / 支援 / 堡垒 / BOSS）。每条表格：`archetype_id | 名称 | 时代 | 类型 | HP | 速度 | 攻击三维 | 防御 | 射程 | 攻速 | 武器 | 出现定位`。
3. **第二篇 缴获卡**：5 时代章节。每条表格：`captured_id | 名称 | 时代 | 类型 | HP | 攻击三维 | 防御三维 | 射程档 | 攻速 | 战力 | 武器 | type_line | 任务专属标记`。
4. **附录**：数据源说明（各段数据出处）、待完善清单（如 C 段单值 defense 未展开三维）。

**呈现规则**：
- 全文统一称"敌人卡"，**不出现** A/B/C/D/E / 补充池 / 固定原型等段位技术命名。
- 缴获卡面那 36 个（C 段战场敌人）在缴获卡篇标 `任务专属`。
- 出现定位标签按 §4。

### D. 数据生成方式

静态表的 109 条值由以下规则计算（严格复刻 `_build_captured_card` 现有逻辑）：

- **archetype_id 规则**：A/B 段 = `foe_<card_id>`；C/D/E 段 = 原 id。`captured_id` = `captured_` + archetype_id。
- **属性值规则**（按 `_build_captured_card` 现有推导）：
  - attack 三维：`cfg.attack_damage > 0`（C 段 JSON 走此路）按 `weapon_type` 分配；否则读 `attack_light/armor/air`（A/B 段 manifest 多维数据走此路）。
  - defense 三维：读 `defense_light/armor/air`，缺则 0（C 段单值 `defense` 不展开，如实记 0）。
  - base_speed：`cfg.speed < 0` → `min(abs/0.65, 200)`，否则 0。
  - power：`round(hp*0.3 + Σattack*2 + Σdefense*1.5 + base_speed*0.1)`，min 10。
  - range_value、attack_speed、type_line：见 §A 表。
- **生成过程**：读全 5 个数据源 → 按上述规则逐条算 → 写入 `CAPTURED_STATS`。实施时用脚本/手算核对，保证与动态结果逐条一致。

### E. 校验

1. `Godot --headless --rendering-driver opengl3 --path "." --check-only`：验证 `captured_card_stats.gd` 与改动后的 `captured_unit_cards.gd` 语法 + autoload 链路无报错。
2. 全键覆盖核对：静态表 key 集合 == `EnemyUnitManifest.get_entries()` 109 条的 `captured_<archetype_id>` 集合（脚本对账，0 缺漏）。
3. 抽样一致性：随机抽 10 张，比对静态值与动态 `_build_captured_card` 结果字段相等。

---

## 4. 出现定位标签（`appear_scope`）

文档/数据策划标签，**不改刷怪逻辑**：

| 标签 | 适用 | 数量(约) |
|------|------|---------|
| `主线波次` | A/B/D 段（平台/特殊/补充池） | 63 |
| `任务专属` | C 段战场敌人（缴获卡面 36 个） | 36 |
| `BOSS` | `boss_*` 前缀敌人 | （含在 C 段内，BOSS 优先标 BOSS） |
| `堡垒` | E 段 `fort_*` | 10 |

规则：`boss_*` 标 `BOSS`；`fort_*` 标 `堡垒`；C 段其余（enemy_/elite_）标 `任务专属`；A/B/D 段标 `主线波次`。

---

## 5. 文件清单

| 文件 | 动作 | 说明 |
|------|------|------|
| `data/captured_card_stats.gd` | 新建 | 109 张缴获卡静态数据表 |
| `data/captured_unit_cards.gd` | 改 | `_build_captured_card` 开头加覆盖查询 + 新增 `_build_from_static` |
| `docs/敌人与缴获卡_完整数据资料.md` | 新建 | 统一资料文档（敌人 + 缴获卡） |

---

## 6. 验收标准

- [ ] `captured_card_stats.gd` 含 109 条 `captured_*` 全键。
- [ ] `CapturedUnitCards` 静态表优先、fallback 动态，双路径均可用。
- [ ] Godot `--check-only` 通过，无报错。
- [ ] 资料文档覆盖 109 敌人 + 109 缴获卡，按时代组织，无段位技术命名，缴获卡面 36 个标 `任务专属`。
- [ ] 抽样 10 张缴获卡静态值与动态结果一致。
