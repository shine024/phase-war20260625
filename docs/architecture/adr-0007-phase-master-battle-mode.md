# ADR-0007: Phase Master Battle Mode

## Status

Accepted

## Date

2026-04-24

## Last Verified

2026-04-24

## Decision Makers

Project lead (reverse-documented from implementation)

## Summary

Phase Master battles are a special encounter mode where the player faces an AI-controlled opponent with a phase instrument loadout (mirroring the player's own loadout system). Encounters trigger with 15% probability per standard battle (forced at level 49). The enemy Phase Field Driver acts as a destructible base that continuously produces units using equipment data from `EnemyPhaseMasters`. This mode completely bypasses the standard wave spawn system (ADR-0006), replacing it with sustained base-vs-base combat that ends when either the player's or enemy's phase field driver is destroyed.

## Engine Compatibility

| Field | Value |
|-------|-------|
| **Engine** | Godot 4.5 |
| **Domain** | Core / Gameplay |
| **Knowledge Risk** | LOW -- Node2D lifecycle, timer-based spawning, scene instantiation are stable APIs |
| **References Consulted** | `docs/engine-reference/godot/VERSION.md` |
| **Post-Cutoff APIs Used** | None |
| **Verification Required** | None |

## ADR Dependencies

| Field | Value |
|-------|-------|
| **Depends On** | ADR-0001 (autoload singleton), ADR-0002 (SignalBus), ADR-0005 (phase instrument loadout), ADR-0006 (wave spawn -- must be skipped) |
| **Enables** | Future ADR for AI opponent behavior (spell casting, tactical decisions) |
| **Blocks** | None |
| **Ordering Note** | Phase Master is a mode branch; it reads from the same loadout architecture (ADR-0005) that the player uses, but produces enemy units autonomously |

## Context

### Problem Statement

The campaign needs variety beyond wave-based encounters. Phase Master battles provide a distinct challenge: an AI opponent with named identity, faction affiliation, equipment loadout, and combat traits. This creates boss-like encounters that feel different from standard wave battles, test the player's loadout against a mirror opponent, and add narrative flavor through named enemy phase masters.

### Current State

The system is fully implemented across three layers:

1. **Trigger logic** in `GameManager.check_phase_master_encounter()` -- rolls 15% chance, forces at level 49, selects a faction-matching master from the leaderboard
2. **Configuration enrichment** in `GameManager._enrich_master_config()` -- merges leaderboard's simple config (`{name, faction, era}`) with `EnemyPhaseMasters` full data (`{equipment, stats, traits, spells}`)
3. **Battle execution** via `EnemyPhaseFieldDriver` -- continuous unit production using equipment data, base HP as win condition

### Constraints

- Phase Master is a random encounter, not a selectable mode -- it can only happen during campaign battles
- The enemy AI does not cast spells or use active abilities yet -- current implementation is production-only (base HP + unit spawning)
- Phase Master battles coexist with Tower Climb as separate systems: Phase Master is a campaign encounter modifier, Tower Climb is a standalone mode (`tower_climb_manager.gd`)
- Equipment data references must resolve against `EnemyPhaseEquipment` definitions

### Requirements

- 15% encounter chance per battle (0.15 constant in `game_constants.gd`)
- Level 49 forces a Phase Master encounter
- Faction-matching priority: prefer masters from the current level's faction
- Enemy must use a destructible base (Phase Field Driver) as the win/loss condition
- Unit production must use the enemy's equipment loadout (platforms + weapons) when available, with fallback to `EnemyArchetypes`
- Wave spawn system (ADR-0006) must be completely bypassed during Phase Master battles

## Decision

### Architecture

```
Campaign Battle Start
        |
        v
GameManager.check_phase_master_encounter()
        |
        +---> randf() > 0.15 (or level == 49)?
        |         |
        |         +---> No: standard wave battle (ADR-0006)
        |         |
        |         +---> Yes:
        |                   |
        |                   v
        |             Faction matching -> select master from leaderboard
        |                   |
        |                   v
        |             _enrich_master_config(simple_config)
        |                   |
        |                   +---> faction name mapping (7 player factions -> 4 enemy factions)
        |                   +---> EnemyPhaseMasters.get_masters_by_faction()
        |                   +---> merge: {equipment, stats, traits, spells, active/passive_spells}
        |                   |
        |                   v
        |             GameManager._current_phase_master (enriched Dictionary)
        |             GameManager._is_phase_master_battle = true
        |                   |
        v                   v
BattleManager.start_battle()
        |
        +---> _is_phase_master_battle == true?
        |         |
        |         +---> Yes: skip wave timer setup, call _spawn_enemy_phase_master_base()
        |         |
        |         +---> No: standard wave spawn (ADR-0006)
        |
        v
EnemyPhaseFieldDriver
        |
        +---> setup(master_config)
        |         |
        |         +---> max_hp from stats (default: 300 + era*80)
        |         +---> spawn_interval from energy_regen (range: 3.0s - 8.0s)
        |         +---> _unit_limit from stats (default: 5)
        |         +---> _has_equipment flag
        |
        +---> start_production() -> _process() timer loop
        |         |
        |         +---> _has_equipment?
        |                   |
        |                   +---> Yes: _produce_unit_with_equipment()
        |                   |         -> select platform (filtered), 1-2 weapons
        |                   |         -> build UnitStats via UnitStatsTable
        |                   |         -> apply master stat multipliers
        |                   |         -> instantiate ConstructUnit
        |                   |
        |                   +---> No: _produce_unit_fallback()
        |                             -> EnemyArchetypes lookup
        |                             -> instantiate EnemyUnit
        |
        +---> take_damage() -> hp <= 0 -> _on_destroyed()
                    |
                    SignalBus.enemy_phase_driver_destroyed.emit()
                    |
                    v
              BattleManager._on_enemy_phase_driver_destroyed()
              -> player victory
```

### Three Battle Modes Comparison

| Aspect | Standard Campaign | Phase Master | Tower Climb |
|--------|-------------------|-------------|-------------|
| **Trigger** | Default campaign mode | 15% random / Level 49 forced | Standalone mode entry |
| **Duration** | Fixed wave count (3-10) | Until base destroyed | Until all floors cleared or player dies |
| **Enemy Source** | Wave spawn (LevelEras tables) | Phase Field Driver production | Floor definitions (TowerDefinitions) |
| **Win Condition** | Survive all waves | Destroy enemy Phase Field Driver | Clear all floors |
| **Lose Condition** | Player base HP <= 0 | Player base HP <= 0 | Player dies on a floor |
| **Wave System** | ADR-0006 active | ADR-0006 disabled | Floor-based (not wave-based) |
| **Enemy AI** | None (passive waves) | Production only (no spell casting) | Floor-specific behaviors |
| **Data Source** | `LevelEras` + `EnemyArchetypes` | `EnemyPhaseMasters` + `EnemyPhaseEquipment` | `TowerDefinitions` |

### Key Interfaces

```gdscript
# GameManager -- trigger and configuration
func check_phase_master_encounter() -> Dictionary
    # Returns enriched master config or empty dict (no encounter)

func is_phase_master_battle() -> bool
    # Returns true during active Phase Master battle

func get_current_phase_master() -> Dictionary
    # Returns the full enriched config (name, equipment, stats, traits, spells)

func _enrich_master_config(simple_config: Dictionary) -> Dictionary
    # Merges leaderboard simple config with EnemyPhaseMasters data
    # Maps 7 player factions to 4 enemy factions


# EnemyPhaseFieldDriver -- battle execution (extends Node2D)
func setup(master_config: Dictionary) -> void
    # Extracts equipment, stats; sets max_hp, spawn_interval, _unit_limit

func start_production() -> void
    # Begins timer-based unit spawning

func take_damage(amount: float, attacker: Variant = null) -> void
    # Reduces HP, emits enemy_phase_driver_hp_changed signal

func _produce_unit_with_equipment() -> void
    # Selects platform + weapons from equipment, builds UnitStats, spawns ConstructUnit

func _produce_unit_fallback() -> void
    # Uses EnemyArchetypes when no equipment data available
```

### Faction Mapping

The leaderboard uses 7 player faction names; `EnemyPhaseMasters` uses 4 base factions plus hybrids. `_enrich_master_config` maps:

| Leaderboard Faction | Enemy Faction |
|---------------------|--------------|
| aether_dynamics | steel |
| helix_recon | thunder |
| nova_arms | flame |
| iron_wall_corp | steel |
| void_research | void |
| (others) | best-match by era |

### Enemy Phase Master Tiers

| Tier | Level Range | Difficulty | Factions | Notable Stats |
|------|------------|-----------|----------|---------------|
| 1 | 5-8 | easy | steel, flame, thunder, void | HP 1100-1500, atk 120-160, limit 5-6 |
| 2 | 10-14 | medium | base 4 + hybrid | HP 1800-2200, atk 200-280, limit 6-7 |
| 3 | 16-19 | hard | base 4 + hybrid | HP 2600-3200, atk 340-400, limit 7-8 |
| 4 | 22-25 | expert | base 4 + hybrid | HP 3800-5000, atk 480-520, limit 7-9 |
| 5 | 26-28 | legendary | base 4 + hybrid | HP 4000-5500, atk 480-580, limit 8-10 |
| 6-7 | 28-30 | legendary/ultimate | base 4 + all | HP 5800-10000, atk 550-1000, limit 9-15 |

### Implementation Guidelines

1. **Equipment-based production** (`_produce_unit_with_equipment`): Filter out "infantry-type" platforms (striker, sniper, stealth, mage) from thunder/void factions before selection. Randomly pick 1-2 weapons per unit (40% chance of 2 weapons).
2. **Stat multipliers**: Enemy master's `attack_power` grants +0.05% damage per point to spawned units; `defense` grants +0.03% HP per point. This makes higher-tier masters feel noticeably stronger beyond just their equipment quality.
3. **Spawn interval** derives from `energy_regen`: `maxf(3.0, 8.0 - energy_regen * 1.0)`. Range is 3.0s (high energy_regen) to 8.0s (low energy_regen). First spawn is always at 3 seconds.
4. **Fallback path**: When no equipment data is available (e.g., JSON missing or schema mismatch), `_produce_unit_fallback` uses `EnemyArchetypes.get_ids_for_era()` to maintain era-appropriate visuals.
5. **Visual archetype selection**: `_pick_visual_archetype_for_era` verifies sprite frame resources exist before assignment, preventing invisible units from missing assets.
6. **Battle mode isolation**: The `_is_phase_master_battle` flag is checked at the top of `BattleManager._process()` wave logic. When true, the entire timer-based wave system is bypassed. No wave_started/wave_completed signals fire during Phase Master battles.

## Alternatives Considered

### Alternative 1: Phase Master as a Selectable Game Mode

- **Description**: Player can choose to enter Phase Master battles from the campaign map, like Tower Climb
- **Pros**: More player agency; clearer progression
- **Cons**: Loses the surprise encounter design; dilutes the "special boss" feeling; requires additional UI and mode management
- **Estimated Effort**: Medium (add mode selection UI, map integration)
- **Rejection Reason**: The 15% random trigger creates tension and surprise that a selectable mode cannot replicate. Level 49 forced encounter provides a guaranteed boss moment mid-campaign.

### Alternative 2: Shared Wave System (Phase Master uses wave spawn with modified parameters)

- **Description**: Phase Master battles use the same wave system from ADR-0006 but with different LevelEras parameters
- **Pros**: Less code divergence; single spawn path to maintain
- **Cons**: Fundamentally different design -- Phase Master is sustained production until base dies, not fixed wave count; wave system cannot express "spawn until my base HP is zero"
- **Estimated Effort**: Higher (would need to graft base-HP win condition onto wave system)
- **Rejection Reason**: The Phase Field Driver model (continuous production + destructible base) is architecturally cleaner than warping the wave system

### Alternative 3: Full AI Opponent (spell casting, tactical deployment)

- **Description**: Enemy phase master actively casts spells, manages energy, and makes tactical decisions about unit composition
- **Pros**: Would provide a truly mirror-match experience against the player
- **Cons**: Significantly higher implementation complexity; AI behavior tuning is notoriously difficult; current system provides the core loop without AI complexity
- **Estimated Effort**: Very high (AI decision tree, spell system integration, energy management)
- **Rejection Reason**: Current implementation provides the essential experience (base-vs-base, equipment-driven unit production). AI spell casting can be layered on later as a future enhancement without structural changes -- the `active_spells` and `passive_spells` data is already defined in `EnemyPhaseMasters` and ready for future implementation.

## Consequences

### Positive

- Distinct battle mode creates variety within the campaign
- Equipment data model mirrors the player's own loadout system (ADR-0005), creating thematic consistency
- Named, factioned masters with traits and spells add narrative depth
- Fallback path ensures battles work even if JSON data is missing
- 30 pre-defined masters across 7 tiers provide extensive content

### Negative

- Non-deterministic encounter trigger (15% RNG) means players may experience inconsistent difficulty
- AI spell casting is not implemented -- masters defined with `active_spells` and `passive_spells` but none are cast during battle
- Faction mapping from 7 player factions to 4 enemy factions is lossy -- some factions share the same enemy pool
- Higher-tier masters (unit_limit up to 15) may exceed the standard 5-unit visual cap during Phase Master battles

### Neutral

- Phase Master battles use the same Battlefield scene as standard battles
- Enemy Phase Field Driver is a Node2D added to the scene tree, not a separate scene state
- Tower Climb is a completely separate system (`tower_climb_manager.gd`) with no shared code with Phase Master

## Risks

| Risk | Probability | Impact | Mitigation |
|------|------------|--------|-----------|
| High-tier masters with unit_limit > 5 cause performance issues | Medium | Medium | Monitor unit count in PerformanceMetricsManager; cap can be clamped if needed |
| Missing JSON data causes silent fallback to generic archetypes | Low | Low | `_load_json_data` pushes warnings; `USE_FALLBACK_SPAWN = true` ensures gameplay continues |
| 15% random trigger frustrates players who want/avoid Phase Master battles | Medium | Low | Level 49 forced encounter ensures every player experiences it at least once |
| AI spell casting gap (data defined but not executed) confuses future developers | High | Low | This ADR explicitly documents the gap; `active_spells`/`passive_spells` are ready for future implementation |

## Performance Implications

| Metric | Before | Expected After | Budget |
|--------|--------|---------------|--------|
| CPU (frame time) | ~0.1ms (wave timer) | ~0.05ms (simple timer check in driver._process) | 16.6ms |
| Memory | N/A | ~50KB for EnemyPhaseMasters data | 512MB |
| Load Time | N/A | ~1ms for JSON parse | N/A |
| Network | N/A | N/A (single-player) | N/A |

Phase Master battles are actually lighter per-frame than wave battles: the driver's `_process` only increments a timer and checks against `spawn_interval`. Unit instantiation occurs at the same rate or lower than wave spawns. The main concern is high-tier masters with `unit_limit > 5`, but ConstructUnit instances are lightweight Node2D objects.

## Migration Plan

No migration -- this ADR documents an existing implemented system.

**Rollback plan**: N/A (documenting current state)

## Validation Criteria

- [ ] Standard battles have 85% chance of NOT triggering Phase Master (statistical over 100 runs)
- [ ] Level 49 ALWAYS triggers Phase Master encounter
- [ ] Phase Master battles produce zero wave_started/wave_completed signals
- [ ] Enemy Phase Field Driver takes damage and emits HP change signals
- [ ] Destroying enemy Phase Field Driver triggers victory
- [ ] Equipment-based production generates ConstructUnits with correct platform/weapon stats
- [ ] Fallback production works when JSON data is unavailable
- [ ] 30 masters across 7 tiers are all loadable and have valid equipment references

## GDD Requirements Addressed

| GDD Document | System | Requirement | How This ADR Satisfies It |
|-------------|--------|-------------|--------------------------|
| Campaign variety | Battle | TR-battle-008: Phase Master encounters as distinct boss-like battles | 15% random trigger + Level 49 forced + faction matching + 30 tiered masters |
| Equipment parity | Battle | Enemy phase masters use same loadout architecture as player | `_enrich_master_config` merges leaderboard data with EnemyPhaseMasters equipment (platforms, weapons, energy cards) |
| Boss encounter design | Battle | Named, factioned opponents with unique traits and visual identity | 30 masters with unique names, titles, factions, traits, spells; era-appropriate visual archetypes |

## Related

- ADR-0005 (Phase Instrument Loadout -- enemy masters mirror the same equipment structure)
- ADR-0006 (Wave Spawn System -- explicitly disabled during Phase Master battles)
- `managers/game_manager.gd` -- `check_phase_master_encounter()`, `_enrich_master_config()`
- `scenes/units/enemy_phase_field_driver.gd` -- unit production and base HP management
- `data/enemy_phase_masters.gd` -- 30 master definitions with equipment, stats, traits, spells
- `data/enemy_phase_equipment.gd` -- weapon/platform definitions for enemy loadouts
- `resources/game_constants.gd` -- `PHASE_MASTER_ENCOUNTER_CHANCE` constant
- `managers/tower_climb_manager.gd` -- Tower Climb mode (independent, not related)
