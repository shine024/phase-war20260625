# Battle System

> **Status**: Reverse-Documented
> **Source**: `managers/battle_manager.gd` (869 lines)
> **Author**: Reverse-documented from implementation
> **Last Updated**: 2026-04-08
> **Implements Pillar**: Tactical Combat & Strategic Planning

> **Quick reference** — Layer: `Core` · Priority: `MVP` · Key deps: `EnergyManager`, `PhaseInstrumentManager`, `DropManager`, `AffixManager`, `GameManager`, `BlueprintManager`

## Summary

The Battle System is Phase War's core gameplay loop, managing real-time auto-combat between player-deployed units and enemy waves. Players manually deploy units during battle by clicking on the field, spending energy and managing a limited unit cap. Enemy waves spawn at timed intervals according to level configuration. The system handles victory/defeat conditions, star rating (1-3★) based on performance, combat drops (CARD_DATA / finished cards / blueprint data / knowledge values), and integrates with affix, blueprint, and phase law systems for unit stat calculations and combat effects.

Key design philosophy: **Balance build & operation** (pre-battle loadout matters, but in-battle decisions are meaningful), **resource management** (plan deployments within limited waves and energy), and **reward tiering** (higher stars = better drops).

## Overview

The Battle System orchestrates the real-time combat phase of Phase War. Before battle, players assemble their loadout in the phase instrument (platform + weapon combinations). During battle, players click on the field to deploy units, which materialize after a deployment timer based on energy cost. Meanwhile, enemies spawn in waves from the right side of the battlefield. Combat is automatic—units move, target enemies in range, and fire weapons. Players can also cast active phase laws if energy permits.

Victory requires surviving all configured enemy waves (or all enemies in unlimited-wave mode) while protecting the phase field driver (player base). Star rating (1-3★) is calculated based on survival rate and battle speed, with higher stars granting better post-battle drops.

## Player Fantasy

**The Tactical Commander Fantasy**: Players feel like battlefield commanders directing their custom-built forces. Key emotional beats:

- **Preparation**: Your loadout decisions matter—platform/weapon combinations define your available forces
- **Deployment**: Each deployment is a strategic choice—positioning, timing, and energy management
- **Observation**: Watch your custom creations fight autonomously, seeing your build choices in action
- **Adaptation**: Respond to battlefield conditions with timely deployments and law casts
- **Progression**: Each battle grants resources (knowledge, research points) that permanently improve your arsenal

The system should feel like **a blend of auto-battler preparation and real-time strategy control**. You're not directly controlling units, but your deployment decisions shape the battle flow.

## Detailed Design

### Core Rules

1. **Battle Lifecycle**
   - `start_battle()`: Initialize battlefield, reset counters, spawn preview units, sync laws, start energy system
   - Battle runs in `_process()`: Enemy wave timer advances, spawns waves when interval reached
   - `end_battle(player_won)`: Stop all systems, clear units, grant battle affixes if won, generate drops, notify quest manager
   - Signals: `battle_started`, `battle_ended`, `unit_spawned`, `unit_died`, `wave_spawned`

2. **Player Deployment**
   - **Manual click deployment**: Players click on battlefield to deploy
   - **Deployment cost**: Platform energy cost + all weapon energy costs
   - **Deployment time**: Total cost / energy output rate (higher cost = longer delay)
   - **Unit cap**: Limited by phase instrument slot count (default: 5 units max)
   - **Duplicate restriction**: Cannot deploy same platform card if already on field
   - **Deploy ghost**: Visual preview appears, counts toward cap, materializes after timer
   - **Validation**: Checks energy, loadout validity, unit cap, position bounds, duplicate restrictions

3. **Enemy Wave System**
   - **Timed waves**: Spawn every `_enemy_wave_interval` seconds (default: 12s, configurable per level)
   - **Wave count**: Limited by `_enemy_wave_total` from level config (0 = unlimited)
   - **Spawn logic**:
     - First wave: 3 seconds after battle start
     - Subsequent waves: Every interval seconds
     - Last wave: Spawns boss if available (when total waves > 3)
     - Every 3rd wave (2nd, 5th, 8th...): Spawns elite
     - Other waves: Spawn basic enemies
   - **Unit count per wave**: Configurable per level (default: 1-2 units)
   - **Enemy cap**: Max 5 enemies on field at once
   - **Era-based selection**: Enemies selected from current era's archetype pool

