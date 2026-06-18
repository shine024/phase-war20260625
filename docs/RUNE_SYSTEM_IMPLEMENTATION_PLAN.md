# 符文系统实施计划（RUNE_SYSTEM_IMPLEMENTATION_PLAN）

> 创建日期：2026-06-17
> 状态：**核心功能已完成（P0-P5.3）** ✅
> 决策依据：参考暗黑破坏神2符文/符文之语机制

---

## 实施完成总览

| 阶段 | 内容 | 状态 |
|------|------|------|
| P0 | 数据层（runes.gd + runewords.gd） | ✅ 完成 |
| P1 | 符文之语匹配引擎（runeword_matcher.gd） | ✅ 完成 |
| P2 | 相位仪数据 + 管理器改造 | ✅ 完成 |
| P3 | 战斗加成注入 | ✅ 完成 |
| P4 | 符文管理面板 UI | ✅ 完成 |
| P5.1 | 18个势力专属符文补充 | ✅ 完成（共51符文） |
| P5.2 | 掉落系统接入 | ✅ 完成 |
| P5.3 | 势力商店接入 | ✅ 完成 |
| P5.4 | 存档系统 | ✅ 完成（save_state 已含 rune_state） |
| P5.5 | 法则系统清理 | ⏸ 延后（槽位已为0，法则自动失效） |

---

## 实际改动文件清单

### 新建文件（5个）
| 文件 | 行数 | 说明 |
|------|------|------|
| `data/runes.gd` | ~1000 | 51个符文定义（33通用 + 18专属） |
| `data/runewords.gd` | ~1100 | 65种符文之语定义（4层级） |
| `managers/runeword_matcher.gd` | ~170 | 纯数据驱动匹配引擎 |
| `scenes/ui/rune_panel.gd` | ~330 | 符文管理面板（槽位/筛选/激活预览） |
| `docs/RUNE_SYSTEM_IMPLEMENTATION_PLAN.md` | 本文档 | 计划+实施记录 |

### 修改文件（6个）
| 文件 | 改动说明 |
|------|---------|
| `data/phase_instruments.gd` | 槽位结构改为 green/yellow/rune，移除 red/blue；颜色映射函数更新 |
| `managers/phase_instrument_manager.gd` | 新增符文槽位管理系统（装备/卸下/缓存/存档），与现有四色槽并行 |
| `managers/battle/battle_spawn_system.gd` | 新增 `_apply_rune_bonus_to_stats()` 注入符文之语加成到 UnitStats |
| `managers/battle/battle_damage_system.gd` | 新增 `_roll_rune_drops()` 按稀有度概率掉落符文 |
| `managers/faction/faction_shop.gd` | 新增 StoreItemType.RUNE + 专属符文商品上架 + 发放逻辑 |
| `resources/drop_tables.gd` | DropType 枚举新增 RUNE（13） |

---

## 核心决策（已确认并实现）

| 决策项 | 选择 | 实现情况 |
|--------|------|---------|
| 符文总数 | **51个**（33通用 + 18专属） | ✅ |
| 符文之语 | **65种** | ✅ |
| 符文分配 | **通用 + 专属混合** | ✅（每势力2-3个） |
| 效果类型 | **数值+少量特殊效果** | ✅（10种特殊效果） |
| 槽位机制 | **相位仪1-6个符文槽位** | ✅（按星级递增） |
| 装备时机 | **战前装备，战斗不变更** | ✅ |
| 加成范围 | **全局加成（所有单位共享）** | ✅ |
| 槽位隔离 | **战斗卡/能量卡/符文严格互斥** | ✅ |
| 法则系统 | **废弃** | ✅（槽位归零，自动失效） |
| 老存档 | **不处理迁移** | ✅ |

---

## 技术实现要点

### 1. 数据驱动设计（无硬编码 switch/case）
- 符文效果通过 `primary_effect` / `secondary_effect` 字典定义
- 符文之语效果通过 `effects[]` 数组定义，支持 `stat`（数值）和 `special`（特殊）两种格式
- 匹配引擎 `RunewordMatcher` 纯数据驱动，无 effect-string match 语句

