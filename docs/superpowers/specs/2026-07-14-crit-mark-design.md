# 侦查暴击标注系统（Crit Mark）设计文档

- 日期：2026-07-14
- 状态：草案待复审
- 分支：feat/v6.14-system-integration
- 相关系统：UnitStats / module_effect_handler / target_selection / construct_unit_ai / bullet / modification_registry / recon_mods

## 1. 背景与目标

让侦查类单位（侦察无人机 `mod_inf_scout_drone`、斥候、特种、幽灵特工等 recon 卡）成为「集火眼」：攻击命中时按概率给目标挂**暴击标注**，使全队远程火力优先集火该目标，且攻击该目标时暴击率获得加成。

项目已有两套可复用机制：
- **暴击系统**（完整）：`crit_chance` / `crit_damage_bonus` / `crit_resist`，命中时在 `scenes/units/bullet.gd:763-774` roll，公式 `final_damage *= (1.5 + crit_damage_bonus)`。
- **标记 mark 系统**（半残）：`mark_chance` / `mark_vuln_bonus` / `mark_duration`（`resources/unit_stats.gd:230-235`），`rec_13_target_designator` 已用，但仅做易伤增伤；索敌代码**完全不读 mark**（注释「优先打标记目标」是死代码），且 mark 不触发暴击。

本设计新增**独立**的暴击标注系统，复用 mark 的 meta 挂载范式与暴击 roll 链路，但**不改动**现有易伤 mark（`rec_13` / `aa_13` / 激光 / 反击炮不受影响）。

## 2. 设计决策（已与用户确认）

| # | 决策点 | 选择 |
|---|---|---|
| 1 | 伤害结算语义 | 易伤 + 暴击叠加（被标注目标：受伤 ×(1+易伤%) ×(1.5+暴击加成)，若同时存在易伤 mark） |
| 2 | 施加方式 | recon 类单位攻击命中按概率附带（被动） |
| 3 | 暴击强度 | 被标注目标受到攻击时，暴击率额外 **+50%**（叠加到 `crit_chance`） |
| 4 | 与现有 mark 共存 | **独立** `crit_mark` 系统，新增 meta + 字段，不影响 `rec_13`/`aa_13` |

## 3. 默认参数（拍板点）

| # | 点 | 默认 |
|---|---|---|
| 1 | 「远程」定义 | `attack_range >= REMOTE_RANGE_THRESHOLD`（默认 250px，含狙击手/曲射/空射） |
| 2 | 敌方是否享受 | **否**。v1 仅：玩家侦查 → 标注敌方目标 → 玩家远程集火。敌方单位索敌不读 crit_mark |
| 3 | recon 注入方式 | 新建 `rec_14_crit_designator` 改造模块（选装占槽），与 `rec_13`（易伤标注）搭配 |

## 4. 数据模型

### 4.1 `UnitStats` 新增字段（`resources/unit_stats.gd`，紧邻 mark 字段 :230-235）

```gdscript
@export var crit_mark_chance: float = 0.0     # 攻击命中时挂暴击标注的概率
@export var crit_mark_duration: float = 5.0   # 暴击标注持续秒数
@export var crit_mark_bonus: float = 0.50     # 被标注目标受到攻击时暴击率加成（+50%）
@export var crit_mark_priority: bool = true   # 是否触发远程索敌优先（可配置关闭）
```

### 4.2 单位节点 meta（运行时，与 `_marked_until` 同范式）

- `_crit_marked_until: float` — 暴击标注过期时间戳（`Time.get_ticks_msec()/1000.0 + duration`）
- `_crit_mark_bonus: float` — 该目标上的暴击率加成值（取施加方 `crit_mark_bonus`）

### 4.3 registry 映射（`scripts/systems/modification_registry.gd`）

新增 effect key 映射（参考现有 `target_marking`/`mark_vuln`/`mark_duration` → mark 字段的映射范式 :565-572）：

- `crit_mark_chance` → `UnitStats.crit_mark_chance`
- `crit_mark_duration` → `UnitStats.crit_mark_duration`
- `crit_mark_bonus` → `UnitStats.crit_mark_bonus`

### 4.4 全局常量（`resources/game_constants.gd` 或 `GameConfig`）

```gdscript
const REMOTE_RANGE_THRESHOLD: float = 250.0   # attack_range >= 此值视为远程单位
```

## 5. 核心机制（四条链路）

### A. 施加（recon 攻击命中 → 挂 crit_mark）

**入口**：`scripts/battle/module_effect_handler.gd:72` `apply_on_hit_side_effects()`

**新增方法** `_apply_crit_mark(attacker: Node, target: Node, stats: UnitStats)`：

