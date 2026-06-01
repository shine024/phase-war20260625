# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Project Overview

**Phase War** (相位战争) — tactical card strategy game. Players deploy historical military units (WWI to future eras) on a grid-based battlefield, manage card evolution, faction diplomacy, and intel-driven progression.

- **Engine**: Godot 4.5 (config_version=5)
- **Language**: GDScript
- **Resolution**: 1280x720, 60fps cap, `gl_compatibility` renderer
- **Entry scene**: `res://scenes/title_screen.tscn`
- **Main game scene**: `res://scenes/main.tscn`

## Godot CLI Commands

Godot not on PATH. Executable: `E:\下载\Godot_4.41\Godot_v4.5-stable_win64.exe`
Add `--rendering-driver opengl3` if Vulkan issues (applies to `--headless` / `--check-only` too).

```powershell
# Version check
& "E:\下载\Godot_4.41\Godot_v4.5-stable_win64.exe" --path "." --version

# Project validation (no UI, recommended)
& "E:\下载\Godot_4.41\Godot_v4.5-stable_win64.exe" --headless --rendering-driver opengl3 --path "." --check-only

# Smoke test (no GdUnit dependency)
& "E:\下载\Godot_4.41\Godot_v4.5-stable_win64.exe" --headless --rendering-driver opengl3 --path "." --script "tests/star_config_smoke.gd"

# Full GdUnit test suite
& "E:\下载\Godot_4.41\Godot_v4.5-stable_win64.exe" --headless --rendering-driver opengl3 --path "." --script "tests/gdunit4_runner.gd"
```

## Architecture

### Autoload Singletons (21 total, in load order)

**Core (always loaded):**
| Singleton | File | Role |
|---|---|---|
| `SignalBus` | `scripts/signal_bus.gd` | Central event bus (~80 signals). All cross-system comms go here. |
| `BattleInputState` | `scripts/battle_input_state.gd` | Battle input state machine |
| `EnergyManager` | `managers/energy_manager.gd` | Battle energy pool |
| `PhaseInstrumentManager` | `managers/phase_instrument_manager.gd` | 4-color equipment slots + phase field XP |
| `BattleManager` | `managers/battle/battle_manager.gd` | Battle orchestration, delegates to Spawn/Damage subsystems |
| `GameManager` | `managers/game_manager.gd` | Game phase: pre-battle → battle → post-battle |
| `BlueprintManager` | `managers/blueprint_manager.gd` | Card account progression (copies, stars, mods, evolution) |
| `DropManager` | `managers/drop_manager.gd` | Post-battle drop tables and claiming |
| `SaveManager` | `managers/save_manager.gd` | `user://save.json`, 3 slots, schema v3, migration chain |
| `AudioManager` | `managers/audio_manager.gd` | Audio |
| `PhaseLawManager` | `managers/phase_law_manager.gd` | Law research, equipping, battle state |
| `BasicResourceManager` | `managers/basic_resource_manager.gd` | Global currencies (nano materials, alloy, crystal, energy blocks, license) |
| `ObjectPoolManager` | `managers/object_pool.gd` | Object pool for bullets, damage numbers |
| `UILazyLoader` | `managers/ui_lazy_loader.gd` | On-demand UI panel loading |
| `ManagerLazyLoader` | `managers/manager_lazy_loader.gd` | On-demand non-core manager loading |
| `PerformanceMetricsManager` | `managers/performance_metrics_manager.gd` | FPS/performance sampling |
| `IntelManual` | `scripts/systems/intel_manual.gd` | Intel 4-dimension progress |
| `IntelItemBag` | `managers/intel_item_bag.gd` | Intel item inventory |
| `IntelDiscoveryManager` | `scripts/systems/intel_discovery_manager.gd` | Battle harvest, reveal events |
| `IntelEvolutionManager` | `scripts/systems/intel_evolution_manager.gd` | Evolution branch discovery |
| `EnemyOriginModManager` | `scripts/systems/enemy_origin_mod_manager.gd` | Enemy origin mods |

**Lazy-loaded managers** (via `ManagerLazyLoader.ensure_loaded()`):
`AuraManager`, `LevelProgressManager`, `QuestManager`, `AchievementManager`, `LoreManager`, `StatBoostManager`, `CardEnhancementManager`, `TutorialProgressionManager`, `StoryManager`, `CharacterManager`, `ChallengeModeManager`, `CardCollectionManager`, `LeaderboardManager`, `DailyTaskManager`, `FactionSystemManager`, etc.

### Key Patterns

1. **SignalBus decoupling**: All cross-system communication via `SignalBus.signal_name.connect()` / `.emit()`. Managers never hold direct references to each other for events.