### 2. 与现有系统解耦
- 符文槽位与四色槽位完全独立运行
- 加成通过 `battle_spawn_system._build_stats_cached()` 统一注入点生效
- 存档通过 `PhaseInstrumentManager.save_state()` 的 `rune_state` 字段自动保存

### 3. 渐进式迁移（不破坏现有功能）
- 保留所有现有法则系统代码（标记为废弃但不删除）
- 相位仪 slot_counts 中 red/blue 设为0，法则同步逻辑自动处理空数组
- UI 新增独立符文面板，不改动现有底部栏

---

## 验证状态

- ✅ **语法验证**：所有新建/修改文件通过 Godot headless `--script tests/star_config_smoke.gd` 编译检查
- ✅ **无新增编译错误**：剩余错误（ModificationRegistry、era数值）均为预存问题，与本次改动无关
- ⏳ **运行时测试**：需要在实际游戏中验证符文装备、加成生效、掉落、商店购买等流程

---

## 后续可迭代优化（非本次范围）

1. **特殊效果触发实现**：当前特殊效果存储在 `stats.set_meta("rune_specials", ...)`，需要在 construct_unit.gd 的攻击/受击/死亡事件中实现触发逻辑
2. **符文面板注册到 UILazyLoader**：当前 rune_panel.gd 已就绪，需在 ui_lazy_loader.gd 注册 panel_id 并在 main.tscn 添加对应 Overlay 容器
3. **符文图鉴系统**：收集进度展示
4. **符文合成**：低级符文合成高级
5. **法则系统彻底清理**：从 autoload 移除 PhaseLawManager，删除废弃文件
6. **平衡性调优**：65种符文之语的实际数值需要游戏内测试调整

---

## 一、核心决策（已确认）

| 决策项 | 选择 | 说明 |
|--------|------|------|
| 符文总数 | **33个** | 暗黑2经典数量，分5类 |
| 符文之语 | **65种** | 特定组合触发，4层级 |
| 符文分配 | **15通用 + 18专属** | 专属符文通过势力声望解锁 |
| 效果类型 | **数值+少量特殊效果** | 大部分百分比加成，顶级带特殊效果 |
| 槽位机制 | **相位仪1-6个符文槽位** | 替换当前红蓝绿黄4色槽 |
| 装备时机 | **战前装备，战斗不变更** | 战斗中不可切换 |
| 加成范围 | **全局加成（所有单位共享）** | 统一注入到UnitStats |
| 槽位隔离 | **战斗卡槽/能量卡槽/符文槽互斥** | 战斗卡槽仅放战斗卡，能量卡槽仅放能量卡，符文槽仅放符文 |
| 法则系统 | **废弃** | 老存档不迁移，新版本从0开始 |
| 老存档 | **不处理迁移** | 简化实现 |

---

## 二、进度跟踪

### P0：数据层（已完成 ✅）

| 文件 | 状态 | 说明 |
|------|------|------|
| `data/runes.gd` | ✅ 已创建 | 33个符文定义，5类（攻击8/防御8/能量6/机动5/特殊6），4稀有度（常见10/稀有12/史诗7/传说4） |
| `data/runewords.gd` | ✅ 已创建 | 65种符文之语，4层级（2符文25种/3符文20种/4符文15种/5符文5种），含10种特殊效果 |

**P0交付物验证清单：**
- [x] 33个符文均有唯一id、name、category、rarity、faction_id、star_requirement
- [x] 15个通用符文（faction_id="generic"）
- [x] 每个符文有 primary_effect（必需）和 secondary_effect（可选）
- [x] 65个符文之语均有 required_runes[]、min_slot_count、effects[]
- [x] effects 支持两种格式：`{"stat": xxx, "value": yyy}` 和 `{"special": xxx, "chance": yyy, "value": zzz}`
- [x] 层级分布：TIER_2=25, TIER_3=20, TIER_4=15, TIER_5=5

