# 进化系统兼容方案：替换星级/研究点/许可证门槛

## 当前问题

删除升星、研究点、许可证后，进化系统 `card_evolution_manager.gd` 的 `can_evolve_blueprint()` 有5个硬依赖：

| 行号 | 旧门槛 | 用途 |
|------|-------|------|
| L113 | `get_blueprint_star() < min_star` | E1需4★，E2需7★ |
| L116 | `get_modification_count() < 3` | 至少装3个MOD |
| L119-121 | `get_research_points() < cost` | E1消耗320，E2消耗680研究点 |
| L125-131 | `permit_general < 1` | 通用许可证×1 |
| L132-134 | `permit_category < 1` / `permit_specific < 1` | 分类/专属许可证 |

另外 `evolution_helpers.gd` 的战力公式也依赖星级。

## 新门槛设计

### 核心理念

进化门槛 = **改造深度证明** + **战力达标** + **情报满**

不再用"星级"和"研究点"这种抽象数值，改为要求玩家实际投入改造资源：
- 装了几个MOD → 证明你确实在培养这张卡
- 战力够不够 → 证明你培养得够好
- 情报满 → 证明你了解目标

### 替换方案

| 旧门槛 | 新门槛 | 理由 |
|--------|--------|------|
| E1需4★（基础战力600+） | 强化Lv5 + 已装2个MOD | Lv5 = 中等培养投入，2个MOD = 实际改造参与 |
| E2需7★（基础战力2200+） | 强化Lv8 + 已装5个MOD + 1个敌源MOD | 深度培养 + 大量改造 + 敌方科技融合 |
| 至少3次改造 | 合并到上面的MOD计数中 | 不再单独检查 |
| 研究点320/680 | 删除 | 简化 |
| 许可证通用×1+分类×1 | 删除 | 简化 |
| 专属许可证×1（E2） | 删除 | 简化 |
| 战力达标 | **保留不变** | 这本来就是好门槛 |
| 情报100% | **保留不变** | 好门槛 |
| 不跨类型 | **保留不变** | 好门槛 |

### 新常量定义（unit_lineage_config.gd 替换）

```
# 旧常量（删除）
E1_MIN_STAR = 4
E2_MIN_STAR = 7
REQUIRED_MOD_COUNT = 3
EVOLVE_COSTS = { research, permit_* }

# 新常量
E1_MIN_ENHANCE_LEVEL = 5       # E1进化：强化至少Lv5
E1_MIN_MOD_COUNT = 2            # E1进化：至少装2个MOD
E2_MIN_ENHANCE_LEVEL = 8        # E2进化：强化至少Lv8
E2_MIN_MOD_COUNT = 5             # E2进化：至少装5个MOD
E2_REQUIRE_ENEMY_ORIGIN_MOD = true  # E2进化：必须有1个敌源MOD
```

### 势力分支 vs 基础进化

当前系统用 `get_stage()` 判断是 e1（基础进化）还是 e2（势力分支），e2要求更高（7★）。

新方案保持同样的区分：
- **基础进化 (evolution_1)**: 强化Lv5 + 2个MOD
- **势力分支 (faction_branches)**: 强化Lv8 + 5个MOD + 1个敌源MOD（因为势力分支是更高阶的选择）

### 情报进化分支（v6.0 IntelEvolutionBranches）

**完全不受影响**。情报进化有自己的入口条件（`intel_requirements`），不依赖星级/研究点/许可证。

## 代码改动清单

### 1. `unit_lineage_config.gd`

```
删除: E1_MIN_STAR, E2_MIN_STAR, REQUIRED_MOD_COUNT, EVOLVE_COSTS, get_min_star_for_stage(), get_costs_for_stage()
新增: E1_MIN_ENHANCE_LEVEL, E1_MIN_MOD_COUNT, E2_MIN_ENHANCE_LEVEL, E2_MIN_MOD_COUNT, E2_REQUIRE_ENEMY_ORIGIN_MOD
修改: get_stage() 保持不变（e1/e2区分逻辑不变）
新增: get_enhance_requirement(stage) -> int
新增: get_mod_requirement(stage) -> int
新增: get_enemy_mod_required(stage) -> bool
```

### 2. `card_evolution_manager.gd` — `can_evolve_blueprint()`

