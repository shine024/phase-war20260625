---
status: reverse-documented
source: Full codebase (220 GDScript files)
date: 2026-04-08
verified-by: shine024
---

# Phase War — Project Architecture

> This document was reverse-engineered from the existing implementation.
> It captures current behavior and structure. Design intent is recorded as-is,
> not evaluated.

---

## 1. Overview

**Phase War** is a horizontal auto-battle strategy game built in Godot 4.5 with GDScript.
The player assembles weapon platforms from cards (platforms + weapons + energy + phase laws),
deploys them on a battlefield, and watches auto-combat resolve against enemy waves.

- **220 GDScript files**, ~66,000 lines of code
- **27 autoload singletons** + centralized SignalBus
- **100 levels** across 5 eras (WWI, WWII, Cold War, Modern, Near Future)
- **5 card types**: Platform, Weapon, Energy, Phase Law, Combined (synthesized)

---

## 2. Architectural Patterns

### 2.1 Service Locator (Autoload Singleton)

All game systems are autoloaded singletons registered in `project.godot`. Managers are
accessed via absolute scene tree paths:

```gdscript
var bm = get_node_or_null("/root/BlueprintManager")
if bm and bm.has_method("some_method"):
    bm.some_method()
```

**27 Autoloads by category:**

| Category | Autoloads |
|----------|-----------|
| Core Flow | `GameManager`, `BattleManager`, `BattleInputState` |
| Card/Blueprint | `BlueprintManager`, `PhaseInstrumentManager`, `AffixManager`, `CardCollectionManager` |
| Resource/Energy | `BasicResourceManager`, `EnergyManager`, `StatBoostManager`, `DropManager` |
| Meta Systems | `QuestManager`, `AchievementManager`, `DailyTaskManager`, `ChallengeModeManager`, `LevelProgressManager` |
| Narrative/Social | `FactionSystemManager`, `LoreManager`, `TutorialProgressionManager`, `StatisticsManager`, `CharacterManager` |
| Infrastructure | `SaveManager`, `SignalBus`, `DebugLog`, `AudioManager`, `ToastManager`, `VersionManager` |

### 2.2 Centralized Signal Bus

`SignalBus` is a single autoload containing ~40 signals organized by domain:

- **Energy**: `energy_changed`, `energy_insufficient`
- **Equipment**: `card_equipped`, `card_unequipped`, `phase_slots_changed`
- **Unit lifecycle**: `unit_spawned`, `unit_died`, `unit_damaged`, `unit_selected`
- **Battle flow**: `battle_started`, `battle_ended`, `wave_spawned`
- **Phase driver**: player/enemy HP changes and destruction
- **Cards**: `card_used`, `backpack_changed`, `card_added_to_backpack`, `card_equipped`
- **Blueprints/Drops**: `blueprint_unlocked`, `blueprint_star_upgraded`, `blueprint_obtained`, `dropped_card_obtained`, `drops_ready_to_claim`
- **Phase Laws**: `active_law_cast_at`, `phase_law_runtime_changed`, `phase_law_cast`
- **Achievements/Tasks**: unlock/progress/completion signals
- **Story**: chapter/node/choice/relationship signals
- **Audio**: `play_sound`

**Dual signal channel**: Some managers emit their own signals in addition to routing
through SignalBus. Consumers subscribe to both channels.

### 2.3 Data-Driven Design

**Two-tier data architecture:**

1. **Static Data Layer** (`data/*.gd`): `RefCounted` classes with `static func` accessors
   and `const` dictionaries. Pure data, no state.
   - `DefaultCards` — 27 platforms, 27 weapons, 10 energy cards, law card factories
   - `EnemyArchetypes` — 36 base + ~135 procedural variants across 5 eras
   - `PhaseLaws` — 24 laws across 4 families (STEEL, FLAME, THUNDER, VOID)
   - `PhaseInstruments` — 12 generic + 23 faction-specific, star levels 1-7

2. **Godot Resource Layer** (`resources/*.gd`): `Resource` subclasses for runtime data.
   - `CardResource` — Core card data object with ~25 `@export` fields
   - `UnitStats` — Computed battle stats + affix-derived properties

