# ADR-0014: Unit System v3 Migration — 100-Unit Complete Replacement

## Status

Proposed

## Date

2026-05-28

## Last Verified

2026-05-28

## Decision Makers

Project lead

## Summary

Replace the current 29-card `platform_*` system with a complete 100-unit system organized by 5 eras (WW1, WW2, Cold War, Modern, Near-Future). Each unit will have 13 complete attributes including the new `power` field (evolution prerequisite), `weapon_type` (DIRECT/INDIRECT/AERIAL), and multi-dimensional attack/defense values. The old star upgrade system will be replaced by an evolution system where units transform into higher-tier units of the same class.

## Engine Compatibility

| Field | Value |
|-------|-------|
| **Engine** | Godot 4.5 |
| **Domain** | Data / Combat / Progression |
| **Knowledge Risk** | LOW — Uses existing Resource and RefCounted patterns |
| **References Consulted** | `docs/engine-reference/godot/VERSION.md` |
| **Post-Cutoff APIs Used** | None |
| **Verification Required** | None |

## ADR Dependencies

| Field | Value |
|-------|-------|
| **Depends On** | ADR-0003 (Data Layer Design), ADR-0007 (Phase Master Battle Mode) |
| **Enables** | Future ADR: Evolution System, Intelligence Manual, Multi-Dimensional Combat |
| **Blocks** | None — This is an optional enhancement |
| **Ordering Note** | Should be completed before implementing evolution/intelligence systems |

## Context

### Problem Statement

The current `platform_*` card system has only 29 units with incomplete attribute coverage:
- Missing `power` field (evolution prerequisite)
- Missing `weapon_type` (DIRECT/INDIRECT/AERIAL targeting logic)
- Single-dimensional attack/defense (cannot express cross-type advantages)
- Star upgrade system (1-9★) overlaps with evolution mechanics
- Era progression is implicit, not explicit

Meanwhile, design documents specify a complete 100-unit system with:
- 5 distinct eras (WW1 → WW2 → Cold War → Modern → Near-Future)
- 20 units per era (5 types × 4 classes)
- 13 complete attributes per unit
- Evolution trees within each unit class
- Intelligence manual progression system

### Current State

**Existing Data Structure** (`data/default_cards.gd`):
- 29 cards using `platform_hound`, `platform_guard`, `platform_titan` IDs
- `combat_kind` field: 0=LIGHT, 1=ARMOR, 2=SUPPORT, 3=AIR
- `weapon_type` field: exists but not used in combat logic
- `star_level` field: 0-9, provides attribute multipliers
- Base attributes: `base_damage`, `base_defense`, `base_hp`, `deploy_speed`, `range`

**Design Document Specification** (`docs/100基础单位的完整数据结构.md`):
- 100 units with `ww1_*`, `ww2_*`, `cold_*`, `mod_*`, `fut_*` prefixes
- Era progression encoded in ID prefix (0-4)
- `power` field: base power level for evolution prerequisite
- Multi-dimensional attack: `attack_light`, `attack_armor`, `attack_air`
- Multi-dimensional defense: `defense_light`, `defense_armor`, `defense_air`

### Constraints

| Constraint | Impact |
|------------|--------|
| **Save Compatibility** | Existing saves use `platform_*` IDs — migration path required |
| **Asset Pipeline** | Card icons and unit sprites assume 29 units — 100-unit art needed |
| **Performance** | 100 units × 13 attributes = static data increase ~4× |
| **UI Display** | Unit info panel shows 3 attack/defense values (not 1) |
| **Code Impact** | 25 files reference `platform_*`, 13 reference `combat_kind`, 12 reference star upgrades |

### Requirements

1. **Data Migration Path**: All 29 existing `platform_*` units must map to new 100-unit IDs
2. **Evolution Prerequisite**: New `power` field enables "power ≥ target base power to evolve" logic
3. **Weapon Type Logic**: Three targeting modes (DIRECT/INDIRECT/AERIAL) with distinct selection rules
4. **Multi-Dimensional Combat**: Attack/defense values vary by target/attacker type
5. **Era Progression**: Units organized by era, enabling era-locked content or bonuses
6. **Backward Compatibility**: Old saves must not crash (can default to era-0 equivalents)

## Decision

### Option A: Complete Replacement (Selected)

**Replace the entire `platform_*` system with the new 100-unit system.**

- **All 29 existing cards**: Remapped to new era-based IDs
- **Star upgrade system**: Removed entirely (replaced by evolution)
- **combat_kind field**: Expanded from 3 values to 4 (LIGHT/ARMOR/SUPPORT/AIR)
- **Attack/defense**: Changed from single values to three-dimensional arrays

### Option B: Hybrid Parallel (Rejected)

Run both systems in parallel, gradually migrating players.

- **Rejected reason**: Doubles data maintenance burden, confuses players with two unit types

### Option C: Incremental Addition (Rejected)

Add new era-based units alongside existing ones.

