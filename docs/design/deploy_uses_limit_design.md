# 每卡部署次数限制 — 设计文档

> **版本**: v1.2 ｜ **日期**: 2026-08-24（v1.2 补进 2026-08-26） ｜ **状态**: 已实施
>
> **设计目标**：为每张战斗卡引入"单场战斗可部署次数"上限，让玩家在 9 槽阵容中做有意义的资源分配决策——低价值炮灰（步兵）多扔、核心资产（堡垒/雷达）少扔，杜绝"死一个扔一个"的无脑循环。

> **⚠️ v1.2 补进（v21.4 实施修订，两项语义变更）**
> 1. **次数池按实例分池**：池键 = 部署身份（实例卡 instance_id / 旧卡裸 card_id）。原实现按裸 card_id 键控，同名卡多实例共享一份池 → 两张同名卡很快双双锁死（用户报告"很多卡死一次就不让上场"的根因，真实战斗驱动实证）。现与 v20.11 存活上限"每装备槽各 1"语义对齐：每张装备的卡各自一份。
> 2. **数值明显上调 + 终极修正仅 rarity 触发**：基线 8/7/6/6/5（原 6/5/4/4/3）、核心档 4（原 2）、card_level≥8 触发 -1 的路径删除（老玩家全队 8 级+ 整队 -1 感知极差）；legendary/mythic 仍 -1。
> 预算验证章节（§3）的算术基于旧数值，仅作历史参考；§4 代码锚点同样为 v1.0 草稿原貌（实现以 `battle_spawn_system.gd`/`unified_card_table.gd` 现行为准）。

---

## 1. 三层架构总览

```
┌─────────────────────────────────────────────────┐
│  L1  总帽（全队）                                │
│  9 槽 × 均 ~4.4 次 = 总预算 36~41 次/场         │
│  敌方枯竭帽 36 次（unit_limit 9 × 4 波均）      │
│  → 我方微弱优势，公平且留挑战                    │
├─────────────────────────────────────────────────┤
│  L2  每卡次数（本设计核心）                      │
│  兵种基线 × 终极修正 × 核心标记判定              │
│  部署即扣，战斗开始重置                          │
├─────────────────────────────────────────────────┤
│  L3  未来能量/资源（预留）                       │
│  相位仪符文"补给"可恢复次数、关卡词条加减等      │
│  不在此期实现，但数据模型预留扩展点               │
└─────────────────────────────────────────────────┘
```

---

## 2. L2 每卡次数 — 判定优先级（三档）

```
1. 显式配置 deploy_uses（单卡覆盖，最高优先）
2. 核心标记：tags 命中 radar/command/hq/侦测 或显式 deploy_class="core"
   → 核心档 2 次
3. 兜底兵种表：LIGHT 6 / SUPPORT 5 / ARMOR 4 / AIR 4 / FORT 3
   × 终极修正（card_level≥8 或 rarity=legendary 再 -1，下限 1，FORT 保底 2）
```

### 2.1 兵种基线表

| CombatKind | 定位价值 | 基线次数 | 设计理由 |
|---|---|---|---|
| `LIGHT` (0) 步兵 | 炮灰/低费 | **6** | 便宜、死得快，多扔维持前线 |
| `SUPPORT` (2) 支援 | 光环/治疗 | **5** | 站得住就少扔，但死了要补 |
| `ARMOR` (1) 装甲 | 主战 | **4** | 中坚战力，死了要重扔但有限 |
| `AIR` (3) 空军 | 高伤机动 | **4** | 高输出但脆，死得快需重扔 |
| `FORT` (4) 堡垒 | 阵地核心 | **3** | 站得住不轻易死，死了重扔很贵 |

### 2.2 终极修正

**触发条件**（满足任一即触发）：
- `card_level ≥ 8`
- `rarity == "legendary"` 或 `"mythic"`

**修正效果**：基线次数 **-1**，下限 1（FORT 保底 2）。

**设计理由**：高练度/传说卡本身属性碾压，次数收紧防止"终极卡无限循环"。

### 2.3 核心标记档（P0 修正）

**触发条件**（满足任一即触发）：
- `tags` 数组命中 `radar`、`command`、`hq`、`侦测` 中任一
- 显式 `deploy_class = "core"`（单卡覆盖，未来扩展用）