**Data flow**: Static data → `CardResource` instances → `UnitStats` (computed at deploy) → Runtime unit nodes.

### 2.4 Three-Phase State Machine

`GameManager` tracks `GamePhase` enum:

```
PRE_BATTLE → BATTLE → POST_BATTLE → PRE_BATTLE (loop)
```

`BattleManager` uses a simpler `battle_active: bool` with two battle modes:
- **Normal Wave Battle**: Wave timer drives spawning, win when all enemies/waves cleared
- **Phase Master Battle**: Continuous enemy spawning, win/lose by base destruction

---

## 3. System Dependency Graph

```
                    ┌─────────────┐
                    │  Main Scene  │
                    └──────┬──────┘
                           │
                    ┌──────▼──────┐
                    │ GameManager │◄──── BattleResult
                    └──────┬──────┘
                           │ go_to_battle()
                    ┌──────▼──────┐
                    │BattleManager│
                    └──────┬──────┘
              ┌────────────┼────────────────┐
              ▼            ▼                ▼
      ┌──────────────┐ ┌────────┐  ┌──────────────┐
      │EnergyManager │ │DropMgr │  │AffixManager  │
      └──────────────┘ └────────┘  └──────────────┘
              │
    ┌─────────┼──────────┐
    ▼         ▼          ▼
BlueprintMgr PhaseInstr  QuestMgr
    │         │          │
    ▼         ▼          ▼
BasicResMgr FactionMgr  LevelProgressMgr
    │
    ▼
SaveManager (hub: knows all 18+ managers)
```

**Cross-references**: There are 80+ `/root/ManagerName` absolute path references
across the codebase. `SaveManager.save_game()` manually collects state from 18+
managers; `load_game()` distributes it back.

---

## 4. Battle System

### 4.1 Battle Flow

| Trigger | Action |
|---------|--------|
| `start_battle(scene)` | Reset counters; get wave params from GameManager; if Phase Master, spawn enemy base; spawn preview ghosts; `EnergyManager.start_battle()`; emit `battle_started` |
| `_process(delta)` | Increment wave timer; spawn enemy wave when timer fires |
| `_on_unit_died()` → `_check_win_lose()` | Normal: win when all enemies dead + all waves spawned. Phase Master: win/lose by base destruction |
| `_on_phase_driver_destroyed()` | Player base destroyed → loss |
| `end_battle(player_won)` | Stop spawning; grant battle affixes; generate drops; clear units; emit `battle_ended` |

### 4.2 Player Unit Deployment

1. Check `battle_active`, unit cap (max 5), no duplicate card on field
2. Get loadout from `PhaseInstrumentManager` (platform + weapon cards)
3. Validate deploy position within 30% of battlefield from player side
4. Calculate energy cost: `cost = platform.energy_cost + SUM(weapon.energy_cost)`
5. Calculate deploy time: `deploy_time = cost / energy_output_rate`
6. Spend energy via `EnergyManager.spend(cost)`
7. Build `UnitStats` via `UnitStatsTable.build_multi_stats()`
8. Apply `BlueprintManager.apply_growth_to_stats()`
9. Apply `AffixManager.apply_affixes_to_stats()`
10. Instantiate unit as ghost → materialize after deploy_time

### 4.3 Enemy Wave Spawning

Timer-driven at `_enemy_wave_interval` (typically 12s, first wave at 3s):
- Classify archetypes by tag (basic / elite / boss)
- Last wave (if total > 3): spawn boss
- Every 3rd wave (wave > 1): spawn elite
- Other waves: spawn basic enemies
- Hard cap: `enemy_unit_count < 5`

### 4.4 Star Rating

| Stars | Condition |
|-------|-----------|
| 1 | Victory (always) |
| 2 | Victory AND `survival_rate >= 50%` |
| 3 | Victory AND `survival_rate >= 80%` AND `battle_time <= 70%` of estimated time |

---

## 5. Combat & Affix System

### 5.1 Stat Pipeline

