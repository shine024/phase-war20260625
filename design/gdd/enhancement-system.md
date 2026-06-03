# Enhancement System

> **Status**: Active (v6.0)
> **Source**: `managers/card_enhancement_manager.gd`, `scenes/ui/card_enhancement_panel.gd`, `scenes/ui/reinforcement_panel.gd`
> **Last Updated**: 2026-06-03
> **Implements Pillar**: Permanent Growth

## Overview

Per-card instance enhancement levels (0–10) increase combat stats using nano materials. **100% success rate** at all levels (v5.0+). Enhancement level is stored on `CardResource.enhance_level` and read by `UnitStatsTable`, `AttackCalculator`, and `Bullet` for damage multipliers.

## Player Fantasy

Reliable nano-material investment on individual deployed cards. Every enhancement succeeds, making it a pure resource-planning decision.

## Detailed Rules

1. Each card instance tracks `enhance_level` (0–10) on `CardResource`.
2. `enhance(card_id)` consumes nano materials and increments `card.enhance_level`.
3. Cost formula: `ENHANCE_BASE_COST × level_cost_multiplier × era_multiplier`.
4. Enhancement applies combat multipliers via `AttackCalculator` and `Bullet` (read `enhance_level` from `UnitStats`).
5. Two UI panels access the same system: `CardEnhancementPanel` and `ReinforcementPanel` (both modify `card.enhance_level`).

## Formulas

### Enhancement Cost (v6.0)

```
cost = ENHANCE_BASE_COST × level_cost_multiplier × era_multiplier
ENHANCE_BASE_COST = 50
```

| Level | level_cost_multiplier | attribute_bonus |
|-------|----------------------|-----------------|
| 1     | 0.5                  | +5%             |
| 2     | 1.0                  | +10%            |
| 3     | 1.5                  | +15%            |
| 4     | 2.0                  | +20%            |
| 5     | 2.5                  | +25%            |
| 6     | 3.0                  | +30%            |
| 7     | 3.5                  | +35%            |
| 8     | 4.0                  | +40%            |
| 9     | 5.0                  | +50%            |
| 10    | 6.0                  | +60%            |

### Era Multiplier

| Era        | Multiplier |
|------------|-----------|
| WWI (0)    | ×0.5      |
| WWII (1)   | ×1.0      |
| Cold War (2)| ×2.0     |
| Modern (3) | ×3.0      |
| Near Future (4)| ×4.0  |

### Example Costs

- WWI MP18 → Lv1: 50 × 0.5 × 0.5 = 12 nano
- WWII Tank → Lv5: 50 × 2.5 × 1.0 = 125 nano
- Cold War T-55 → Lv10: 50 × 6.0 × 2.0 = 600 nano

### Power Multiplier (combat damage scaling)

```
Lv 1-8: 1.0 + level × 0.05
Lv 9:   1.50
Lv 10:  1.60
```

## Edge Cases

- Enhancing at max level (10) returns failure message.
- Cards without CardResource default to enhance_level = 0.
- Old saves with `card_enhancement_level` dictionary are migrated to `card.enhance_level` on load.
- Evolution resets enhance_level to 0 on the new card.

## Dependencies

- `BlueprintManager` — nano material currency (`get_nano_materials`, `add_nano_materials`)
- `CardResource` — `enhance_level` field (single source of truth)
- `UnitStatsTable` — copies `enhance_level` into `UnitStats`
- `AttackCalculator` / `Bullet` — reads `UnitStats.enhance_level` for damage multiplier
- `UnifiedRankSystem` — `get_power_multiplier()` and `get_cost_multiplier()`

## Tuning Knobs

- `ENHANCE_BASE_COST` (currently 50)
- `ERA_MULTIPLIER` table per era
- `level_cost_multiplier` per level in `enhancement_config`
- `attribute_bonus` per level

## Acceptance Criteria

- [x] 100% success rate at all levels
- [x] Enhancement level stored on `CardResource.enhance_level`
- [x] Combat damage scaled by power multiplier
- [x] Cost formula includes era multiplier (v6.0)
- [x] Old save migration from `card_enhancement_level` dictionary
- [x] EnhancementAnimation fires on success/failure
