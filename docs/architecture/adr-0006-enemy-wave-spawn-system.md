# ADR-0006: Enemy Wave Spawn System

## Status

Accepted

## Date

2026-04-24

## Last Verified

2026-04-24

## Decision Makers

Project lead (reverse-documented from implementation)

## Summary

Enemy encounters in standard campaign battles follow a deterministic wave-based spawn system driven by `LevelEras` data tables. Wave count, spawn density, and intervals scale linearly within each of five historical eras (WW1 through Near Future) across 100 levels. Both players and enemies share a hard unit cap of 5, enforced by `clampi(..., 1, 5)`. BattleManager orchestrates wave progression via a timer loop in `_process`, delegating actual unit instantiation to the spawn system and Battlefield scene.

## Engine Compatibility

| Field | Value |
|-------|-------|
| **Engine** | Godot 4.5 |
| **Domain** | Core / Gameplay |
| **Knowledge Risk** | LOW -- static utility class, randi_range, clampi are stable APIs |
| **References Consulted** | `docs/engine-reference/godot/VERSION.md` |
| **Post-Cutoff APIs Used** | None |
| **Verification Required** | None |

## ADR Dependencies

| Field | Value |
|-------|-------|
| **Depends On** | ADR-0001 (autoload singleton), ADR-0002 (SignalBus event mediator), ADR-0003 (data layer) |
| **Enables** | ADR-0007 (Phase Master battle mode -- which explicitly disables this system) |
| **Blocks** | None |
| **Ordering Note** | Wave spawn system is the default battle mode; Phase Master (ADR-0007) branches off by skipping it |

## Context

### Problem Statement

The campaign spans 100 levels across five historical eras. Each level needs a configurable number of enemy waves with era-appropriate enemy density and pacing. Without a structured spawn system, enemy encounters would feel arbitrary, difficulty would be impossible to tune, and the 5-unit cap for both sides would be inconsistently enforced.

### Current State

The system is fully implemented in `data/level_eras.gd` (static utility class `LevelEras`) and driven by `BattleManager._process()` via `_spawn_system.spawn_enemy_wave(level)`. Wave parameters are read from era-based constant dictionaries and interpolated linearly within each 20-level era block.

### Constraints

- 100 levels divided into 5 eras of 20 levels each -- immutable structure
- Both player and enemy unit caps are hard-limited to 5 to keep visual clarity and performance within budget
- Wave spawn uses `randi_range` for per-wave variance -- non-deterministic but bounded
- Spawn intervals must not drop below 11 seconds to prevent overwhelming the player

### Requirements

- Wave count must scale from 3 waves (WW1 Level 1) to 10 waves (Near Future Level 100)
- Spawn count per wave must stay within the 5-unit hard cap shared with the player
- Wave interval must decrease across eras to increase pace (14s -> 11s)
- The system must be skippable for Phase Master battles (ADR-0007)
- Era-appropriate enemy archetypes must be selected from `enemy_archetypes.json`

## Decision

### Architecture

```
GameManager.current_level
        |
        v
   BattleManager._process()
        |
        +---> _spawn_system.update_wave_timer(delta)
        |           |
        |           +---> should_spawn_wave()? ---> consume_wave_timer()
        |           |
        |           +---> can_spawn_more_waves()? ---> spawn_enemy_wave(level)
        |
        v
   LevelEras (static queries)
        |
        +---> get_wave_total_for_level(level)      -> int
        +---> get_wave_interval_for_level(level)    -> float
        +---> get_spawn_count_for_wave(level, idx)  -> int
        +---> get_era(level)                        -> int
        |
        v
   EnemyArchetypes.get_ids_for_era(era) -> Array[String]
        |
        v
   EnemyUnit scene instantiated & added to Battlefield/EnemyUnits
```

### Era Progression Table

| Era | Levels | Wave Range | Spawn/Wave | Interval | Drop Mult |
|-----|--------|-----------|------------|----------|-----------|
| WW1 | 1-20 | [3, 5] | [1, 2] | 14.0s | 0.85x |
| WW2 | 21-40 | [4, 7] | [2, 3] | 13.0s | 1.0x |
| Cold War | 41-60 | [5, 8] | [2, 3] | 12.0s | 1.15x |
| Modern | 61-80 | [6, 9] | [2, 4] | 12.0s | 1.25x |
| Near Future | 81-100 | [7, 10] | [3, 4] | 11.0s | 1.4x |

### Key Interfaces

```gdscript
# LevelEras -- all methods are static, no instantiation needed
static func get_era(level: int) -> int
    # Maps level (1-100) to era index (0=WW1 .. 4=Near Future)

static func get_wave_total_for_level(level: int) -> int
    # Linear interpolation within era: Level 1 of era = min, Level 20 = max

static func get_wave_interval_for_level(level: int) -> float
    # Fixed per era (no intra-era interpolation)

static func get_spawn_count_for_wave(level: int, wave_index: int) -> int
    # Base random within era range + wave_bonus (floor(wave_index/4))
    # Hard capped: clampi(base + wave_bonus, 1, 5)
```

### Implementation Guidelines

