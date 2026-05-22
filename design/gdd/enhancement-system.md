# Enhancement System

> **Status**: Reverse-Documented (Verified v3)
> **Source**: `managers/card_enhancement_manager.gd`, `scenes/ui/card_enhancement_panel.gd`
> **Last Updated**: 2026-05-18
> **Implements Pillar**: Permanent Growth

## Overview

Per-card instance enhancement levels (+1…+10) increase combat stats using nano materials. Success rates decay from **95%** at Lv1 to **40%** at Lv10. **Mutation slots** at +5/+7/+9 are **not implemented** (v3 cancelled).

## Player Fantasy

Risk/reward nano sink on individual deployed cards; failures still consume materials.

## Detailed Rules

1. Each card instance tracks `enhancement_level` (0–10).
2. `try_enhance(card_id)` rolls against `ENHANCEMENT_CONFIG[level].success_rate`.
3. On success: apply `attribute_bonus` to stored enhancement stats.
4. On failure: materials consumed, level unchanged.
5. No variant/mutation slot unlocks at any level.

## Formulas

- Success rate and nano cost: `ENHANCEMENT_CONFIG` in `card_enhancement_manager.gd` (Lv1: 95%, Lv10: 40%).

## Edge Cases

- Enhancing at max level returns failure message.
- Cards without instance records initialize at level 0.

## Dependencies

- `BasicResourceManager` (nano)
- Backpack card instances

## Tuning Knobs

- `ENHANCEMENT_CONFIG` table per level

## Acceptance Criteria

- [x] Success rates match 95%→40% table
- [x] No mutation slot UI or logic in enhancement flow