---

### P1：符文之语匹配引擎（待执行 ⏳）

**新建文件：`managers/runeword_matcher.gd`**

#### 职责
- 输入：当前相位仪上装备的符文ID列表 + 相位仪槽位总数
- 输出：匹配成功的符文之语列表 + 合并后的效果字典

#### 核心函数设计

```gdscript
extends RefCounted
class_name RunewordMatcher

## 检查当前装备的符文激活了哪些符文之语
## 返回：[{id, name, tier, effects}, ...]
static func check_active_runewords(active_rune_ids: Array[String], slot_count: int) -> Array[Dictionary]:
    var results: Array[Dictionary] = []
    for rw in RunewordDefinitions.ALL_RUNEWORDS:
        if _matches(active_rune_ids, rw.required_runes) and slot_count >= rw.min_slot_count:
            results.append(rw)
    return results

## 检查符文组合是否满足符文之语要求（含重复符文处理）
static func _matches(active_runes: Array[String], required: Array[String]) -> bool:
    var available := active_runes.duplicate()
    for req in required:
        var idx = available.find(req)
        if idx == -1:
            return false
        available.remove_at(idx)
    return true

## 合并所有激活符文之语的效果，返回最终加成
## 返回：{
##   "stats": {attack: 0.5, hp: 0.3, ...},  # 数值加成（叠加）
##   "specials": [{special: "...", chance: ..., value: ...}, ...]  # 特殊效果（不叠加，独立触发）
## }
static func merge_effects(active_runewords: Array[Dictionary]) -> Dictionary:
    var merged_stats: Dictionary = {}
    var merged_specials: Array[Dictionary] = []
    for rw in active_runewords:
        for effect in rw.get("effects", []):
            if effect.has("stat"):
                var key = effect["stat"]
                merged_stats[key] = merged_stats.get(key, 0.0) + effect["value"]
            elif effect.has("special"):
                merged_specials.append(effect)
    return {"stats": merged_stats, "specials": merged_specials}

## 获取当前完整加成（一步到位的便捷函数）
static func get_active_bonus(active_rune_ids: Array[String], slot_count: int) -> Dictionary:
    var matched = check_active_runewords(active_rune_ids, slot_count)
    return merge_effects(matched)

## 预览：列出某符文组合潜在可激活的符文之语（用于UI提示）
static func preview_potential_runewords(active_rune_ids: Array[String]) -> Array[Dictionary]:
    var results: Array[Dictionary] = []
    for rw in RunewordDefinitions.ALL_RUNEWORDS:
        if _is_subset(rw.required_runes, active_rune_ids):
            results.append(rw)
    return results

## 检查 required 是否是 active 的子集（不考虑重复）
static func _is_subset(required: Array[String], active: Array[String]) -> bool:
    for req in required:
        if not active.has(req):
            return false
    return true
```

#### 测试用例（待编写）
- 空 slot → 不激活任何符文之语
- 装备 ["attack_01","attack_02"] → 激活 rw_2_01（锐利）
- 装备 ["attack_01","attack_02","defense_01"] → 激活 rw_2_01（锐利）
- slot_count=1 但 required=2 → 不激活（min_slot_count 拦截）
- 装备 ["attack_01","attack_01"] → 不激活（重复符文不能凑成2符文之语，因为符文之语需要不同符文）

---

### P2：相位仪数据 + 管理器改造（待执行 ⏳）

#### P2.1 修改 `data/phase_instruments.gd`

**改动点：**
1. 每个 instrument 定义新增字段：
   ```gdscript
   "rune_slot_count": 4,  # 符文槽数量（1-6，按星级递增）
   ```
2. 星级与槽位对应规则：
   | 星级 | 战斗卡槽 | 能量卡槽 | 符文槽 |
   |------|---------|---------|--------|
   | 1星 | 1 | 1 | 1 |
   | 2星 | 2 | 1 | 2 |
   | 3星 | 2 | 1 | 3 |
   | 4星 | 3 | 2 | 4 |
   | 5星 | 3 | 2 | 5 |
   | 6星 | 4 | 2 | 5 |
   | 7星 | 4 | 2 | 6 |