4. **Victory/Defeat Conditions**
   - **Victory (normal battle)**: All waves spawned AND all enemies destroyed
   - **Victory (phase master battle)**: Enemy phase driver destroyed
   - **Defeat (any battle)**: Player phase field driver destroyed
   - **Checks**: `_check_win_lose()` called on each unit death

5. **Star Rating System (1-3★)**
   - **1★**: Victory (baseline)
   - **2★**: Victory + Survival rate ≥ 50% (lost ≤ half of deployed units)
   - **3★**: Victory + Survival rate ≥ 80% + Time efficiency (battle time ≤ 70% of estimated)
   - **Estimated time**: `wave_total × wave_interval + 15 seconds`
   - **Tracked stats**:
     - `_max_player_units_deployed`: Peak concurrent units
     - `_player_units_lost`: Total units killed
     - `_enemy_units_killed`: Total enemies defeated
     - `_battle_elapsed_time`: Battle duration

6. **Energy System Integration**
   - **Deployment spending**: Deducts energy immediately on successful deployment
   - **Energy cost**: Sum of platform and weapon card energy costs
   - **Energy output rate**: Multiplier from phase instrument (affects deployment time)
   - **Battle energy**: Separate from pre-battle energy, managed by EnergyManager

7. **Combat Drops**
   - **CARD_DATA drops**: Roll on enemy death based on archetype drop definitions; yields raw card data entries used for research
   - **Finished cards**: Rare direct drops of usable cards (platforms/weapons), chance increased by star rating
   - **Blueprint data**: Dropped from elite/boss enemies; provides blueprint entries for BlueprintManager
   - **Knowledge values (知识值)**: Base gain on enemy kill; elite = 2×, boss = 3×; boosted by recon units and star rating
   - **Recon bonus**: Scout/Stealth units increase knowledge gain and card drop quality
   - **Environment-based laws**: Knowledge value type influenced by battle environment (weather, terrain, energy field, time)
   - **Post-battle drops**: Generated on victory based on era, level, win/loss, star rating via DropManager

8. **Phase Master Battle Mode** (Special PvP)
   - **Disabled wave system**: No timed enemy waves
   - **Enemy phase driver**: Spawns enemy units continuously
   - **Victory condition**: Destroy enemy phase driver
   - **Config**: Loaded from GameManager's current phase master

9. **Battle Affixes**
   - **On victory**: Participating cards (platforms + weapons used in battle) may gain random affixes
   - **Managed by AffixManager**: `on_battle_won()` processes affix grants
   - **Based on level**: Higher levels may grant better affixes

10. **Kill Rewards**
    - **Shield on kill**: Units with `shield_on_kill` affix gain shield when killing enemies
    - **Last hit tracking**: Enemy records `last_damage_source` to identify killer
    - **Applied immediately**: Shield granted right after enemy death

### States and Transitions

| State | Entry Condition | Exit Condition | Behavior |
|-------|----------------|----------------|----------|
| Not in battle | Default state | `start_battle()` called | No battle logic, all timers reset |
| Battle active | `start_battle()` successful | `end_battle()` called | Wave timer runs, units can deploy, combat enabled |
| Battle paused | Game paused | Game resumed | Wave timer pauses, units freeze |
| Deploying (ghost) | Player clicks valid position | Deployment timer expires | Ghost visible, counts to cap, materializes into real unit |
| Spawning wave | Wave timer reaches interval | Wave spawn complete | Enemy units created and added to field |
| Victory | All waves spawned + all enemies killed | `end_battle(true)` | Star rating calculated, drops generated |
| Defeat | Phase driver destroyed | `end_battle(false)` | No star rating, reduced drops |

### Interactions with Other Systems