- **Rejected reason**: Doesn't solve the core problem (missing multi-dimensional attributes, no evolution prerequisites)

## Consequences

### Positive

| Benefit | Description |
|---------|-------------|
| **Complete Design Fidelity** | Game data matches design document specification |
| **Evolution System Enabled** | `power` field provides clear prerequisite for tier-to-tier evolution |
| **Strategic Depth** | Multi-dimensional attack/defense creates meaningful counter-picking |
| **Era Progression** | Clear visual/mechanic progression from WW1 to Near-Future |
| **Simplified Progression** | Removes star system complexity (replaced by intuitive evolution) |
| **Future-Proof** | 100-unit framework supports expansion units |

### Negative

| Drawback | Mitigation |
|----------|------------|
| **Art Asset Overhead** | Need 100 card icons + 100 unit sprites | — Phase 1: Reuse existing 29, use color-coded placeholders for 71 new |
| **Save Migration Required** | Old saves reference deleted `platform_*` IDs | — Provide ID remapping table in `data/save_migration_config.gd` |
| **Code Refactoring** | 25 files need `platform_*` → new ID updates | — Use IDE refactoring + grep search to catch all references |
| **Balance Testing Burden** | 100 units × 4 matchups = 400 damage interactions | — Create automated test matrix in `tests/unit/combat/test_multi_dim_damage.gd` |

### Neutral

| Change | Impact |
|--------|--------|
| **Data Structure** | `CardResource` gains 6 fields, loses 2 fields (net +4) |
| **Memory Footprint** | Static data increases from ~29 cards to ~100 cards (~+4×) |
| **UI Changes** | Unit info panel shows 9 attribute boxes (was 2) |
| **Enum Changes** | `PlatformType` → `EraType`, `CombatKind` expands to 4 values |

## Architecture

### New ID Namespace

```
Old: platform_hound, platform_guard, platform_titan, ...
New: ww1_mp18, ww2_thompson, cold_ak47, mod_marine, fut_cyborg, ...
```

**Remapping Table** (partial):

| Old ID | New ID | Era | Rationale |
|--------|--------|-----|-----------|
| `platform_hound` | `ww2_thompson` | 1 | WW2 SMG unit |
| `platform_guard` | `cold_ak47` | 2 | Cold War assault rifle unit |
| `platform_titan` | `mod_m1a2` | 3 | Modern heavy tank |
| `platform_fortress` | `fut_heavy_mech` | 4 | Near-future heavy mech |

**Complete remapping table**: See `data/unit_id_migration_config.gd` (to be created).

### New Data Structure

```gdscript
# CardResource (战斗卡专用字段扩展)
{
    # === 新增字段 ===
    "weapon_type": 0,              # 0=DIRECT, 1=INDIRECT, 2=AERIAL
    "power": 0,                    # 战力（进化门槛）
    
    # === 多维攻击（替换 base_damage）===
    "attack_light": 0,             # 对轻装伤害
    "attack_armor": 0,             # 对装甲伤害
    "attack_air": 0,               # 对空中伤害
    
    # === 多维防御（替换 base_defense）===
    "defense_light": 0,            # 防轻装武器伤害减免
    "defense_armor": 0,            # 防装甲武器伤害减免
    "defense_air": 0,              # 防空武器伤害减免
    
    # === 保留字段 ===
    "card_id": "唯一标识",
    "display_name": "显示名称",
    "era": 0,                      # 0=WW1, 1=WW2, 2=Cold, 3=Modern, 4=Future
    "combat_kind": 0,              # 0=LIGHT, 1=ARMOR, 2=SUPPORT, 3=AIR
    "base_hp": 0,
    "deploy_speed": 0,
    "range": 3,
    "energy_cost": 10,
    
    # === 删除字段 ===
    # "base_damage": 0,            # 被 attack_light/armor/air 替代
    # "base_defense": 0,           # 被 defense_light/armor/air 替代
    # "star_level": 0,             # 被进化系统替代
}
```

### New Enum

```gdscript
# resources/game_constants.gd
enum WeaponType {
    DIRECT = 0,      # 直射：坦克炮、步枪、机枪，攻击最近敌人，有射程衰减
    INDIRECT = 1,    # 曲射：迫击炮、火炮，全图攻击被克制类型，无衰减
    AERIAL = 2       # 空射：战斗机、无人机，全图攻击，可被防空拦截
}
```

### Updated Enum

```gdscript
# resources/game_constants.gd
enum CombatKind {
    LIGHT = 0,       # 轻装（步兵、侦察车）
    ARMOR = 1,       # 装甲（坦克、机甲）
    SUPPORT = 2,     # 支援（火炮、防空）
    AIR = 3          # 空中（战斗机、攻击机、无人机）
}
```

## Implementation Plan

### Phase 1: Data Foundation (2-3 days)

**Goal**: Create new 100-unit data without breaking existing game

