# 敌方战斗卡情报系统 v21.0 设计计划

> 状态：规划中（未开始修改代码）
> 日期：2026-08-27

---

## 一、目标概述

重构现有情报系统，从"单一标量进度"升级为**双轨制**：
- **base_progress（0~1.0）**：追踪每张敌方卡的总体情报，控制属性可见性 / 低进化触发
- **mod_intel_points（各 mod 独立）**：追踪每张敌方卡专属改造模块的积累点数，按阈值解锁改造

核心玩法变化：
1. 商店购卡 → 直接给 50% base_progress（立即可见属性）
2. 击败敌方卡 → 少量 base + 随机 mod 点数
3. **部署该敌方卡形态** → 稳定积累 base + mod 点数（主要成长手段）
4. base ≥ 50% → 允许低进化（同战力卡进化为该形态）
5. base ≥ 100% → 该卡所有改造全解锁；隐藏进化分支解锁
6. 各 mod 独立阈值 → 达标即自动可用，不再依赖蓝图道具

---

## 二、数据结构变更

### 2.1 `IntelEntry`（`intel_manual.gd`）

```
旧字段（保留兼容）：
  intel_progress: float       → 重命名为 base_progress（迁移时赋值）
  is_unlocked: bool           → 含义不变，条件改为 base_progress >= 1.0

新增字段：
  deploy_count: int           # 部署该敌方卡的次数（主要情报来源）
  defeat_count: int           # 击败次数（保留，用于衰减计算）
  card_mod_intels: Dictionary # archetype_id -> {mod_id: int} 累积点数
  unlocked_mod_ids: Array     # 已解锁的 mod_id 列表（派生缓存）
```

### 2.2 新建文件

| 文件 | 作用 |
|------|------|
| `data/enemy_card_mod_map.gd` | 敌方 archetype → 玩家卡 + 专属改造池映射表 ✅ 已创建 |
| `data/intel_mod_thresholds.gd` | 各稀有度改造解锁点数门槛 ✅ 已创建 |

---

## 三、情报获取规则

### 3.1 来源 & 增量

| 来源 | base_progress | mod 点数 |
|------|--------------|---------|
| 首次遭遇 | +8% | — |
| 击败普通 | +3% × 衰减(×0.8^n, 下限0.5%) | +1 point（随机 common mod） |
| 击败精英 | +5% × 衰减 | +2 points |
| 击败 Boss | +8% × 衰减 | +3 points |
| **部署一次** | +4%（固定，不衰减） | +2~5 points（按 mod rarity） |
| 3星完美胜利 | +2% | — |
| 商店购卡 | **直接 = 50%** | 0 |

### 3.2 新增函数签名

```gdscript
# intel_manual.gd 新增
func register_deploy(archetype_id: String, enemy_type: String = "") -> Dictionary
func set_shop_purchased_base_progress(archetype_id: String, progress: float) -> void
func get_mod_intel_points(archetype_id: String, mod_id: String) -> int
func get_all_mod_intel_points(archetype_id: String) -> Dictionary
func get_unlocked_mod_ids(archetype_id: String) -> Array[String]
func is_mod_unlocked(archetype_id: String, mod_id: String) -> bool
func get_mod_unlock_progress(archetype_id: String, mod_id: String) -> float
```

---

## 四、解锁行为

### 4.1 base_progress 阶梯

| 阈值 | 效果 |
|------|------|
| 0% | 敌方名称/图标迷雾 |
| 25% | 显示敌方名称 + 类型 |
| **50%** | 显示完整 HP/ATK/DEF；**触发低进化** |
| 75% | 显示弱点/抗性提示 |
| **100%** | 该卡所有改造全解锁；隐藏分支解锁 |

### 4.2 改造模块解锁（按点数）

```
每个 mod 的解锁门槛 = IntelModThresholds.get_threshold(mod.rarity)
当 card_mod_intels[mod_id] >= threshold → 自动解锁，加入 unlocked_mod_ids
```

### 4.3 低进化 vs 完整进化

| 类型 | 触发条件 | 结果 |
|------|---------|------|
| 低进化 | base ≥ 50% + 同战力我方卡 | 进化为该敌方卡的普通形态，无特殊改造槽 |
| 完整进化 | base ≥ 100% + 等级门槛 + 改造数量门槛 | 进化为完整形态，可装配全部已解锁改造 |

---

## 五、已创建的文件

### `data/enemy_card_mod_map.gd` ✅