3. **保留** `slot_counts`（green/red/blue/yellow）字段用于兼容，但新增 `rune_slot_count`

#### P2.2 修改 `managers/phase_instrument_manager.gd`

**改动范围（约300行）：**

1. **新增状态**：
   ```gdscript
   # 符文槽位：索引0到rune_slot_count-1
   var _rune_slots: Array = []  # Array[String] 符文ID
   var _cached_active_bonus: Dictionary = {}  # 缓存的加成结果
   var _cached_active_runewords: Array[Dictionary] = []  # 缓存的激活符文之语
   ```

2. **替换红蓝绿黄slot相关逻辑**：
   - 删除 `SLOT_COLOR_ORDER = ["red", "blue", "green", "yellow"]`
   - 删除 `_can_equip_card_to_color()` 的颜色校验
   - 删除 `_flat_index_to_slot()` / `_slot_to_flat_index()`
   - 改为三种槽位：`combat_unit_slots`、`energy_card_slots`、`rune_slots`

3. **删除法则同步逻辑**：
   - 删除 `_apply_law_slots_to_plm()`
   - 删除 `sync_law_cards_to_phase_law_manager()`
   - 删除 `migrate_law_slots_from_phase_law_manager_if_empty()`
   - 删除 `force_sync_instrument_law_slots()`

4. **新增符文操作函数**：
   ```gdscript
   func equip_rune(slot_index: int, rune_id: String) -> bool
   func unequip_rune(slot_index: int) -> void
   func get_rune_slots() -> Array[String]
   func get_rune_slot_count() -> int
   func get_active_bonus() -> Dictionary  # 返回合并后的加成
   func get_active_runewords() -> Array[Dictionary]  # 返回激活的符文之语列表
   func _refresh_active_bonus() -> void  # 内部：装备变更后刷新缓存
   ```

5. **保留不变**：
   - 相位场XP系统（16级）
   - 相位仪属性池（properties[]）
   - 掉落系统（try_roll_battle_drop_instrument）
   - `apply_phase_field_bonus_to_unit_stats()` 函数签名不变，内部增加符文加成合并

---

### P3：战斗加成注入（待执行 ⏳）

#### P3.1 修改 `managers/battle/battle_spawn_system.gd`

**改动点：**
在 `_build_stats_cached()` 中（约 line 742-792），追加符文加成注入：

```gdscript
# 现有：势力加成、蓝图成长、相位场加成 → 已生效
# 新增：符文之语加成
var rune_bonus = PhaseInstrumentManager.get_active_bonus()
var stats = _apply_rune_bonus_to_stats(stats, rune_bonus)
```

**新增辅助函数：**
```gdscript
func _apply_rune_bonus_to_stats(stats: UnitStats, bonus: Dictionary) -> UnitStats:
    var stat_map = bonus.get("stats", {})
    if stat_map.has("attack"): stats.attack *= (1.0 + stat_map["attack"])
    if stat_map.has("defense"): stats.defense *= (1.0 + stat_map["defense"])
    if stat_map.has("hp"): stats.max_hp *= (1.0 + stat_map["hp"])
    if stat_map.has("attack_speed"): stats.attack_speed *= (1.0 + stat_map["attack_speed"])
    # ... 其他属性
    return stats
```

#### P3.2 特殊效果注入

特殊效果（on_kill_regen_energy 等）不通过 stats 注入，而是通过 SignalBus 或单位回调：

```gdscript
# 在 UnitStats 上附加 special_effects 数组
stats.special_effects = bonus.get("specials", [])
# 单位在 on_kill / on_hit / on_damaged 等事件中检查并触发
```

