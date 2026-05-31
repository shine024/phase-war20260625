# 简化卡片养成系统 & 重写进化门槛

## Goal

删除升星(★)、研究点、许可证三个抽象系统，用"情报书掉落 + 战力阈值"驱动MOD安装，用"强化等级 + MOD数量 + 敌源MOD"作为进化新门槛。保留强化Lv1-10、20种MOD改造、7势力×10级势力改造、9种敌源改造、9条进化路线。

## Current Context

- 项目路径: `D:/godotplay/godot fair duel/phase-war/`
- search_files 不可用，须用 `powershell.exe -Command` 查找
- 已有设计文档:
  - `docs/card_progression_data_sheet.md` — 旧系统完整数据
  - `docs/card_modification_system_v2_design.md` — 情报书+战力阈值方案
  - `docs/evolution_gate_compatibility.md` — 进化门槛替换方案

### 旧系统关键常量（要删除的）

| 文件 | 常量/函数 | 说明 |
|------|----------|------|
| `unit_lineage_config.gd` | `E1_MIN_STAR=4`, `E2_MIN_STAR=7` | 进化星级门槛 |
| `unit_lineage_config.gd` | `REQUIRED_MOD_COUNT=3` | 进化改造次数门槛 |
| `unit_lineage_config.gd` | `EVOLVE_COSTS{research, permit_*}` | 进化消耗 |
| `unit_lineage_config.gd` | `get_min_star_for_stage()`, `get_costs_for_stage()` | 返回以上值 |
| `blueprint_star_config.gd` | 全文件 | 星级配置 |
| `card_progression_settings.gd` | 研究点乘数 | 研究点系统 |

### 新门槛设计

| 阶段 | 条件 |
|------|------|
| 基础进化(E1) | 强化Lv5 + 2个MOD + 战力≥目标 + 情报100% |
| 势力分支(E2) | 强化Lv8 + 5个MOD + 1个敌源MOD + 战力≥目标 + 情报100% |

## Approach: 4 Phase 分步实施

### Phase 1: 数据层 — 新常量 & 敌源MOD查询函数

**修改文件:**
- `data/unit_lineage_config.gd`
- `managers/evolution/mod_manager.gd`

**改动:**

`unit_lineage_config.gd`:
```
删除常量: E1_MIN_STAR, E2_MIN_STAR, REQUIRED_MOD_COUNT, EVOLVE_COSTS
新增常量:
  E1_MIN_ENHANCE_LEVEL = 5
  E1_MIN_MOD_COUNT = 2
  E2_MIN_ENHANCE_LEVEL = 8
  E2_MIN_MOD_COUNT = 5
  E2_REQUIRE_ENEMY_ORIGIN_MOD = true

删除函数: get_min_star_for_stage(), get_costs_for_stage()
新增函数:
  get_enhance_requirement(stage: String) -> int
  get_mod_requirement(stage: String) -> int
  get_enemy_mod_required(stage: String) -> bool

更新 EVOLVE_REASON_ZH:
  删除: star_not_enough, research_not_enough, permit_*_not_enough
  新增: enhance_not_enough, enemy_mod_not_enough
```

`mod_manager.gd`:
```
新增函数:
  static func has_enemy_origin_mod(card_id: String, mods_dict: Dictionary) -> bool
    → 遍历 mods_dict[card_id] 数组，检查元素是否以 "EOM_" 开头
```

**验证:** 无（纯数据层，不影响运行）

---

### Phase 2: 进化门槛重写

**修改文件:**
- `managers/evolution/card_evolution_manager.gd`

**改动 — `can_evolve_blueprint()`:**

删除 L113-135 的6个旧检查（星级、改造次数、研究点、3种许可证）。

替换为:
```
var stage: String = UnitLineageConfig.get_stage(card_id, target_card_id)
var enhance_lvl: int = bpm_ref.get_blueprint_enhance_level(card_id)
var mod_count: int = ModManager.get_modification_count(card_id, bpm_ref.blueprint_mods)
var has_eom: bool = ModManager.has_enemy_origin_mod(card_id, bpm_ref.blueprint_mods)

if enhance_lvl < UnitLineageConfig.get_enhance_requirement(stage):
    return _evolve_check_denied("enhance_not_enough")
if mod_count < UnitLineageConfig.get_mod_requirement(stage):
    return _evolve_check_denied("mod_not_enough")
if UnitLineageConfig.get_enemy_mod_required(stage) and not has_eom:
    return _evolve_check_denied("enemy_mod_not_enough")
```

注意: 检查 `bpm_ref` 是否已有 `get_blueprint_enhance_level()` 方法。如果没有，需在 BlueprintManager 中新增（或使用 `blueprint_enhance_level` 字典直接读取）。

**改动 — `evolve_blueprint()`:**

删除 L157-158 研究点扣除、L159-169 许可证扣除。

保留:
- L170: old_star 读取（保留 blueprint_stars 字段兼容）
- L174-178: unlock + copies + stars + inherit_bonus 继承
- L179-183: HP floor 计算
- L190-192: MOD继承（源复制到目标，源清空）
- L198-199: signal 发射

简化后的执行流程: 条件检查通过 → unlock目标 → 继承mods(复制+清空) → 继承stars(max) → 继承inherit_bonus → 计算HP floor → emit signals → return true

**验证:** 进化面板中显示正确的"需要X"条件，旧条件不再出现。

---

### Phase 3: 战力公式替换 star → enhance_level

**修改文件:**
- `managers/evolution/evolution_helpers.gd`
- `managers/card_enhancement_manager.gd`（可能需要新增 `enhance_stat_multiplier`）

**改动:**

`evolution_helpers.gd`:

1. `get_effective_power_multiplier()` (L38-45):
   ```
   旧: star = bpm_ref.blueprint_stars[card_id]
       return rarity_mul * BattleCardV3.star_stat_multiplier(star, rarity)
   新: enhance = bpm_ref.get_blueprint_enhance_level(card_id)
       return rarity_mul * enhance_stat_multiplier(enhance, rarity)
   ```

2. `estimate_power_score_meta_only()` (L144-148):
   ```
   旧: (80 + star*28 + mod_count*22) * rarity * (1+inherit)
   新: (80 + enhance*28 + mod_count*22) * rarity * (1+inherit)
   ```

3. `_apply_platform_star_growth_bias()` (L78-99):
   ```
   旧: var star = bpm_ref.blueprint_stars[card_id]
       var tiers = max(0, star - 1)
   新: var enhance = bpm_ref.get_blueprint_enhance_level(card_id)
       var tiers = enhance  # 直接用强化等级，Lv0=0倍，Lv10=10倍
   ```
   注意: bias 系数（hp_bias=0.04, dmg_bias=0.04）是每星的乘数。如果 enhance=10 而 star=9 时 tiers=8 vs tiers=10，成长会更快。需要确认 bias 系数是否需要调整。**暂不调整**，先用 enhance_level 直接替换，后续数值平衡时再微调。

4. 新增函数 `enhance_stat_multiplier(enhance_level: int, rarity: String) -> float`:
   ```
   # 旧 BattleCardV3.star_stat_multiplier(star, rarity) 的等价替代
   # 需要查看 BattleCardV3 中该函数的实现来映射
   # 如果 BattleCardV3.star_stat_multiplier(star=4, rarity) 约等于 enhance_level=5 的效果
   # 则: enhance_stat_multiplier(e, r) = 1.0 + e * 0.06（粗略）
   ```
   → 必须先读 `BattleCardV3.star_stat_multiplier()` 的实现，然后写等价映射。

**验证:** 战力估算值合理（不出现0或无穷大），军衔系统正常显示。

---

### Phase 4: 清理 & 兼容

**修改文件:**
- `data/blueprint_star_config.gd` — 删除或标记废弃
- `data/card_progression_settings.gd` — 删除研究点乘数
- 任何引用 `get_blueprint_star()` 做门槛检查的地方（不含军衔/战力估算，那些在Phase 3已处理）

**清理项:**
1. `blueprint_star_config.gd` — 不再作为进化门槛使用。暂时保留文件但标记为 deprecated（其他系统如UI可能在读）。搜索所有引用确认安全后再删除。
2. `card_progression_settings.gd` 中的研究点乘数 — 删除相关常量。
3. 搜索全局 `research_points`, `permit_general`, `permit_category`, `permit_specific` 引用，确认无残留。
4. 搜索全局 `E1_MIN_STAR`, `E2_MIN_STAR`, `REQUIRED_MOD_COUNT` 引用。

**存档兼容:** 无需 SAVE_VERSION 变更。所有门槛都是运行时检查。

**验证:** 引擎启动无报错，项目无 unused 变量 warning。

---

## Files Likely to Change (Complete List)

| 文件 | Phase | 改动类型 | 改动量 |
|------|-------|---------|--------|
| `data/unit_lineage_config.gd` | 1 | 替换常量+函数 | ~25行 |
| `managers/evolution/mod_manager.gd` | 1 | 新增1个函数 | ~8行 |
| `managers/evolution/card_evolution_manager.gd` | 2 | 重写门槛+执行 | ~50行 |
| `managers/evolution/evolution_helpers.gd` | 3 | star→enhance替换 | ~25行 |
| `data/blueprint_star_config.gd` | 4 | deprecated标记 | ~5行 |
| `data/card_progression_settings.gd` | 4 | 删除研究点常量 | ~10行 |

**不改动:**
- `data/mod_effects.gd` — MOD定义不变
- `data/faction_card_bonuses.gd` — 势力改造不变
- `data/enemy_origin_mods.gd` — 敌源改造不变
- `managers/faction/faction_card_generator.gd` — 势力变体生成不变
- `data/intel_evolution_branches.gd` — 情报进化不变
- `managers/card_enhancement_manager.gd` — 强化系统不变（除非需要新增 enhance_stat_multiplier）

## Risks & Tradeoffs

1. **BattleCardV3.star_stat_multiplier 映射**: 必须查看实现。如果它用非线性映射（如指数衰减），简单的线性 enhance 替代会导致战力曲线失真。
2. **bias 系数**: `_apply_platform_star_growth_bias` 中 tiers 从 (star-1) 变为 enhance_level，Lv10=10倍 vs 旧Lv9=8倍，后期成长会快25%。后续需要数值平衡。
3. **蓝图星级字段保留**: `blueprint_stars` 字典保留但不更新。如果UI上显示星级会永远停在旧值。需要确认UI是否有星级显示需要改为显示强化等级。
4. **势力分支进化门槛偏重**: 要求5个MOD + 1个敌源MOD可能偏难（总共只有20个MOD位，9个槽位限制）。如果玩家觉得E2太难，后续可降低。
5. **permit_* 资源系统**: 删除许可证后，BasicResources 中 permit_* 资源定义需要检查是否还有其他引用。如果只是进化在用，可以一并清理。

## Open Questions

1. BlueprintManager 是否已有 `get_blueprint_enhance_level()` 方法？还是需要新增？（需要读 BlueprintManager 代码确认）
2. `BattleCardV3.star_stat_multiplier()` 的具体实现是什么？需要映射到 enhance 等价函数
3. UI上是否有星级显示？如果有，改为显示强化等级还是直接隐藏？
4. 删除许可证后 `BasicResources` 中的 permit 定义是否清理？