覆盖 unified_card_table 中所有 `enemy_only=true` 的条目：
- 一战：7 条（inf_mp18, inf_rifle, sup_mg_nest, arty_mortar, inf_storm_e, arm_rolls_e, boss_av7）
- 二战：10 条
- 冷战：10 条
- 现代：11 条
- 近未来：10 条
- A段平台卡：8 条（low_evo=false）

每条约 56 条映射，格式：
```gdscript
"archetype_id" = {
    "player_card_id": "对应玩家卡",  # null = Boss/无对应卡
    "mod_pool": [],                  # 空 = 按 combat_kind 全量开放
    "low_evo": true/false,
}
```

### `data/intel_mod_thresholds.gd` ✅

| 稀有度 | 解锁点数 |
|--------|---------|
| common | 5 |
| uncommon | 12 |
| rare | 25 |
| epic | 50 |
| legendary | 80 |
| mythic | 120 |

---

## 六、待修改文件清单

### 核心逻辑层

| 文件 | 改动类型 | 主要内容 |
|------|---------|---------|
| `scripts/systems/intel_manual.gd` | **重写核心** | Entry 结构改双轨；新增 `register_deploy/set_shop_purchased_base_progress/get_mod_*`；旧 `intel_progress` 迁移为 `base_progress` |
| `scripts/systems/intel_discovery_manager.gd` | **修改** | 战斗结算新增 `register_deploy` 调用；蓝图掉落改为 base intel 增益 |
| `managers/instance_registry.gd` | **修改** | `create_instance` 后判断是否商店购卡来源，调 `set_shop_purchased_base_progress(card_id, 0.5)` |

### 进化/查询层

| 文件 | 改动类型 | 主要内容 |
|------|---------|---------|
| `managers/evolution/card_evolution_manager.gd` | **修改** | 新增低进化路径：`base_progress >= 0.5` 时允许进化；旧 100% 路径保留 |
| `scripts/systems/evolution_path_registry.gd` | **小改** | 适配新 intel 查询接口（`get_base_progress` vs `get_intel_progress`） |

### UI 层

| 文件 | 改动类型 | 主要内容 |
|------|---------|---------|
| `scenes/ui/intelligence_hub_panel.gd` | **重写 Tab 3** | 每卡展示 base progress bar + mod 解锁列表（带各 mod 进度条和当前/阈值点数） |
| `scenes/ui/intel_harvest_display.gd` | **修改** | 结算界面显示 base intel 增益 + 各 mod 点数增益条目 |

### 数据层（已有）

| 文件 | 状态 |
|------|------|
| `data/enemy_card_mod_map.gd` | ✅ 已创建 |
| `data/intel_mod_thresholds.gd` | ✅ 已创建 |

---

## 七、废弃与兼容

| 旧系统 | 状态 | 说明 |
|--------|------|------|
| `IntelItemBag`（蓝图道具背包） | 停用 | 改造改为积点自动解锁，道具仍保留但不触发 mod 解锁 |
| `blueprint_*` 改造蓝图掉落 | 简化 | 掉落改为 base intel +2%~5% 增益，不再产出道具 |
| `intel_branch_unlock` 揭示奖励 | 调整 | Tier 4（100% base）自动触发，不再需要单独事件 |
| `intel_manual_items.roll_random_mod_blueprint` | 保留 | 仍可用于掉落通知，但消费方改为 intel 增益 |

### 存档迁移

旧档 `intel_progress` 迁移策略：
```
base_progress = old_intel_progress
deploy_count ≈ defeat_count（近似值，不精确回推）
card_mod_intels = {}（全新开始，玩家需重新积累 mod 点数）
unlocked_mod_ids = []
```

---

## 八、实现顺序建议

1. **Phase 1**：修改 `intel_manual.gd`（Entry 结构 + 新接口）
2. **Phase 2**：修改 `intel_discovery_manager.gd`（战斗结算接入 deploy 统计）
3. **Phase 3**：修改 `instance_registry.gd`（商店购卡 hook）
4. **Phase 4**：修改 `card_evolution_manager.gd`（低进化路径）
5. **Phase 5**：修改 UI（`intelligence_hub_panel` Tab 3 + `intel_harvest_display`）
6. **Phase 6**：测试 + 旧档迁移验证

---

## 九、风险点

1. **`intel_progress` 向后兼容**：多处代码读 `get_intel_progress()`，需保留别名或全局替换
2. **蓝图掉落链路**：`IntelManualItems.roll_random_mod_blueprint` 返回值需适配新消费方
3. **进化检查链**：`UnitLineageConfig` 中 `intel_not_full` 拒绝码需迁移为 `base_progress < 0.5/1.0`
4. **存档体积**：`card_mod_intels` 是 nested Dictionary，旧档迁移时为空即可，不影响读档