**修正效果**：无论兵种基线为何，**强制 2 次**。

**设计理由**：纯指挥/侦测/光环建筑比战斗堡垒更金贵——它们赢在"站着提供光环"，不该靠重扔。2 次 < FORT 战斗堡垒 3 次，体现金贵程度。

**当前命中卡（自动归档，无需逐卡配置）**：
| card_id | display_name | combat_kind | 原基线 | 核心档 |
|---|---|---|---|---|
| `cold_fort_radar` | 雷达站 | FORT | 3 | **2** |
| `platform_ww1_radar` | 一战雷达平台 | SUPPORT | 5 | **2** |
| `platform_ww2_radar` | 二战雷达平台 | SUPPORT | 5 | **2** |
| `platform_cold_radar` | 冷战雷达平台 | SUPPORT | 5 | **2** |
| `platform_modern_radar` | 现代雷达平台 | SUPPORT | 5 | **2** |
| `platform_future_radar` | 近未来雷达平台 | SUPPORT | 5 | **2** |

> `mod_boss_command`（指挥中枢·Boss）是敌方独有（enemy_only），不适用玩家侧每卡次数。

---

## 3. 预算验证

### 3.1 全终极 9 槽（最紧情景）

```
2×LIGHT(6→5) + 2×SUPPORT(5→4) + 2×ARMOR(4→3) + 2×AIR(4→3) + 1×FORT(2)
= 10 + 8 + 6 + 6 + 2 = 32 → 均 3.6
```

### 3.2 全终极 + 1 雷达（含核心标记）

```
2×LIGHT(5) + 2×SUPPORT(4) + 2×ARMOR(3) + 2×AIR(3) + 1×雷达核心(2)
= 10 + 8 + 6 + 6 + 2 = 32 → 均 3.6
```

### 3.3 混编（一半非终极，无雷达）

```
1×LIGHT(6) + 1×LIGHT(5) + 1×SUPPORT(5) + 1×SUPPORT(4) +
1×ARMOR(4) + 1×ARMOR(3) + 1×AIR(4) + 1×AIR(3) + 1×FORT(3)
= 11 + 9 + 7 + 7 + 3 = 37 → 均 4.1
```

### 3.4 混编 + 1 雷达

```
~37 - (SUPPORT 5→2 核心) = 37 - 3 = 34 → 均 3.8
```

### 3.5 纯非终极 9 槽（最松情景）

```
2×LIGHT(6) + 2×SUPPORT(5) + 2×ARMOR(4) + 2×AIR(4) + 1×FORT(3)
= 12 + 10 + 8 + 8 + 3 = 41 → 均 4.6
```

### 3.6 结论

| 情景 | 总次数 | 均次 | vs 敌方枯竭帽 36 |
|---|---|---|---|
| 全终极 | 32 | 3.6 | 略紧，但终极卡属性碾压，少扔也够 |
| 混编 | 37 | 4.1 | ✓ 微弱优势 |
| 全非终极 | 41 | 4.6 | ✓ 明显优势，但非终极卡属性弱所以合理 |

**全部情景落在 32~41 区间，敌方枯竭帽 36 居中——公平且留挑战。**

---

## 4. 实现锚点

### 4.1 数据层：`UnifiedCardTable` 新增字段

**文件**: `data/unified_card_table.gd`

在 `_TABLE` 每条记录中新增可选字段 `deploy_uses`（默认 -1 = 按兵种表自动计算）：

```gdscript
# 新增字段（可选，默认 -1 = 按 combat_kind 自动计算）
# "deploy_uses": 6,  # 显式覆盖（最高优先）
```

**新增静态方法** `get_deploy_uses(entry: Dictionary, card_resource: CardResource = null) -> int`：

