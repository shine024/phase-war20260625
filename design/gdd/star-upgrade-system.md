# Star Upgrade System

> **Status**: Verified (v3, reverse-documented)
> **Source**: `managers/blueprint_manager.gd`, `data/blueprint_star_config.gd`
> **Last Updated**: 2026-05-18
> **Implements Pillar**: Permanent Growth

## Overview

Account-wide card stars (1–9★) are raised by spending **research points** only. There is no fragment currency and no auto-star from accumulated copies.

## Player Fantasy

Invest research earned from battles into flagship units; each star tier is a deliberate spend, not a passive pile-up.

## Detailed Rules

1. Each `card_id` has `blueprint_stars[card_id]` (1–9).
2. `can_upgrade_star(card_id)` when current research points ≥ `StarConfig.get_star_upgrade_cost(star)`.
3. `upgrade_blueprint_star(card_id)` deducts research points and emits `blueprint_star_upgraded`.
4. Extra blueprint copies from legacy drops convert to research point grants (`add_blueprint_copy` overflow path).

## Formulas

- Cost table: `data/blueprint_star_config.gd` → `STAR_UPGRADE_RESEARCH_COSTS` (v3.0.1 fixed table).

## Dependencies

- `BasicResourceManager` (research points)
- `BlueprintManager` (account star state)
- `AffixManager` (star-up affix hooks)

## Tuning Knobs

- Per-star research costs in `blueprint_star_config.gd`
- Battle base research in `data/card_progression_settings.gd`

## Acceptance Criteria

- [x] Upgrade never requires fragment/shard counters
- [x] UI shows research cost, not fragment progress
- [x] `tests/star_config_smoke.gd` passes cost table expectations