1. 判定 attacker 是否具备施放能力：`stats.crit_mark_chance > 0.0`（由 `rec_14` mod 写入）。无需额外卡前缀判定——`crit_mark_chance>0` 即视为已装备标注能力。
2. `if randf() < stats.crit_mark_chance:` roll 通过。
3. `var now := Time.get_ticks_msec() / 1000.0`
4. `target.set_meta("_crit_marked_until", now + stats.crit_mark_duration)`
5. `target.set_meta("_crit_mark_bonus", stats.crit_mark_bonus)`
6. （可选）emit `SignalBus.combat_highlight("crit_mark_applied", {target})` 供 VFX。

**调用点**：在 `apply_on_hit_side_effects` 内，与 `_apply_mark` 同级调用。施加方 = `crit_mark_chance > 0` 的单位（v1 即装备 `rec_14` 的玩家 recon）。敌方缴获 recon 若也有该字段，标注玩家单位无害——因 §5.B 仅玩家方索敌读 crit_mark，敌方不读。

### B. 索敌优先（远程单位优先集火被标注目标）

**入口**：`scripts/battle/target_selection.gd:109` `select_target()` 三路（DIRECT:10 / INDIRECT:42 / AERIAL:65）

**新增辅助**：

```gdscript
# 在三路函数头部、正式筛选前调用
static func _prioritize_crit_marked(candidates: Array, attacker_stats) -> Array:
    # 仅远程单位（attack_range >= 阈值）且未显式关闭 crit_mark_priority 时触发
    if not (is_remote_unit(attacker_stats) and attacker_stats.crit_mark_priority):
        return candidates
    var marked := candidates.filter(_is_crit_marked_active)
    return marked if not marked.is_empty() else candidates
```

- `_is_crit_marked_active(unit)`: `unit.has_meta("_crit_marked_until") and Time.get_ticks_msec()/1000.0 < unit.get_meta("_crit_marked_until")`
- **远程判定**：`is_remote_unit(stats)` = `stats.attack_range >= REMOTE_RANGE_THRESHOLD`。索敌优先触发条件 = `is_remote_unit(stats) AND stats.crit_mark_priority`（后者默认 true，单位级开关）。
- 仅玩家方接入（`construct_unit_ai._scan_slot_targets:211` 与 `select_target` 调用链）。`enemy_unit._find_target:841` **不接入**。

### C. 暴击触发（攻击被标注目标暴击率 +50%）

**入口**：`scenes/units/bullet.gd:763-774` 现有暴击 roll。

**改动**（现有逻辑后追加）：

```gdscript
# 现有：var effective_crit := max(0.0, shooter_stats.crit_chance - target_crit_resist)
# 新增：
if _is_crit_marked_active(target):
    effective_crit += target.get_meta("_crit_mark_bonus", 0.0)
# 现有：if randf() < effective_crit: final_damage *= (1.5 + shooter_stats.crit_damage_bonus)
```

- 暴击率无显式上限（可 >1.0 → 必定暴击），符合「+50%」叠加语义。
- `_is_crit_marked_active` 抽成 bullet.gd 内私有或复用 target_selection 的静态函数。

### D. 过期清理

**惰性清理**（在 `take_damage` 读取处，与现有 `_marked_until` 同范式）：

- `scenes/units/enemy_unit.gd:1257` 附近、`construct_unit.gd:1168` 附近、`swarm_enemy_slot.gd:233` 附近，读取 `_crit_marked_until` 前先判过期；过期则 `remove_meta("_crit_marked_until")` + `remove_meta("_crit_mark_bonus")`。
- 过期 meta 留在节点上无害（C 链路时间戳判定自然失效），惰性清理即足够，无需 on_tick 主动扫。

## 6. 改造模块定义

**新增** `data/modification_modules/recon_mods.gd`：

```gdscript
# rec_14_crit_designator — 暴击指示器（精确标定仪）
# 攻击命中 30% 概率挂暴击标注 5 秒，被标注目标受到攻击暴击率 +50%
{
    "id": "rec_14_crit_designator",
    "name": "暴击指示器",
    "slot_cost": 1,
    "effects": {
        "crit_mark_chance": 0.30,
        "crit_mark_duration": 5.0,
        "crit_mark_bonus": 0.50
    },
    # ... 描述/图标/适用平台参照 rec_13
}
```

- 槽位、平台适用性、描述文案参照 `rec_13_target_designator`（:147）。
- 注册到 recon mod 列表末尾（id 递增）。

## 7. 接入文件清单（9 处）