```
Base stats (UnitStatsTable)
  + Blueprint growth (BlueprintManager)
  + Affix modifiers (AffixManager)
  = Final UnitStats
```

### 5.2 Affix Effects (14 types)

| Effect | Formula | Cap |
|--------|---------|-----|
| `max_hp` | `stats.max_hp *= (1 + val)` | — |
| `move_speed` | `stats.move_speed *= (1 + val)` | — |
| `attack_damage` | `stats.attack_damage *= (1 + val)` | — |
| `attack_range` | `stats.attack_range *= (1 + val)` | — |
| `attack_interval` | `stats.attack_interval *= max(0.1, 1 - val)` | — |
| `damage_reduction` | `stats.damage_reduction += val` | 0.75 |
| `crit_chance` | `stats.crit_chance += val` | 0.75 |
| `lifesteal` | `stats.lifesteal += val` | 0.60 |
| `splash_damage` | `stats.splash_damage += val` | 0.80 |
| `armor_penetration` | `stats.armor_penetration += val` | 0.80 |
| `chain_chance` | `stats.chain_chance += val` | 0.60 |
| `shield_on_kill` | `stats.shield_on_kill += val` | — |
| `hp_regen` | `stats.hp_regen += val` (fraction of max_hp/s) | — |

### 5.3 Affix Value Scaling

```
current_value = base_value * rarity_multiplier * level_factor
```

| Level | Factor |
|-------|--------|
| Lv1 | 1.0 |
| Lv2 | 1.25 |
| Lv3 | 1.55 |
| Lv4 | 1.95 |
| Lv5 | 2.5 |

| Rarity | Multiplier |
|--------|------------|
| common | 1.0 |
| rare | 1.3 |
| epic | 1.7 |
| legendary | 2.2 |

Phase Law passive bonus: `value *= (1 + (law_level - 1) * 0.02)`

### 5.4 Damage Calculation

```
1. Crit roll: if randf() < crit_chance → base_damage *= 1.5
2. effective_armor = defender.damage_reduction * (1 - attacker.armor_penetration)
3. final_damage = base_damage * (1 - effective_armor)
4. minimum final_damage = 0.1
```

### 5.5 Post-Damage Effects

| Effect | Trigger | Formula |
|--------|---------|---------|
| Lifesteal | Every hit | `heal = damage_dealt * lifesteal` |
| Splash | Every hit | `splash_dmg = damage * splash_damage`, 80px radius |
| Chain Lightning | Probabilistic (randf() < chain_chance) | 75% damage per hop, max 5 targets, 200px |
| Shield on Kill | Enemy death | `shield = max_hp * shield_on_kill` |
| HP Regen | Every frame | `heal = max_hp * hp_regen * delta` |

### 5.6 Mutation Effects (affix level 5, 25% chance)

| Affix | Mutation |
|-------|----------|
| weapon_dmg_up | 15% chance to deal double damage |
| weapon_atkspd_up | After 3 consecutive attacks, next +50% damage |
| crit_chance | Crit heals 5% max HP |
| lifesteal | When HP < 30%, lifesteal doubled |
| nano_regen | When HP < 50%, regen doubled |
| platform_hp_up | When HP > 80%, damage reduction +10% |

---

## 6. Energy System

### Constants

```
ENERGY_MAX = 100.0
ENERGY_START = 100.0
ENERGY_REGEN_PER_SEC = 1.0
PHASE_BASE_DRAIN_PER_SEC = 0.5
```

### Flow

```
Pre-Battle: Energy cards modify _base_start and _regen_per_sec
During Battle: net_regen = 1.0 + card_regen - 0.5 (per second, only positive)
Deploy: cost = platform.energy_cost + SUM(weapon.energy_cost)
         deploy_time = cost / energy_output_rate
Post-Battle: auto-recharge from energy blocks (1 block = 1 energy)
```

### Energy Card Types

| Type | Effect |
|------|--------|
| `energy_start_*` | +initial energy (era-scaled) |
| `energy_regen_*` | +regen per second (era-scaled) |
| `energy_hybrid` | +15 initial, +0.3/sec |
| 4+ energy slots | regen × 5.0 multiplier |