```gdscript
## 计算单场战斗可部署次数
## 优先级：显式配置 > 核心标记(2) > 兵种基线 × 终极修正
## card_resource 为 null 时仅按 entry 判定（敌方/预览用）
static func get_deploy_uses(entry: Dictionary, card: CardResource = null) -> int:
    # 1. 显式配置
    if entry.has("deploy_uses") and int(entry["deploy_uses"]) >= 0:
        return int(entry["deploy_uses"])

    var ck: int = int(entry.get("combat_kind", 0))
    var tags: Array = entry.get("tags", [])

    # 2. 核心标记判定
    if _is_core_unit(tags, entry):
        return 2

    # 3. 兵种基线
    var uses: int = _baseline_deploy_uses_for_combat_kind(ck)

    # 4. 终极修正
    if _is_ultimate(card, entry):
        uses -= 1
        if ck == GameConstants.CombatKind.FORT:
            uses = maxi(uses, 2)  # FORT 保底 2
        else:
            uses = maxi(uses, 1)  # 通用下限 1

    return uses

static func _baseline_deploy_uses_for_combat_kind(ck: int) -> int:
    match ck:
        GameConstants.CombatKind.LIGHT:   return 6
        GameConstants.CombatKind.SUPPORT: return 5
        GameConstants.CombatKind.ARMOR:   return 4
        GameConstants.CombatKind.AIR:     return 4
        GameConstants.CombatKind.FORT:    return 3
        _: return 4

static func _is_core_unit(tags: Array, entry: Dictionary) -> bool:
    # 显式 deploy_class
    if String(entry.get("deploy_class", "")) == "core":
        return true
    # tags 命中
    for tag in tags:
        if tag in ["radar", "command", "hq", "侦测"]:
            return true
    return false

static func _is_ultimate(card: CardResource, entry: Dictionary) -> bool:
    if card != null:
        if card.rarity in ["legendary", "mythic"]:
            return true
        # 从 InstanceRegistry 查 card_level
        if not card.instance_id.is_empty():
            var ir = Engine.get_main_loop().root.get_node_or_null("/root/InstanceRegistry")
            if ir != null and ir.has_method("get_card_level"):
                if ir.get_card_level(card.instance_id) >= 8:
                    return true
    # 回退：entry 层显式标记
    if String(entry.get("rarity", "")) in ["legendary", "mythic"]:
        return true
    return false
```

### 4.2 战斗层：`BattleSpawnSystem` 新增次数追踪

**文件**: `managers/battle/battle_spawn_system.gd`

**新增成员变量**：

```gdscript
## 每卡剩余部署次数追踪（base_card_id → int）
## 战斗开始时由 _reset_deploy_uses() 初始化，部署时扣减
var _deploy_uses_remaining: Dictionary = {}  # String → int
```

**新增方法**：

```gdscript
## 战斗开始时初始化所有装备卡的部署次数
func _reset_deploy_uses() -> void:
    _deploy_uses_remaining.clear()
    if _phase_instrument == null:
        return
    var loadouts: Array = _phase_instrument.get_loadouts() if _phase_instrument.has_method("get_loadouts") else []
    for lo in loadouts:
        var card: CardResource = lo.get("platform", null)
        if card == null:
            continue
        var base_id: String = card.card_id
        var entry: Dictionary = UnifiedCardTable.get_entry(base_id)
        if entry.is_empty():
            continue
        var uses: int = UnifiedCardTable.get_deploy_uses(entry, card)
        _deploy_uses_remaining[base_id] = uses

## 检查某卡是否还有剩余部署次数（base_card_id 为剥离 #序号 的裸 ID）
func _has_deploy_uses(base_card_id: String) -> bool:
    return int(_deploy_uses_remaining.get(base_card_id, 0)) > 0

## 部署时扣减次数
func _consume_deploy_use(base_card_id: String) -> void:
    var cur: int = int(_deploy_uses_remaining.get(base_card_id, 0))
    if cur > 0:
        _deploy_uses_remaining[base_card_id] = cur - 1

## 查询剩余次数（HUD 显示用）
func get_deploy_uses_remaining(base_card_id: String) -> int:
    return int(_deploy_uses_remaining.get(base_card_id, 0))
```

**修改 `request_player_deploy`** — 在现有 `_reach_alive_limit_for_card` 检查之后，插入部署次数检查：