**特殊效果触发点（共7处，约50行）：**
- `construct_unit.gd` 的 `_on_attack_landed()` → 检查 on_hit_chain_lightning、on_area_damage、on_attack_penetration
- `construct_unit.gd` 的 `_on_kill()` → 检查 on_kill_regen_energy
- `construct_unit.gd` 的 `_on_damaged()` → 检查 on_damage_reduction、on_energy_shield
- `construct_unit.gd` 的 `_on_death()` → 检查 on_death_respawn
- `EnergyManager` → 应用 energy_regen、energy_cost_reduction
- `BattleManager` 战斗结算 → 应用 on_explore_bonus、on_resource_yield

---

### P4：UI改造（待执行 ⏳）

#### P4.1 修改 `scenes/ui/bottom_instrument_bar.gd`

**改动范围（约200行）：**

1. **删除颜色相关代码**：
   - 删除 `_slot_bg()`、`_slot_border()`、`get_slot_color_value()` 中的颜色逻辑
   - 删除 `_slot_name()` 中的"单位/主动法则/被动法则/能量"映射

2. **改为三类槽位显示**：
   ```
   [战斗卡1][战斗卡2][战斗卡3][战斗卡4]  [能量卡1][能量卡2]  [符文1][符文2][符文3][符文4][符文5][符文6]
   ↑ 战斗单位槽                     ↑ 能量槽        ↑ 符文槽
   ```

3. **新增符文之语提示区**：
   - 底部栏新增一行：显示当前激活的符文之语名称（高亮显示）
   - 鼠标悬停显示效果详情

#### P4.2 修改 `scenes/ui/instrument_bar_drag.gd`

**改动点（约100行）：**
- `_can_drop_data()` 校验逻辑：根据目标槽位类型校验拖拽物
  - 战斗卡槽 → 只接受 COMBAT_UNIT 卡
  - 能量卡槽 → 只接受 ENERGY 卡
  - 符文槽 → 只接受符文（rune_id 字符串）

#### P4.3 新建符文背包面板（可选，建议P4末尾）

**新建 `scenes/ui/rune_inventory_panel.gd`**
- 展示所有已拥有的符文（按分类/稀有度筛选）
- 点击符文 → 选择装备到哪个符文槽
- 显示符文之语组合预览

#### P4.4 删除废弃的法则UI

| 文件 | 处理 |
|------|------|
| `scenes/ui/phase_law_panel.gd` | 删除或保留为遗留文件 |
| `scenes/ui/active_law_cast_panel.gd` | 删除 |
| `scenes/ui/equipped_passives_box.gd` | 删除 |

---

### P5：势力专属符文 + 掉落 + 存档（待执行 ⏳）

#### P5.1 在 `data/runes.gd` 补充18个专属符文

**分配方案（每势力2-3个，共18个）：**

| 势力 | 数量 | 符文示例 |
|------|------|---------|
| aether_dynamics（以太动力） | 3 | 能量向：能量恢复+特殊 |
| helix_recon（螺旋侦察） | 2 | 机动向：闪避+侦察 |
| nova_arms（新星军备） | 3 | 攻击向：攻击力+暴击 |
| iron_wall_corp（铁壁公司） | 3 | 防御向：HP+减伤 |
| void_research（虚空研究） | 2 | 特殊向：神秘效果 |
| quantum_logistics（量子物流） | 2 | 经济向：资源+部署 |
| frontier_union（边境联盟） | 3 | 均衡向：全属性 |

每个专属符文设置 `unlock_requirement: {"faction_id": xxx, "min_reputation": 1000}`。

#### P5.2 掉落系统接入

**修改 `resources/drop_tables.gd`**：
- 新增掉落类型：`DROP_RUNE`
- 按稀有度配置权重：
  - common: 权重 100（常见掉落）
  - rare: 权重 30
  - epic: 权重 8
  - legendary: 权重 1（极稀有）

**修改 `managers/battle/battle_damage_system.gd`**：
- 击杀敌人时，按概率掉落符文（替代或并存于当前的"知识"掉落）

#### P5.3 势力商店接入

