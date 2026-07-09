## 背景

你的诉求"敌方曲射和空射也要有相应弹道效果和攻击选择"——经调研分两层：

- **弹道效果** ✅ 已完整实现（`bullet.gd` 已按武器类型做抛物线/AOE/弧高差异化，`enemy_unit.gd:829` 曲射走 `enemy_indirect_batch`）。**无需改动。**
- **攻击选择（索敌）** ❌ 敌方缺失。`target_selection.gd` 三种选敌逻辑（直射最近/曲射打克制/空射打空中）早已写好，我方 `construct_unit_ai.gd:120` 已接入，但**敌方 `enemy_unit.gd._find_target()` 从不调用它**，只找最近目标——导致火箭筒不优先打装甲、防空不优先打空中。`enemy_unit.gd:15` 甚至已 `preload TargetSelection` 却没用上（开发者当初有意图，没接完）。

本次只修**索敌层**。

## 改动方案（3 个文件）

### 1. `resources/game_constants.gd` — 新增统一映射函数（DRY）

在 `is_indirect_weapon_type()` 旁新增静态函数，集中 legacy→新枚举映射逻辑：

```gdscript
## legacy 12 值武器类型 → 新 4 值 WeaponType 映射（敌方 archetype 配的是 legacy 值）
## 空中平台(tags aircraft/air)→AERIAL；曲射类(ROCKET=3/FLAK=7/MISSILE=9/RAIL=11)→INDIRECT；其余→DIRECT
static func legacy_weapon_to_new_weapon_type(legacy_wt: int, is_aircraft: bool = false) -> int:
    if is_aircraft:
        return int(WeaponType.AERIAL)
    if legacy_wt == 3 or legacy_wt == 7 or legacy_wt == 9 or legacy_wt == 11:
        return int(WeaponType.INDIRECT)
    return int(WeaponType.DIRECT)
```

### 2. `scenes/units/enemy_unit.gd` — `_find_target()` 接入差异化索敌（核心）

改造 `_find_target()`（L669-714），分流两条路径：

- **直射单位**（`!GC.is_indirect_weapon_type(wt)`）：保持现有 `spatial_grid.query_nearest_target` 最近目标路径**完全不变**（O(1) 性能最优，且 `select_target_direct` 结果与之等价，零风险零行为变化）。
- **曲射/空射单位**（`GC.is_indirect_weapon_type(wt)`）：新增候选收集 → `TargetSelection.select_target()` 差异化选敌路径：
  1. 收集射程内（`_enemy_acquisition_range()`）的我方候选单位（复用现有 `player_units` 组遍历 + `CombatTargeting.is_attackable_combat_unit` 过滤，与我方 `construct_unit_ai` 同路径）
  2. `mapped_wt = GC.legacy_weapon_to_new_weapon_type(wt, _is_aircraft_unit())` 映射
  3. `target = TargetSelection.select_target(self, candidates, mapped_wt)` —— 迫击炮打克制、防空打空中、导弹按克制
  4. 候选为空时回退攻击相位场（保留现有 `found_alive` 逻辑）

新增两个私有辅助：
- `_collect_player_candidates(acq) -> Array`：收集射程内可攻击的我方单位（候选数组）
- `_is_aircraft_unit() -> bool`：判定空中单位（`_cached_archetype_cfg.tags` 含 aircraft/air，或 `stats.combat_kind == AIR`）

`wt` 的取值复用现有缓存链（`_cached_weapon_type` / `stats.weapon_type` / `cfg.weapon_type`），与 `_do_attack()` 的 wt 取值口径一致。

### 3. `scenes/units/enemy_phase_field_driver.gd` — 去重映射逻辑

`_legacy_weapon_to_new_weapon_type`（L690-697）改为调用 `GC.legacy_weapon_to_new_weapon_type()`，删除重复的本地映射体，保证全项目只有一处映射真身（避免两份逻辑日后不一致）。

## 不做的事

- ❌ 不改 `target_selection.gd`（三种逻辑已完整正确）
- ❌ 不改 `bullet.gd` / `simple_indirect_projectile_batch.gd`（弹道渲染已完整）
- ❌ 不加空中单位 Y 偏移悬浮视觉（你已确认保持现状）
- ❌ 不动 `_do_attack()` 开火链路（曲射/空射弹道已通过 `is_indirect_weapon_type` 正确走 batch）

## 设计决策

1. **直射保持 spatial_grid，曲射/空射走候选收集**——与 `construct_unit_ai` 分流模式一致（我方也是直射优先 spatial_grid、曲射走 card_grid/候选）。`select_target_direct` 与 spatial_grid 最近结果等价，强制直射绕路候选遍历只损失性能无行为收益。
2. **映射函数集中到 GameConstants**——敌方标准敌兵和相位师产兵两条路径共用一处真身，避免 v6.6 双映射漂移的老问题重演。
3. **is_aircraft 参数化**——映射是否归 AERIAL 由调用方传（敌兵查 tags，相位师产兵查平台/来源），映射函数本身不耦合 cfg 结构。

## 验证策略

- Godot `--check-only`（项目体量大可能 5min 超时，属既有现象，重点看是否构建到 133 卡无语法错误）
- Grep 静态核对：`TargetSelection.select_target` 在 `enemy_unit.gd` 新调用链完整、`legacy_weapon_to_new_weapon_type` 两处调用方一致、`_collect_player_candidates`/`_is_aircraft_unit` 定义调用配对
- 独立 load 编译 `enemy_unit.gd` 确认无语法错误
- 运行时索敌行为（迫击炮打克制/防空打空中）需游戏内实机验证