1. **Era interpolation** uses linear interpolation: `t = (in_era - 1) / 19.0`. Level 1 of each era gets the minimum wave count; level 20 gets the maximum.
2. **Wave bonus** grows slowly: `mini(floor(wave_index / 4.0), 1)`. This adds +1 spawn count every 4 waves, capped at +1. Combined with era ranges, the absolute cap of 5 prevents overflow.
3. **Unit cap enforcement** is shared: `clampi(..., 1, 5)` applies identically to both player-spawned and enemy-spawned units. BattleManager tracks counts via `get_enemy_unit_count()` / `set_enemy_unit_count()`.
4. **Enemy archetype selection** uses `EnemyArchetypes.get_ids_for_era(era)` with `randi()` for variety within the correct historical period.
5. **Phase Master bypass**: When `_is_phase_master_battle == true` in BattleManager, the entire wave timer and spawn logic is skipped in `_process()`. This is documented in ADR-0007.
6. **SignalBus integration** (ADR-0002): Spawn events emit through SignalBus for HUD updates, damage number triggers, and achievement tracking.

## Alternatives Considered

### Alternative 1: Procedural Difficulty Curve (formula-based, no era tables)

- **Description**: Single difficulty formula mapping level 1-100 to wave parameters without era boundaries
- **Pros**: Simpler data structure; smoother difficulty curve
- **Cons**: Loses the thematic "historical era" identity; harder for designers to reason about specific level ranges
- **Estimated Effort**: Lower (remove era tables, add formula)
- **Rejection Reason**: Era-based structure is a core game design pillar -- WW1 enemies should feel distinct from Near Future enemies in density and pace

### Alternative 2: Scriptable Wave Definitions (per-level JSON)

- **Description**: Every level has its own wave definition JSON file with explicit wave counts, spawn lists, and timings
- **Pros**: Maximum designer control per level
- **Cons**: 100 JSON files to maintain; linear interpolation already provides smooth scaling; high data-entry burden
- **Estimated Effort**: Significantly higher
- **Rejection Reason**: The era-based interpolation covers 100 levels adequately; per-level JSON would only be justified if specific levels needed bespoke wave patterns

## Consequences

### Positive

- Clean separation: `LevelEras` is a pure data class with no scene dependencies
- Predictable difficulty curve within each era
- Hard unit cap keeps visual clarity and performance bounded
- Era theming is naturally reinforced through spawn density differences

### Negative

- `randi_range` in `get_spawn_count_for_wave` makes exact wave compositions non-reproducible across runs
- No per-level bespoke wave tuning -- if a specific level needs an unusual wave pattern, the era system must be overridden
- Wave bonus formula (`floor(wave_index / 4.0)`) is simple but may feel too uniform across all eras

### Neutral

- Drop rate multiplier scales with era independently of spawn density
- XP rewards use a separate 3-anchor interpolation system (first/mid/last level of era)

## Risks

| Risk | Probability | Impact | Mitigation |
|------|------------|--------|-----------|
| Late-era wave density (3-4 spawns) may exceed 5-unit cap when combined with wave bonus | Low | Low | `clampi(..., 1, 5)` hard cap already prevents this |
| Wave timer logic in BattleManager._process conflicts with Phase Master mode | Already mitigated | N/A | Phase Master check is the first branch in the wave code path |
| Non-deterministic spawn makes replay debugging difficult | Medium | Low | Seed-based RNG could be added later without structural changes |

## Performance Implications

| Metric | Before | Expected After | Budget |
|--------|--------|---------------|--------|
| CPU (frame time) | N/A (new system) | ~0.1ms per frame for timer check | 16.6ms |
| Memory | N/A | ~2KB for LevelEras constants | 512MB |
| Load Time | N/A | Negligible (static class) | N/A |
| Network | N/A | N/A (single-player) | N/A |

Spawn system contributes negligible per-frame cost (timer increment + comparison). Actual unit instantiation occurs once per wave interval (11-14 seconds), well within frame budget. The 5-unit cap ensures at most 10 active units on screen (5 player + 5 enemy) per battle, keeping draw calls under budget.

## Migration Plan

No migration -- this ADR documents an existing implemented system. The wave spawn system has been operational since initial campaign implementation.

**Rollback plan**: N/A (documenting current state, not proposing changes)

## Validation Criteria

- [ ] All 100 levels resolve to valid wave counts within their era range
- [ ] No wave ever produces more than 5 simultaneous enemy units
- [ ] Phase Master battles correctly skip wave spawn logic
- [ ] Wave interval never drops below 11 seconds (Near Future era floor)
- [ ] Era transitions (levels 20->21, 40->41, etc.) produce reasonable difficulty step-ups

## GDD Requirements Addressed

| GDD Document | System | Requirement | How This ADR Satisfies It |
|-------------|--------|-------------|--------------------------|
| Campaign progression | Battle | TR-battle-007: Wave-based enemy encounters scale across eras | LevelEras provides era-based wave count, density, and interval tables with linear intra-era interpolation |
| Unit balance | Battle | Symmetric unit cap (5 per side) | `clampi(base + wave_bonus, 1, 5)` enforces identical cap for enemy spawn and player deployment |

## Related

- ADR-0002 (SignalBus -- wave events are emitted through SignalBus)
- ADR-0003 (Data layer -- enemy archetypes loaded from JSON)
- ADR-0007 (Phase Master -- this system is explicitly disabled during Phase Master battles)
- `data/level_eras.gd` -- LevelEras static class
- `managers/battle/battle_manager.gd` -- wave timer loop in `_process()`
- `data/enemy_archetypes.gd` -- era-based enemy archetype lookup