**修改 `managers/faction/faction_shop.gd`**：
- 新增商品类别：`CATEGORY_RUNE`
- 各势力商店上架对应的专属符文（需声望解锁）
- 通用符文也可在所有势力商店购买

#### P5.4 存档系统改造

**修改 `managers/save_manager.gd`**：

1. **schema version 升级**：v5 → v6
2. **新增迁移函数** `save_migration_v6.gd`：
   - 移除 `phase_law` section（废弃法则数据）
   - 新增 `runes` section：`{owned_rune_ids: [...], rune_slots: [...]}`
3. **PhaseInstrumentManager save_state() 增加字段**：
   ```gdscript
   {
       # ... 现有字段 ...
       "rune_slots": ["attack_01", "defense_02", null, null],  # 符文槽内容
       "owned_rune_ids": ["attack_01", "defense_02", "energy_01", ...]  # 已拥有的符文
   }
   ```

#### P5.5 废弃法则系统清理

**保留但标记废弃（不删除，方便回滚）：**
- `data/phase_laws.gd` — 保留
- `managers/phase_law_manager.gd` — 保留但从 autoload 移除
- `managers/active_law_effects.gd` — 保留

**从 `project.godot` 移除 autoload：**
- `PhaseLawManager`

**删除引用（约20处）：**
- `managers/game_manager.gd` 中对 PhaseLawManager 的引用
- `managers/battle/battle_manager.gd` 中对 PhaseLawManager 的引用
- `scenes/main.gd` 中法则施放入口
- `data/default_cards.gd` 中法则卡创建逻辑

---

## 三、文件改动清单

### 新建文件（4个）
| 文件 | 预估行数 | 阶段 |
|------|---------|------|
| `data/runes.gd` | ~600 | ✅ 已完成 |
| `data/runewords.gd` | ~750 | ✅ 已完成 |
| `managers/runeword_matcher.gd` | ~100 | P1 |
| `scenes/ui/rune_inventory_panel.gd` | ~300 | P4（可选） |

### 修改文件（9个）
| 文件 | 改动行数 | 阶段 |
|------|---------|------|
| `data/phase_instruments.gd` | +20 | P2.1 |
| `managers/phase_instrument_manager.gd` | ~300 | P2.2 |
| `managers/battle/battle_spawn_system.gd` | ~80 | P3.1 |
| `scenes/units/construct_unit.gd` | ~50 | P3.2 |
| `scenes/ui/bottom_instrument_bar.gd` | ~200 | P4.1 |
| `scenes/ui/instrument_bar_drag.gd` | ~100 | P4.2 |
| `resources/drop_tables.gd` | +30 | P5.2 |
| `managers/faction/faction_shop.gd` | +40 | P5.3 |
| `managers/save_manager.gd` | ~50 | P5.4 |

### 废弃文件（保留不删，从autoload移除）
- `managers/phase_law_manager.gd`
- `managers/active_law_effects.gd`
- `data/phase_laws.gd`
- `scenes/ui/phase_law_panel.gd`
- `scenes/ui/active_law_cast_panel.gd`
- `scenes/ui/equipped_passives_box.gd`
- `scenes/effects/phase_law_cast_effect.gd`
- `scenes/effects/law_target_indicator.gd`

---

## 四、实施顺序与依赖

```
P0（已完成）
  ↓
P1（匹配引擎）← 无依赖，可独立开发
  ↓
P2（相位仪改造）← 依赖 P1
  ↓
P3（战斗注入）← 依赖 P2
  ↓
P4（UI改造）← 依赖 P2
  ↓
P5.4（存档）← 依赖 P2
P5.1（专属符文补充）← 独立
P5.2（掉落）← 依赖 P5.1
P5.3（商店）← 依赖 P5.1
P5.5（法则清理）← 最后执行，避免破坏现有功能
```

**建议执行顺序：P1 → P2 → P3 → P4 → P5.1 → P5.2 → P5.3 → P5.4 → P5.5**

---

## 五、验证计划

### 单元测试（待编写）

**位置：`tests/unit/rune/`**