```gdscript
# 在 _reach_alive_limit_for_card 检查之后（约 L588），插入：
if not _no_limits and not _has_deploy_uses(base_card_id):
    _emit_deploy_failed("deploy_uses_exhausted", "该单位部署次数已耗尽，本场战斗无法再部署。")
    return false

# 在部署成功后（约 L630+，spawn 成功路径），扣减次数：
_consume_deploy_use(base_card_id)
```

**在 `start_battle` 中调用 `_reset_deploy_uses()`**：

```gdscript
# 在 start_battle / on_battle_start 末尾添加：
_reset_deploy_uses()
```

### 4.3 信号与事件

**新增信号**（`SignalBus`）：

```gdscript
## 部署次数变化（base_card_id, remaining, total）
signal deploy_uses_changed(base_card_id: String, remaining: int, total: int)
```

在 `_consume_deploy_use` 中发射：

```gdscript
func _consume_deploy_use(base_card_id: String) -> void:
    var cur: int = int(_deploy_uses_remaining.get(base_card_id, 0))
    if cur > 0:
        _deploy_uses_remaining[base_card_id] = cur - 1
        var total: int = _get_deploy_uses_total(base_card_id)
        SignalBus.deploy_uses_changed.emit(base_card_id, cur - 1, total)
```

### 4.4 HUD 显示（可选，二期）

- `bottom_instrument_bar` 槽位显示剩余次数（如 `×3`）
- 次数耗尽时槽位变灰/加锁图标
- 战斗结束总结显示各卡消耗次数

### 4.5 存档兼容

- **不存档**：`_deploy_uses_remaining` 是战斗运行时态，每次 `start_battle` 重新初始化。
- 旧档无感知——新字段 `deploy_uses` 在 `_TABLE` 中默认 -1，行为完全由 `combat_kind` 推导。

### 4.6 测试清单

| # | 测试点 | 预期 |
|---|---|---|
| 1 | LIGHT 步兵部署 6 次后第 7 次被拒 | `deploy_uses_exhausted` 错误 |
| 2 | FORT 堡垒部署 3 次后第 4 次被拒 | 同上 |
| 3 | 终极卡（card_level≥8）LIGHT 仅 5 次 | 基线 6 - 1 = 5 |
| 4 | 终极卡 FORT 保底 2 次 | 基线 3 - 1 = 2，不低于 2 |
| 5 | 传说卡 ARMOR 仅 3 次 | rarity=legendary 触发 -1 |
| 6 | 雷达站（cold_fort_radar）仅 2 次 | 核心标记档覆盖 |
| 7 | 雷达平台（5 时代）各仅 2 次 | tags 命中 radar |
| 8 | 显式 deploy_uses=1 覆盖所有规则 | 最高优先 |
| 9 | 战斗结束后再开新战斗，次数重置 | 重新初始化 |
| 10 | debug_no_deploy_limits=true 跳过所有检查 | 不限制 |

---

## 5. 涉及文件清单

| 文件 | 改动类型 | 说明 |
|---|---|---|
| `data/unified_card_table.gd` | **新增方法** | `get_deploy_uses()` + 辅助函数 + 基线表 |
| `managers/battle/battle_spawn_system.gd` | **新增字段+方法+埋点** | `_deploy_uses_remaining` 字典 + 初始化/扣减/查询 + `request_player_deploy` 埋点 |
| `scripts/signal_bus.gd` | **新增信号** | `deploy_uses_changed(base_card_id, remaining, total)` |
| `scenes/ui/bottom_instrument_bar.gd` | **可选改动** | 显示剩余次数（二期） |
| `tests/deploy_uses_smoke.gd` | **新增测试** | 无 GdUnit 依赖的冒烟测试 |

---

## 6. 设计原则回顾

1. **光环型（SUPPORT/FORT）天然抗耗**——站得住就不吃次数；空军/装甲死了重扔才烧次数。数值上已体现。
2. **核心标记独立于兵种**——雷达/指挥类不论 combat_kind 均按 2 次，比战斗堡垒更金贵。
3. **基线进 `UnifiedCardTable` 按兵种默认生成**——单卡可覆盖（`deploy_uses` 显式值优先）。
4. **计数口径：部署即扣**——战斗开始重置。
5. **9 槽 = 敌方 unit_limit 9**——同构约束，总预算 32~41 vs 敌方枯竭帽 36，我方微弱优势。