---

## 7. Drop & Reward Pipeline

### Drop Generation (on victory)

```
Battle ends (player wins)
  → _calculate_victory_stars()
  → DropManager.generate_battle_drops(era, level, won, stars)
      → If lost: grant 10-20 nano_materials only
      → If won:
          → Guaranteed: era-specific materials + 1 blueprint fragment
          → 3-star bonus: +1 extra blueprint fragment
          → Random: 1-3 weighted rolls from era pool
          → Resolve virtual IDs (era_N → real blueprint ID)
  → Per-enemy kill during battle:
      → _roll_blueprint_drops(): chance from enemy archetype
      → _roll_law_shard_drops(): 15%/30%/50% for basic/elite/boss
```

### Drop Types (10 types)

| Type | Processing |
|------|------------|
| `MATERIAL` | Added to BasicResourceManager |
| `BLUEPRINT_FRAGMENT` | Added as blueprint copy via BlueprintManager |
| `DROPPED_CARD` | Creates CardResource clone with random 1-9 star rating |
| `LORE_PAGE` | Unlocks lore entry in LoreManager |
| `CARD_REWARD` | Adds card to backpack via SignalBus |
| `ENERGY_CARD` | Adds card to backpack via SignalBus |
| `STAT_BOOST` | Applied via StatBoostManager |
| `LAW_BLUEPRINT` | Added as law shard via BlueprintManager |
| `LAW_CARD` | Creates full law card + shards + unlocks |
| `ENERGY_BLUEPRINT` | Resolves to era-appropriate energy card blueprint |

### Era Drop Progression

| Era | Nano | Alloy | Crystal | Notable Pool Items |
|-----|------|-------|---------|-------------------|
| WW1 | 30-50 | — | — | steel_quick_repair |
| WWII | 50-80 | — | — | flame_afterburn |
| Cold War | 70-100 | 15-20 | — | thunder_ion_net |
| Modern | 90-120 | 20-25 | — | void_phase_cloak, stat_boost |
| Near Future | 110-150 | 25-30 | 10-15 | void_time_ripple, 2× stat_boost |

### Recon Boost (in-combat)

Blueprint fragment bonus: `1.0 + (recon_count × 0.25)`, capped at +1.0

---

## 8. Phase Law System

### Law Categories

- **Passive**: Auto-apply effects based on environment matching
- **Active**: Player-triggered during battle (energy + nano cost)

### Environment System

4 dimensions: `weather`, `terrain`, `energy_field`, `time_of_day`

```
power_multiplier = 0.5 + (match_count / total_required_dims) * 0.5
  No requirements → 100% power
  0 matches       → 50% power
  All matches     → 100% power
```

### Active Law Casting Requirements

1. Law in equipped active list
2. Cast count < `max_cast_per_battle`
3. `current_energy >= battle_cost.energy`
4. `nano_materials >= battle_cost.nano`
5. `friendly_units >= min_friendly_units` (if specified)

### Passive Law Scaling

`value *= 1 + (law_level - 1) * 0.02` (2% per blueprint level above 1)

### Knowledge Tracks

4 tracks gate law research: `defense_knowledge`, `energy_knowledge`, `mobility_knowledge`, `mystic_knowledge`

---

## 9. Blueprint System

### Star Progression

- Cumulative threshold system (no fragment deduction), max 9★
- Two card paths: manufactured (blueprint system) and dropped (battle loot)
- Dropped cards also capped at 9★ (consistent with manufactured)

### Blueprint Fragment Flow

```
Enemy killed → roll drop chance → add copy to BlueprintManager
                            → check unlock threshold → auto-unlock if met
```

### Blueprint ↔ Law Mapping

Law blueprints use `law:` prefix convention: `"law:steel_quick_repair"`.
Legacy IDs are mapped via `LEGACY_LAW_CARD_ID_MAP`.

---

## 10. Quest System

- Max 5 simultaneous quests
- 16 objective types (win battles, kill enemies, collect fragments, etc.)
- Tracking modes: internal counters + real-time manager queries
- Rewards: blueprint fragments, nano materials, blueprint unlocks, faction reputation