| System | Interface | Data Flow | Direction |
|--------|-----------|-----------|-----------|
| **EnergyManager** | `spend()`, `start_battle()`, `end_battle()` | Energy deduction, battle energy init | BattleManager → EnergyManager |
| **PhaseInstrumentManager** | `get_loadout_by_platform_card_id()`, `get_max_deployable_units()`, `get_energy_output_rate()`, `get_spawn_range_ratio()` | Loadout data, unit caps, energy multipliers | PhaseInstrumentManager → BattleManager |
| **DropManager** | `generate_battle_drops()` | Era, level, win/loss, stars → drops | BattleManager → DropManager |
| **AffixManager** | `apply_affixes_to_stats()`, `on_battle_won()` | Star level → affix grants | Bidirectional |
| **BlueprintManager** | `apply_growth_to_stats()`, `add_blueprint_copy()` | Blueprint star → stat multipliers, blueprint data | BattleManager →/← BlueprintManager |
| **GameManager** | `current_level`, `get_era()`, `get_enemy_wave_total_for_level()`, `get_drop_rate_multiplier()` | Level data → battle config | GameManager → BattleManager |
| **QuestManager** | `notify_battle_result()`, `notify_fragments_changed()` | Battle stats → quest progress | BattleManager → QuestManager |
| **SignalBus** | Multiple signals | Battle events → UI and other systems | BattleManager → SignalBus |
| **UnitStatsTable** | `build_multi_stats()` | Platform type, weapon types, era → unit stats | UnitStatsTable → BattleManager |

## Formulas

### Deployment Energy Cost

```
deploy_energy_cost = max(1.0, platform_energy_cost + Σ weapon_energy_costs)
```

| Variable | Type | Range | Source | Description |
|----------|------|-------|--------|-------------|
| platform_energy_cost | float | 1-50 | Card data | Energy cost of platform card |
| weapon_energy_costs | Array[float] | 0-30 each | Card data | Energy costs of all equipped weapons |
| deploy_energy_cost | float | 1-∞ | Calculated | Total energy to deploy |

**Expected output range**: 1 to 100+ energy

### Deployment Time

```
deployment_time = deploy_energy_cost / energy_output_rate
```

| Variable | Type | Range | Source | Description |
|----------|------|-------|--------|-------------|
| deploy_energy_cost | float | 1-∞ | Calculated above | Total energy cost |
| energy_output_rate | float | 0.1-2.0 | PhaseInstrumentManager | Energy per second (multiplier) |
| deployment_time | float | 0.5-∞ | Calculated | Seconds before unit materializes |

**Expected output range**: 0.5s (low cost, high output) to 30s+ (high cost, low output)

### Survival Rate

```
survival_rate = (max_deployed - units_lost) / max_deployed
```

| Variable | Type | Range | Source | Description |
|----------|------|-------|--------|-------------|
| max_deployed | int | 0-∞ | Tracked during battle | Peak concurrent player units |
| units_lost | int | 0-∞ | Tracked during battle | Total player units killed |
| survival_rate | float | 0.0-1.0 | Calculated | Ratio of units survived |

**Expected output range**: 0.0 (all died) to 1.0 (none lost)

### Star Rating Calculation

```
stars = 1  (baseline for victory)
if survival_rate ≥ 0.5:
    stars = 2
if survival_rate ≥ 0.8 AND battle_time ≤ (wave_total × wave_interval + 15) × 0.7:
    stars = 3
```

| Variable | Type | Range | Source | Description |
|----------|------|-------|--------|-------------|
| survival_rate | float | 0.0-1.0 | Calculated above | Unit survival ratio |
| battle_time | float | 0-∞ | Tracked during battle | Actual battle duration in seconds |
| wave_total | int | 0-∞ | Level config | Total enemy waves configured |
| wave_interval | float | 0-∞ | Level config | Seconds between waves |
| stars | int | 1-3 | Calculated | Victory star rating |

**Expected output range**: 1 to 3 stars

### Estimated Battle Time

```
estimated_time = wave_total × wave_interval + 15.0
```

| Variable | Type | Range | Source | Description |
|----------|------|-------|--------|-------------|
| wave_total | int | 0-∞ | Level config | Total enemy waves |
| wave_interval | float | 0-∞ | Level config | Seconds between waves |
| estimated_time | float | 15-∞ | Calculated | Expected battle duration (upper bound) |

**Expected output range**: 15s (0 waves) to 600s+ (many waves)

### Card Data Drop Chance

```
drop_chance = archetype_base_chance × drop_rate_multiplier
if randf() < drop_chance:
    grant CARD_DATA entry (tier scaled by star rating)
```

| Variable | Type | Range | Source | Description |
|----------|------|-------|--------|-------------|
| archetype_base_chance | float | 0.0-1.0 | EnemyArchetypes | Base drop chance for this enemy |
| drop_rate_multiplier | float | 0.5-2.0 | GameManager | Level-specific modifier |
| drop_chance | float | 0.0-1.0 | Calculated | Final drop probability |
| recon_bonus | float | 0.0-0.5 | Calculated | Bonus from scout/stealth units |
| star_rating | int | 1-3 | Battle result | Scales CARD_DATA tier quality |