2. **Resource-based card model**: `CardResource` (extends Resource) is the unified data type for cards, units, and progression. All cards created programmatically in `data/default_cards.gd` — no `.tres` files.

3. **Lazy loading**: Two tiers — `UILazyLoader` for UI panels, `ManagerLazyLoader` for non-core managers. Expensive init uses `call_deferred()`.

4. **Subsystem decomposition**: Large managers (`BattleManager`, `BlueprintManager`, `FactionSystemManager`) use `RefCounted` static sub-modules to separate concerns.

5. **Data-as-code**: All game data tables are pure GDScript static classes (`extends RefCounted`) with `Dictionary` collections. No JSON/CSV data files.

6. **Era scaling**: Units scale by era (WWI → Future). `UnitStatsTable.build_stats_from_card()` applies era multipliers.

### System Dependencies

```
GameManager → BattleManager, BlueprintManager, PhaseInstrumentManager,
               PhaseLawManager, BasicResourceManager, LevelProgressManager,
               FactionSystemManager, DropManager, QuestManager

BattleManager → BattleSpawnSystem, BattleDamageSystem, EnergyManager,
                 PhaseInstrumentManager, GameManager, SpatialGrid, SignalBus

SaveManager → ALL managers (loads/saves their state sections)

BlueprintManager → CardEvolutionManager, ModManager, EvolutionHelpers,
                    DefaultCards, PhaseLaws, UnitStatsTable
```

### Battle Flow

1. `GameManager.go_to_battle()` → `BattleManager.start_battle(scene)`
2. Per-frame: wave spawning + win/lose check
3. `SignalBus.battle_ended.emit(player_won)` → `GameManager._on_battle_ended()` handles rewards, progression, save

### Scene Structure

- `scenes/main.tscn` — `BattleContainer` + `HudLayer` (CanvasLayer 40) + `PopupLayer` (CanvasLayer 100)
- `scenes/battlefield/battlefield.tscn` — Battlefield rendering
- `scenes/ui/` — ~65 UI panel scripts (backpack, store, faction, quest, achievement, etc.)
- `scenes/units/` — `construct_unit`, `enemy_unit`, `phase_field_driver`, `bullet`
- `scenes/effects/` — Damage numbers, screen shake, cast effects

### Data Layer (`data/`)

Key data files (all `extends RefCounted`, static):
- `default_cards.gd` — ~110 battle unit definitions (WWI to future)
- `enemy_archetypes.gd` — Enemy types, drops, nano material drops
- `phase_laws.gd` — Law definitions (4 families: STEEL/FLAME/THUNDER/VOID)
- `affix_definitions.gd` — Affix definition table
- `blueprint_star_config.gd` — Star upgrade costs, mod costs, license rules
- `battle_card_v3.gd` — Era HP/damage multipliers
- `level_eras.gd` — Level-to-era mapping, wave parameters

### Resource Types (`resources/`)

- `CardResource` — Unified card model (unit/energy/law types), evolution, affix slots, mods
- `AffixResource` — Card modifiers with rarity, level scaling, stat caps
- `UnitStats` / `UnitStatsTable` — Derived combat stats from CardResource
- `GameConstants` — All enums: CardType, WeaponType, CombatKind, etc.
- `DropTables` — Weighted drop entries and tables
- `DesignTokens` — UI theming constants

### Test Structure

Framework: GdUnit4 (`addons/gdunit4/`)

```
tests/
  unit/
    blueprint/    — blueprint star config
    combat/       — affix scaling, card grid damage, damage calc, enemy stat resolver
    data/         — battle card v3, enemy archetypes, level info
    economy/      — drop tables, energy economy
    energy/       — energy manager
    progression/  — evolution HP floor, unit lineage
    resources/    — basic resource manager
    save/         — save integrity, save migration
  star_config_smoke.gd   — Quick smoke test (no GdUnit)
  syntax_check.gd         — Syntax validation
  gdunit4_runner.gd       — CI test runner entry point
```

### Save System

- Single JSON file: `user://save.json`, 3 save slots
- Schema version 3, migration chain v1→v2→v3 via `scripts/systems/save_migration.gd`
- Critical managers load first, others lazy-load

## Engine Version Notes

LLM training data covers Godot up to ~4.3. This project uses Godot 4.5.
Check `docs/engine-reference/godot/VERSION.md` before suggesting API calls.

## Collaboration Protocol

User-driven collaboration. Every task follows: **Question → Options → Decision → Draft → Approval**

- Ask before writing to any filepath
- Show drafts before requesting approval
- Multi-file changes need explicit approval for the full changeset
- No commits without user instruction