---

## 11. Save System

`SaveManager` is a hub coordinating 18+ managers:

- `save_game()`: Collects state from all managers → serializes to `user://save.json`
- `load_game()`: Deserializes → distributes state to all managers
- Schema versioning: v1 → v2 → v3 with migration logic
- Legacy path resolution: `res://save.json` → old user path → `user://save.json`
- Includes migrations for: company reputation → faction system, blueprint nano materials → basic resources

**RESETTABLE_MANAGERS**: 18 managers listed for save/load/reset operations.

---

## 12. Technical Debt Inventory

### 12.1 Tight Coupling (80+ hard-coded paths)

Every inter-manager call uses `/root/ManagerName`. No dependency injection.

### 12.2 Dual Signal Channels

Managers emit both own signals and SignalBus signals. Consumers must subscribe to both.

### 12.3 SaveManager God Object

Knows internal state of 18+ managers. Any new manager requires manual SaveManager integration.

### 12.4 Monolithic Battle Rewards

`GameManager._on_battle_ended()` is ~422 lines handling victory/defeat, rewards for
7+ systems, faction changes, drops, and save triggering.

### 12.5 Defensive Programming Overhead

Hundreds of `get_node_or_null` + `has_method` guards mask real bugs by failing silently.

### 12.6 Legacy Debug Instrumentation

Multiple files contain hardcoded session ID debug logging (`_dbg()`, `_agent_debug_log()`)
scattered across managers.

### 12.7 Legacy Compatibility Code

- `BlueprintManager`: fragment → copy rename migration, legacy nano merge, default energy copies
- `SaveManager`: multi-version schema migration, legacy path resolution
- Dead code stubs: `upgrade_blueprint_level()` no-op with warning print

### 12.8 ID Convention Fragmentation

Law IDs use three conventions: raw (`"steel_quick_repair"`), prefixed (`"law:steel_quick_repair"`),
legacy (`"law_steel_passive_1"`). Scattered `begins_with("law:")` checks throughout.

### 12.9 Scaffold-Only Systems (11 managers)

DailyTaskManager, ChallengeModeManager, CardCollectionManager, StoryManager,
CharacterManager, StatisticsManager, LoreManager, TutorialManager,
TutorialProgressionManager, AudioManager, UIThemeManager — all autoloaded but
with minimal or no real implementation.

### 12.10 Stale/Backup Files

`save_manager_enhanced.gd`, `battle_system_enhanced.gd`, `battle_manager_addons.gd`,
`store_panel_backup.gd`, `new_functions_bar_addon.gd`, `comprehensive_system_verifier.gd`,
`cloud_save_manager.gd`, `social_system_manager.gd`, `mod_manager.gd` — likely
abandoned feature branches or incomplete refactors.

---

## 13. Key Formulas Reference

| Formula | Location |
|---------|----------|
| `current_value = base_value * rarity_mult * level_factor` | affix_resource.gd |
| `final_damage = base_damage * (1 - defender_dr * (1 - attacker_pen))` | affix_combat_handler.gd |
| `deploy_time = energy_cost / energy_output_rate` | battle_manager.gd |
| `net_regen = 1.0 + card_regen - 0.5` per second | energy_manager.gd |
| `power_mult = 0.5 + (env_matches / env_dims_required) * 0.5` | phase_law_manager.gd |
| `survival_rate = (max_deployed - lost) / max_deployed` | battle_manager.gd |
| `fragment_bonus = min(1.0, recon_units * 0.25)` | battle_manager.gd |
| `crit: damage *= 1.5 when randf() < crit_chance` | affix_combat_handler.gd |
| `splash: damage * splash_damage, 80px radius` | affix_combat_handler.gd |
| `chain: damage * 0.75, max 5 hops, 200px` | affix_combat_handler.gd |
| `passive law: value *= 1 + (lv - 1) * 0.02` | phase_law_manager.gd |
| `mutation trigger: 25% chance at affix level 5` | affix_definitions.gd |