**Expected output range**: 0% to 100% drop chance

### Knowledge Gain Formula

> **Replaces**: Law Shard Drop Chance (deprecated in v3)

```
knowledge_base = 10
if enemy is elite: knowledge_base = 20 (2×)
if enemy is boss: knowledge_base = 30 (3×)
knowledge_gain = knowledge_base × (1.0 + recon_bonus) × star_multiplier
grant knowledge values (知识值)
```

| Variable | Type | Range | Source | Description |
|----------|------|-------|--------|-------------|
| knowledge_base | int | 10-30 | Enemy tier | Base knowledge per kill |
| recon_bonus | float | 0.0-0.5 | Calculated | Bonus from scout/stealth units |
| star_multiplier | float | 1.0-1.5 | Star rating | 1★=1.0, 2★=1.2, 3★=1.5 |
| knowledge_gain | int | 10-45 | Calculated | Final knowledge granted |

**Expected output range**: 10 (basic, no bonus, 1★) to 45 (boss, max recon, 3★)

### Recon Bonus Calculation

```
recon_bonus = min(0.5, recon_unit_count × 0.1)
```

| Variable | Type | Range | Source | Description |
|----------|------|-------|--------|-------------|
| recon_unit_count | int | 0-5 | Tracked during battle | Scout/Stealth units on field |
| recon_bonus | float | 0.0-0.5 | Calculated | Drop multiplier bonus |

**Expected output range**: 0.0 (no recon) to 0.5 (5 recon units, capped)

## Edge Cases

| Scenario | Expected Behavior | Rationale |
|----------|------------------|-----------|
| Energy insufficient for deployment | Deployment fails, `player_deploy_failed` signal emitted with "insufficient_energy" | Prevents negative energy, provides clear feedback |
| Unit cap reached (5/5) | Deployment fails, `player_deploy_failed` signal emitted with "max_units" | Prevents overflow, enforces strategic limit |
| Duplicate platform deployment | Deployment fails, `player_deploy_failed` signal emitted with "unit_on_field" | Prevents spamming same unit, encourages variety |
| Invalid loadout (no platform/weapons) | Deployment fails, `player_deploy_failed` signal emitted with "invalid_loadout" | Validates configuration before spending energy |
| Deploy position out of bounds | Deployment fails, `player_deploy_failed` signal emitted with "out_of_bounds" | Enforces deploy zone, prevents edge exploits |
| Enemy cap reached (5/5) | Wave spawns fewer units or skips until cap frees up | Prevents performance issues, maintains balance |
| Victory with 0 units deployed | Awards 1★ (minimum victory reward) | Edge case where player wins without deploying (unlikely) |
| Phase master battle without config | Falls back to normal battle behavior | Graceful degradation for missing config |
| Loading old save format | Migrates legacy data structures to new format | Backward compatibility |
| Recon bonus exceeds cap | Clamped to 0.5 (50% bonus maximum) | Prevents exploitation |
| Knowledge gain with no valid knowledge pool | Skip gain, log warning | Prevents crash when knowledge data missing |

## Dependencies

| System | Direction | Nature of Dependency |
|--------|-----------|---------------------|
| **EnergyManager** | This depends on EnergyManager | Energy spending, battle energy init/end |
| **PhaseInstrumentManager** | This depends on PhaseInstrumentManager | Loadout data, unit caps, energy multipliers |
| **DropManager** | DropManager depends on this | Battle results (win/loss, stars) → drop generation |
| **AffixManager** | Bidirectional | Stat calculation (Affix→Battle) + battle affix grants (Battle→Affix) |
| **BlueprintManager** | This depends on BlueprintManager | Star growth → stat multipliers, blueprint data |
| **GameManager** | This depends on GameManager | Level config (waves, intervals, era) |
| **QuestManager** | QuestManager depends on this | Battle stats → quest progress tracking |
| **SignalBus** | This emits to SignalBus | Battle events → UI and other systems |
| **UnitStatsTable** | This depends on UnitStatsTable | Base stats for unit creation |
| **EnemyArchetypes** | This depends on EnemyArchetypes | Enemy configs, drop definitions |

## Tuning Knobs