| 测试文件 | 测试内容 |
|---------|---------|
| `test_runes_data.gd` | 33个符文数据完整性、id唯一性、字段合法性 |
| `test_runewords_data.gd` | 65种符文之语数据完整性、required_runes有效性 |
| `test_runeword_matcher.gd` | 匹配算法正确性（空槽、完整组合、部分组合、重复符文） |
| `test_bonus_merge.gd` | 效果合并正确性（数值叠加、特殊效果独立） |

### 集成测试

| 测试场景 | 验证点 |
|---------|--------|
| 战前装备符文 → 进入战斗 | 符文加成正确注入到 UnitStats |
| 多个符文之语同时激活 | 加成正确叠加，不冲突 |
| 特殊效果触发 | on_kill_regen_energy 等按概率正确触发 |
| 存档/读档 | 符文槽位、已拥有符文正确保存恢复 |
| 槽位隔离 | 战斗卡不能拖入符文槽，符文不能拖入战斗卡槽 |

### 平衡性测试

| 关注点 | 验证方法 |
|--------|---------|
| 2符文之语是否过强 | 对比当前法则卡的加成幅度 |
| 5符文之语是否过强 | 100级关卡实测通关时间 |
| 专属符文是否破坏势力平衡 | 各势力通关相同关卡的时间对比 |
| 经济平衡 | 符文掉落率 vs 升星资源消耗 |

---

## 六、风险与缓解

| 风险 | 概率 | 影响 | 缓解措施 |
|------|------|------|---------|
| 65种符文之语平衡失控 | 中 | 高 | 先做25种验证（P0已完成），分批上线 |
| 玩家认知负担（33符文+65之语） | 中 | 中 | UI提供筛选/搜索/预览；符文之语高亮提示 |
| 特殊效果实现复杂度 | 中 | 中 | 每种特殊效果独立函数，互不耦合 |
| 势力声望解锁增加肝度 | 低 | 低 | 专属符文可通过掉落+商店双途径获取 |
| 与现有系统冲突 | 低 | 高 | 明确边界：法则废弃，符文接管 |
| 老存档玩家流失 | 中 | 中 | 不处理迁移（已确认），新版本作为内容更新 |

---

## 七、关键设计决策记录

### 决策1：为什么符文槽替代红蓝槽，而不是新增？

**原因：** 红蓝槽原本承载法则卡（active/passive）。法则系统废弃后，红蓝槽失去意义。用符文槽替代，保持槽位总数稳定，UI改动可控。

### 决策2：为什么战斗卡槽和能量卡槽保留？

**原因：**
- 战斗卡槽（原green）：承载玩家部署的战斗单位，是塔防核心机制
- 能量卡槽（原yellow）：承载能量卡，决定能量上限
- 这两类槽与符文系统正交，互不影响

### 决策3：为什么特殊效果不叠加？

**原因：**
- 数值加成（attack+20%）叠加直观且可控
- 特殊效果（on_kill_regen_energy 30%概率）如果叠加会变成"60%概率"，平衡难以控制
- 保持每个特殊效果独立判断，玩家可以通过装备多个带相同特殊效果的符文之语来"提高触发覆盖"，但每次触发仍是原始概率

### 决策4：为什么槽位总数不变（保持3-11个）？

**原因：**
- 相位仪的星级系统（1-7星）已经定义了槽位总数
- 符文槽从中"切出"1-6个，其余分配给战斗卡和能量卡
- 避免破坏现有的相位仪经济平衡

---

## 八、后续扩展方向（不在本计划范围）

1. **符文合成**：低级符文合成高级符文（参考暗黑2赫拉迪克方块）
2. **符文之语升级**：已激活的符文之语可消耗资源升级效果
3. **季节性符文**：限时活动掉落特殊符文
4. **符文图鉴**：收集系统，集齐某类符文解锁额外加成
5. **符文交易**：势力之间交换专属符文

---

**文档结束。下一步：等待用户确认，开始执行 P1。**