```
L113-115: 删除星级检查
→ 替换: 检查强化等级和MOD数量

L116-117: 删除单独的改造计数检查（已合并）

L118-135: 删除研究点+许可证检查
→ 新检查逻辑:
  var stage = UnitLineageConfig.get_stage(card_id, target_card_id)
  var enhance_lvl = bpm_ref.get_blueprint_enhance_level(card_id)
  var mod_count = ModManager.get_modification_count(card_id, bpm_ref.blueprint_mods)
  var has_enemy_mod = ModManager.has_enemy_origin_mod(card_id, bpm_ref.blueprint_mods)

  if stage == "e1":
    if enhance_lvl < E1_MIN_ENHANCE_LEVEL: return denied("enhance_not_enough")
    if mod_count < E1_MIN_MOD_COUNT: return denied("mod_not_enough")
  else:  # "e2"
    if enhance_lvl < E2_MIN_ENHANCE_LEVEL: return denied("enhance_not_enough")
    if mod_count < E2_MIN_MOD_COUNT: return denied("mod_not_enough")
    if has_enemy_mod == false: return denied("enemy_mod_not_enough")
```

### 3. `card_evolution_manager.gd` — `evolve_blueprint()`

```
L157-158: 删除 research_points 扣除
L159-169: 删除许可证扣除
L170: 删除 old_star 读取（但保留 blueprint_stars 的 max 继承以防其他地方引用）

新执行逻辑更简单：只检查条件 → 继承mods → 重置强化 → 完成
```

### 4. `evolution_helpers.gd` — 战力公式

```
L38-45: get_effective_power_multiplier()
  旧: rarity_mul * star_stat_multiplier(star, rarity)
  新: rarity_mul * enhance_stat_multiplier(enhance_level, rarity)
  → 需要新增 enhance_stat_multiplier() 函数

L144-148: estimate_power_score_meta_only()
  旧: (80 + star*28 + mod_count*22) * rarity * (1+inherit)
  新: (80 + enhance_level*28 + mod_count*22) * rarity * (1+inherit)

L78-99: _apply_platform_star_growth_bias()
  旧: tiers = max(0, star-1)
  新: tiers = enhance_level (直接用强化等级)
```

### 5. `mod_manager.gd`

新增函数：
```
static func has_enemy_origin_mod(card_id: String, mods_dict: Dictionary) -> bool
  → 遍历该卡的mods列表，检查是否有EOM_前缀的MOD
```

### 6. `EVOLVE_REASON_ZH` 更新

```
删除: "star_not_enough", "research_not_enough",
      "permit_general_not_enough", "permit_category_not_enough", "permit_specific_not_enough"
新增: "enhance_not_enough": "强化等级不足（基础进化需Lv5，势力分支需Lv8）",
      "enemy_mod_not_enough": "未安装敌源改造模块（势力分支进化要求）"
```

### 7. 存档兼容

进化门槛全部是运行时检查（不存档），所以**无需 SAVE_VERSION 变更**。

但进化执行时的扣除逻辑变化：
- 旧存档可能存有 research_points 和 permit_* 的消耗记录 → 这些字段被删除后不影响，只是不再变化
- blueprint_stars 字段保留（虽然不再作为门槛，但其他地方可能引用）

## 兼容性总结

| 系统 | 影响 | 改动量 |
|------|------|--------|
| 强化Lv1-10 | 无 | 0 |
| MOD改造门槛（情报书） | 无 | 0 |
| 势力改造 | 无 | 0 |
| 敌源改造 | 无 | 0 |
| 情报进化(v6.0) | 无 | 0 |
| **进化门槛检查** | 重写 | ~50行 |
| **进化执行** | 删除消耗逻辑 | ~15行 |
| **战力公式** | star→enhance_level 替换 | ~20行 |
| **进化常量** | 替换 | ~15行 |
| **存档** | 无需改动 | 0 |

总改动约 **100行**，集中在 3个文件。

## 与情报书改造系统的关系

两个系统完全正交：

```
情报书改造（MOD安装）          进化系统
    │                            │
    ├─ 战力提升 ──────────────→  ├─ 战力达标检查（需要）
    ├─ MOD计数增加 ───────────→  ├─ MOD数量检查（需要）
    └─ 敌源MOD安装 ──────────→  └─ 敌源MOD检查（E2需要）
```

情报书改造为进化提供"门槛原料"（MOD数量、敌源MOD），进化在条件满足后执行。两者不互相消耗，只是进化要求玩家先通过改造系统投入足够资源。

这就是设计意图：**改造是日常投入，进化是阶段性成果。**