| Parameter | Current Value | Safe Range | Effect of Increase | Effect of Decrease |
|-----------|--------------|------------|-------------------|-------------------|
| **PLAYER_MAX_UNITS** | 5 | 3-8 | More strategic options, higher CPU load | Fewer options, faster battles |
| **ENEMY_MAX_UNITS** | 5 | 3-10 | Harder battles, more chaos | Easier battles, less pressure |
| **ENEMY_WAVE_INTERVAL** | 12.0s | 8.0-20.0s | Faster pacing, more intense | Slower pacing, more preparation time |
| **3★ Time threshold** | 70% | 50-90% | Harder to get 3★ | Easier to get 3★ |
| **2★ Survival threshold** | 50% | 30-70% | Harder to get 2★ | Easier to get 2★ |
| **3★ Survival threshold** | 80% | 60-90% | Harder to get 3★ | Easier to get 3★ |
| **RECON_KNOWLEDGE_BONUS_PER_UNIT** | 0.1 (10%) | 0.05-0.2 | Recon units more valuable | Recon units less impactful |
| **RECON_KNOWLEDGE_BONUS_CAP** | 0.5 (50%) | 0.3-0.8 | Higher knowledge gain potential | Lower knowledge gain potential |
| **KNOWLEDGE_BASE_GAIN** | 10 | 5-20 | Faster knowledge progression | Slower knowledge progression |
| **KNOWLEDGE_ELITE_MULTIPLIER** | 2.0 | 1.5-3.0 | Elite rewards better | Elite rewards worse |
| **KNOWLEDGE_BOSS_MULTIPLIER** | 3.0 | 2.0-5.0 | Boss rewards better | Boss rewards worse |

**Balance Concerns**:
- **Recon unit stacking**: 5 scout units = 50% bonus, very powerful. Consider if this is intended or exploitable.
- **Star difficulty gap**: 2★ requires 50% survival, 3★ requires 80% survival + time efficiency. Large jump may make 3★ feel unattainable for casual players.
- **Energy cost vs deployment time**: High-cost units take very long to deploy, may not be worth the energy. Monitor if players avoid expensive platforms.

## Visual/Audio Requirements

| Event | Visual Feedback | Audio Feedback | Priority |
|-------|----------------|---------------|----------|
| Battle started | Camera sweep to battlefield, battle UI appears | Battle start fanfare | HIGH |
| Player deployment click | Ghost appears at position with deployment progress bar | Confirmation beep | HIGH |
| Deployment complete | Ghost materializes into real unit with spawn effect | Materialization sound | HIGH |
| Deployment failed | Error shake/red flash, error message | Error buzz | MEDIUM |
| Enemy wave spawned | "Wave 3/10" toast, enemies appear from right | Wave alarm sound | HIGH |
| Unit killed (player) | Unit death animation/vfx, unit counter updates | Death sound | HIGH |
| Unit killed (enemy) | Enemy death animation/vfx, kill counter updates | Enemy death sound | HIGH |
| Phase driver hit (player) | Screen flash red, low HP warning | Critical alarm | HIGH |
| Phase driver destroyed (player) | Explosion, defeat overlay | Defeat stinger | HIGH |
| All enemies cleared | Victory overlay, star rating reveal | Victory fanfare | HIGH |
| CARD_DATA dropped | Card icon flies to collection | Collect chime | MEDIUM |
| Knowledge values gained | Knowledge icon with glow effect flies to collection | Mystical chime | MEDIUM |

**UI Elements Required**:
- Battle HUD (energy bar, unit counters, wave progress, timer)
- Deployment zone visualization (green overlay for valid areas)
- Unit portraits with health bars
- Wave progress indicator (current/total)
- Star rating display (1-3★)
- Battle end screen (victory/defeat, stars, drops)
- Deploy ghost preview (shows selected loadout)
- Kill feed (unit deaths)

## Game Feel

### Feel Reference

**Deployment**: Should feel like **placing units in League of Legends**—deliberate, strategic, with satisfying feedback when the unit materializes. The ghost-to-real transition should have visual weight.

**Combat**: Should feel like **watching auto-battlers clash**—units moving, firing, dying in understandable patterns. Not too chaotic, not too slow. The "frontline" should be visible.

**Wave Spawning**: Should feel like **Left 4 Dead zombie hordes**—tension building as the timer counts down, then a wave of enemies appearing. Audio cues are critical.

**Victory/Defeat**: Should feel like **XCOM mission end**—clear resolution, star rating reveal (victory) or dramatic failure (defeat). The stakes should feel real.