| # | 文件 | 改动 |
|---|---|---|
| 1 | `resources/unit_stats.gd` | +4 字段（§4.1） |
| 2 | `resources/unit_stats_table.gd` | `_apply_mod_stat_effects`（:336-339 读 / :405-408 写 范式）贯通 4 字段 |
| 3 | `resources/game_constants.gd` | `REMOTE_RANGE_THRESHOLD` 常量 |
| 4 | `scripts/systems/modification_registry.gd` | `crit_mark_*` effect key → UnitStats 映射（§4.3） |
| 5 | `scripts/battle/module_effect_handler.gd` | `_apply_crit_mark` + `apply_on_hit_side_effects:72` 调用（§5.A） |
| 6 | `scripts/battle/target_selection.gd` | `_prioritize_crit_marked` + 三路头部接入（§5.B） |
| 7 | `scripts/battle/construct_unit_ai.gd` | `_scan_slot_targets:211` 链路确保走接入后的 select_target |
| 8 | `scenes/units/bullet.gd` | 暴击 roll 处加 crit_mark 加成（§5.C） |
| 9 | `data/modification_modules/recon_mods.gd` | `rec_14_crit_designator` 定义（§6） |
| 10 | `scenes/units/enemy_unit.gd` / `construct_unit.gd` / `swarm_enemy_slot.gd` | `take_damage` 惰性清理 meta（§5.D） |

## 8. 平衡参数汇总

| 参数 | 默认 | 来源/说明 |
|---|---|---|
| `crit_mark_chance` | 0.30 | 复用 `rec_13` 的 30% 标记概率 |
| `crit_mark_duration` | 5.0s | 复用 `rec_13` 的 5s |
| `crit_mark_bonus` | +0.50 | 单次攻击期望约 +30%（基础暴击率 10% → 60%），配合易伤 +25% 综合 +62% |
| `REMOTE_RANGE_THRESHOLD` | 250px | 含狙击手/曲射/空射 |
| 敌方享受 | 否 | v1 仅玩家方 |

**平衡考量**：
- 触发有条件（需 recon 命中 + 30% 概率 + 5s 窗口），不会全程覆盖。
- 远程优先可能改变 DIRECT 近战索敌——已用 `is_remote_unit` 限定，近战不受影响。
- 建议：实装 + smoke test 后，视实战回调概率/持续时间。

## 9. 测试方案

新增 `tests/crit_mark_smoke.gd`（参照 `tests/phase_instrument_drop_smoke.gd` 风格）：

1. 构造 recon 单位（`crit_mark_chance=1.0` 强制触发）攻击敌方 → 断言 target 有 `_crit_marked_until` meta。
2. 远程单位（`attack_range >= 250`）索敌 → 断言优先选被标注目标。
3. 近战单位（`attack_range < 250`）索敌 → 断言不优先（保持原逻辑）。
4. `bullet.gd` roll → 断言攻击被标注目标时 `effective_crit` 含 `crit_mark_bonus`。
5. 过期后（`_crit_marked_until` 时间戳过期）→ 断言暴击加成失效。
6. 现有 `rec_13` / `aa_13` 路径回归 → 断言行为不变（独立系统）。

## 10. 风险

| 风险 | 缓解 |
|---|---|
| 暴击率叠加 >1.0 → 必定暴击过强 | 由 `rec_14` 占槽的机会成本制约；可调 `crit_mark_bonus` 下调 |
| 远程索敌优先使近战失 target | `is_remote_unit` 限定，DIRECT 近战不走优先 |
| 现有三条 crit roll 路径不一致（bullet / module_effect_handler / affix_combat_handler） | 本设计只接入主路径 `bullet.gd:763`；另两条为备份/词缀路径，v1 不动，记录待统一 |

## 11. 非目标（YAGNI）

- 不做敌方施加 crit_mark（v1 仅玩家方）。
- 不做 crit_mark 的层数叠加（单层，刷新时间戳）。
- 不做 crit_mark 的 UI 面板配置（参数走 mod effects）。
- 不统一三条 crit roll 路径（另立任务）。
- 不做主动技能 / 光环式施加（已选被动概率方案）。

## 12. 实现顺序建议（供 writing-plans）

1. 数据层：`unit_stats.gd` 字段 + `game_constants` 常量 + `unit_stats_table` 贯通。
2. registry 映射 + `rec_14` mod 定义。
3. 施加链路（`module_effect_handler._apply_crit_mark`）。
4. 暴击触发（`bullet.gd` roll）。
5. 过期清理（三处 `take_damage`）。
6. 索敌优先（`target_selection` + `construct_unit_ai`）。
7. smoke test + 回归验证。