| Step | File | Action |
|------|------|--------|
| 1.1 | `data/default_cards_v4.gd` | Create new file with all 100 units |
| 1.2 | `resources/game_constants.gd` | Add `WeaponType` enum, update `CombatKind` to 4 values |
| 1.3 | `resources/card_resource.gd` | Add 6 new fields, comment out 2 old fields |
| 1.4 | `data/unit_id_migration_config.gd` | Create old→new ID remapping table |
| 1.5 | `data/battle_card_v3.gd` | Update era scaling to use `power` instead of computed sum |

### Phase 2: Core System Adaptation (3-4 days)

**Goal**: Update all systems that reference unit data

| Step | File | Action |
|------|------|--------|
| 2.1 | `resources/unit_stats_table.gd` | Update `build_stats_from_card()` to use multi-dim values |
| 2.2 | `resources/unit_stats.gd` | Sync field changes with CardResource |
| 2.3 | `data/enemy_unit_manifest.gd` | Replace 100 slots with new IDs (A/B/C/D sections) |
| 2.4 | `data/unit_lineage_config.gd` | Update 90× `platform_` references to new IDs |
| 2.5 | `managers/blueprint_manager.gd` | Update `get_card_by_id()` to handle both old/new IDs (compat layer) |

### Phase 3: Combat System Integration (4-5 days)

**Goal**: Implement weapon type targeting and multi-dimensional damage

| Step | File | Action |
|------|------|--------|
| 3.1 | `scripts/battle/target_selection.gd` | Create new file with DIRECT/INDIRECT/AERIAL logic |
| 3.2 | `scripts/battle/damage_attenuation.gd` | Create new file with range attenuation calculation |
| 3.3 | `managers/battle/battle_damage_system.gd` | Update to use `attack_X` vs `defense_X` |
| 3.4 | `scripts/battle/battle_manager.gd` | Integrate target selection and attenuation |

### Phase 4: Save Migration & Testing (2-3 days)

**Goal**: Ensure old saves don't crash

| Step | File | Action |
|------|------|--------|
| 4.1 | `data/save_migration_config.gd` | Create migration script for old saves |
| 4.2 | `managers/save_manager.gd` | Add version check + one-time migration |
| 4.3 | `tests/unit/data/test_unit_id_migration.gd` | Verify all 29 old IDs map correctly |
| 4.4 | `tests/integration/test_save_migration.gd` | Test loading old save files |

**Total Estimated Time**: 11-15 days

## Risk Assessment

| Risk | Probability | Impact | Mitigation |
|------|-------------|--------|------------|
| **Save Data Loss** | Medium | High | — Provide migration script + backup before upgrade |
| **UI Overload** | High | Medium | — Use tabs/scroll for 9 attribute boxes, show only relevant ones |
| **Balance Crisis** | High | High | — Run automated test matrix before release |
| **Asset Shortage** | High | Low | — Phase 1 uses placeholders, Phase 2 commissions art |
| **Code Refactor Bugs** | Medium | Medium | — Grep for all `platform_` + GC.PlatformType references |

## Verification

**Pre-Commit Checklist**:

- [ ] All 100 units defined in `data/default_cards_v4.gd`
- [ ] All 29 old IDs have mapping in `data/unit_id_migration_config.gd`
- [ ] `weapon_type` field present on all combat cards
- [ ] `attack_light/armor/air` all non-zero (or explicitly 0 for specialized units)
- [ ] `defense_light/armor/air` all non-zero (or explicitly 0)
- [ ] `power` field follows era scaling table (WW1:15-50, WW2:60-180, ...)
- [ ] Grep shows zero `platform_*` references in non-test files
- [ ] Grep shows zero `GC.PlatformType` references
- [ ] All tests pass (`tests/gdunit4_runner.gd`)

**Post-Deployment Verification**:

- [ ] Load old save file → verify units auto-remapped
- [ ] Create new game → verify all 100 units accessible
- [ ] Battle test → verify DIRECT units target nearest enemy
- [ ] Battle test → verify INDIRECT/AERIAL units target countered types
- [ ] Damage test → verify cross-type damage uses correct attack/defense pairs

## Rollback Plan

If critical bugs discovered post-release:

1. **Hotfix**: Revert to `data/default_cards.gd` (old 29-unit system)
2. **Code**: Comment out multi-dim damage logic, restore single `base_damage`/`base_defense`
3. **Saves**: Run reverse migration script on corrupted saves
4. **Communication**: Notify players of rollback, promise re-release after fixes

**Rollback Time**: < 4 hours (if backup migration script prepared)

## References

| Document | Link |
|----------|------|
| 100-Unit Data Specification | `docs/100基础单位的完整数据结构.md` |
| Key Design Decisions Summary | `docs/相位战争 - 关键设计决策汇总.md` |
| Existing Data Layer ADR | `docs/architecture/adr-0003-data-layer-design.md` |
| Save System ADR | `docs/architecture/adr-0004-save-system-architecture.md` |

## Version History

| Version | Date | Changes |
|---------|------|---------|
| 0.1 | 2026-05-28 | Initial draft (Proposed status) |