### Input Responsiveness

| Action | Max Input-to-Response Latency (ms) | Frame Budget (at 60fps) | Notes |
|--------|-----------------------------------|------------------------|-------|
| Click to deploy | 50ms | 3 frames | Ghost should appear instantly |
| Deployment complete | N/A (timer-based) | N/A | Materializes after calculated delay |
| Wave spawn | N/A (timer-based) | N/A | Spawns on interval |

### Animation Feel Targets

| Animation | Startup Frames | Active Frames | Recovery Frames | Feel Goal | Notes |
|-----------|---------------|--------------|----------------|-----------|-------|
| Deployment ghost | 5-10 | Until timer ends | N/A | Anticipation, charging up | Ghost shows countdown |
| Unit materialize | 5 | 10 | 5 | Satisfying "pop" into existence | VFX heavy |
| Enemy spawn | 5 | 10 | 5 | Ominous arrival | From right edge |
| Unit death | 5 | 15 | 5 | Impactful but quick | Don't clutter battlefield |
| Phase driver death | 10 | 30 | 20 | Dramatic, consequential | Boss-level finale |

### Impact Moments

| Impact Type | Duration (ms) | Effect Description | Configurable? |
|-------------|--------------|-------------------|---------------|
| Hit-stop (unit kill) | 50-100 | Brief freeze on killing blow, highlights damage numbers | Yes (duration) |
| Wave spawn announcement | 1000-1500 | "Wave X/Y" toast with audio cue | Yes (display time) |
| Star rating reveal | 2000-3000 | Sequential star reveal with sound effects | Yes (sequence timing) |
| Phase driver critical hit | 200-300 | Screen shake + red flash | Yes (intensity) |

## Open Questions

1. **Phase Master Battle**: This mode seems to be a special PvP mode. Is it fully implemented, and how does it fit into the core progression loop? Should it be documented separately?

2. **Energy Balance**: High deployment costs (30+ energy) can take 20-30 seconds to materialize. Is this intended to make expensive units rare, or should there be a way to reduce deployment time?

3. **Recon Unit Stacking**: 5 scout units provide 50% drop bonus. Is this intended to be a powerful build-around, or is it exploitable?

4. **Star Rating Difficulty**: The jump from 2★ (50% survival) to 3★ (80% survival + time limit) is significant. Is this intended to make 3★ exclusive to skilled players, or should the curve be smoothed?

5. **Debug Logging**: The code contains extensive debug logging systems (`_dbg_ndjson`, `_agent_debug_log`). Are these for development only, or do they serve a production purpose?

## Acceptance Criteria

- **GIVEN** battle has started, **WHEN** player clicks valid deployment position with sufficient energy, **THEN** deploy ghost appears and unit materializes after deployment timer
- **GIVEN** player unit cap reached (5/5), **WHEN** player attempts deployment, **THEN** deployment fails with "max_units" signal
- **GIVEN** enemy wave timer reaches interval, **WHEN** enemy cap not reached, **THEN** new enemy wave spawns
- **GIVEN** all configured waves spawned and all enemies killed, **WHEN** check conditions, **THEN** battle ends in victory
- **GIVEN** phase field driver destroyed, **WHEN** signal received, **THEN** battle ends in defeat immediately
- **GIVEN** victory with 80%+ survival and fast time, **WHEN** stars calculated, **THEN** player awarded 3★
- **GIVEN** enemy unit killed, **WHEN** roll for drops, **THEN** may grant CARD_DATA, finished cards, blueprint data, and knowledge values based on chances
- **GIVEN** recon units on field, **WHEN** calculating drops, **THEN** knowledge gain amount and card drop quality increased
- **GIVEN** battle ends in victory, **WHEN** generating drops, **THEN** drop quality influenced by star rating

---

**Document Status**: Reverse-documented from existing implementation. Some sections (Game Feel, Visual/Audio) are design targets and may not yet be fully implemented in code.

**Notes**:
- This is a complex system with multiple interconnected subsystems. Consider splitting into separate GDDs for:
  - **Core Battle Flow** (start/end, victory conditions)
  - **Deployment System** (player unit spawning)
  - **Enemy Wave System** (enemy spawning logic)
  - **Combat Drops** (CARD_DATA / knowledge values rewards)
- The debug logging subsystems (`_dbg_ndjson`, `_agent_debug_log`) appear to be for A/B testing or analytics. Clarify if these are production systems.
