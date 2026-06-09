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

### Autoload Singletons (19 total, in project.godot load order)

**Core autoloaded singletons (always loaded at startup):**
| # | Singleton | File | Role |
|---|---|---|---| 
| 1 | `SignalBus` | `scripts/signal_bus.gd` | Central event bus (~80+ signals). All cross-system comms go here. |
| 2 | `BattleInputState` | `scripts/battle_input_state.gd` | Battle input state machine |
| 3 | `EnergyManager` | `managers/energy_manager.gd` | Battle energy pool; cap = equipped energy card star × 100 |
| 4 | `PhaseInstrumentManager` | `managers/phase_instrument_manager.gd` | 4-color equipment slots (red/blue/green/yellow) + phase field XP (Lv1-16) |
| 5 | `BattleManager` | `managers/battle/battle_manager.gd` | Battle orchestration, delegates to BattleSpawnSystem + BattleDamageSystem |
| 6 | `GameManager` | `managers/game_manager.gd` | Game flow: pre-battle → battle → post-battle; 15% phase master encounter |
| 7 | `BlueprintManager` | `managers/blueprint_manager.gd` | Card account progression (copies, stars, mods, evolution, inherit bonus, HP floor) |
| 8 | `DropManager` | `managers/drop_manager.gd` | Post-battle drop tables (13 drop types) and claiming |
| 9 | `SaveManager` | `managers/save_manager.gd` | `user://save.json`, 3 slots, schema v5, migration chain v1→v5 |
| 10 | `AudioManager` | `managers/audio_manager.gd` | Audio |
| 11 | `PhaseLawManager` | `managers/phase_law_manager.gd` | Law research/equip/battle state; 4 families (STEEL/FLAME/THUNDER/VOID); nano budget |
| 12 | `BasicResourceManager` | `managers/basic_resource_manager.gd` | Global currencies (nano materials, alloy, crystal, energy blocks, research points, permits) |
| 13 | `ObjectPoolManager` | `managers/object_pool.gd` | Object pool for bullets (25), damage numbers (15) |
| 14 | `UILazyLoader` | `managers/ui_lazy_loader.gd` | On-demand UI panel loading (18 panels) |
| 15 | `ManagerLazyLoader` | `managers/manager_lazy_loader.gd` | On-demand non-core manager loading (20+ managers, priority 1-10) |
| 16 | `PerformanceMetricsManager` | `managers/performance_metrics_manager.gd` | FPS/performance sampling |
| 17 | `ModificationRegistry` | `scripts/systems/modification_registry.gd` | 140+ modification modules across 9 unit types (autoload, static registry) |
| 18 | `MilitaryTitleRegistry` | `scripts/systems/military_title_registry.gd` | Unified rank system (13 ranks, per combat_kind, via UnifiedRankSystem) |
| 19 | `EvolutionPathRegistry` | `scripts/systems/evolution_path_registry.gd` | 8 unit-type evolution paths (main line + hidden branches) |

**Lazy-loaded managers** (via `ManagerLazyLoader.ensure_loaded()`, 20 total):

| Priority | Manager ID | Node Name | Description |
|----------|-----------|-----------|-------------|
| 1 | `aura` | `AuraManager` | Aura system |
| 1 | `battle_feedback` | `BattleFeedbackManager` | Battle feedback |
| 1 | `level_progress` | `LevelProgressManager` | Level progress |
| 2 | `quest` | `QuestManager` | Quest system |
| 2 | `achievement` | `AchievementManager` | Achievement system |
| 2 | `daily_task` | `DailyTaskManager` | Daily tasks |
| 2 | `challenge_mode` | `ChallengeModeManager` | Challenge mode |
| 3 | `faction` | `FactionSystemManager` | 7-faction system (reputation/shop/skill/events/card-gen) |
| 3 | `affix` | `AffixManager` | Modular affix management (acquire/upgrade/reroll/lock; boss-unlocked affix pool) |
| 4 | `card_collection` | `CardCollectionManager` | Card collection |
| 4 | `stat_boost` | `StatBoostManager` | Stat boosts |
| 5 | `statistics` | `StatisticsManager` | Statistics |
| 5 | `leaderboard` | `LeaderboardManager` | Leaderboard |
| 6 | `lore` | `LoreManager` | Lore |
| 6 | `story` | `StoryManager` | Story |
| 6 | `character` | `CharacterManager` | Character management |
| 7 | `tutorial` | `TutorialProgressionManager` | Tutorial |
| 8 | `new_systems` | `NewSystemsIntegration` | New systems integration |
| 9 | `toast` | `ToastManager` | Toast notifications |
| 9 | `version` | `VersionManager` | Version management |
| 99 | `debug_log` | `DebugLog` | Debug logging |

**v6.0 情报系统管理器** (已移至延迟加载):
- `IntelManual` — 4维情报系统（basic/tactical/material/secret）
- `IntelItemBag` — 情报道具背包（6种消耗品）
- `IntelDiscoveryManager` — 战利品发现系统（112个揭示事件）
- `IntelEvolutionManager` — 情报进化分支（4条隐藏分支）
- `EnemyOriginModManager` — 敌源MOD系统（9种敌源MOD）
- `CardEnhancementManager` — 卡牌强化系统（Lv1-10，词条选择）

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
                 PhaseInstrumentManager, GameManager, SpatialGrid, SignalBus,
                 IntelDiscoveryManager (v6.0 defeated enemy recording)

SaveManager → ALL managers (loads/saves their state sections)
              Critical: BlueprintManager, PhaseInstrumentManager, PhaseLawManager,
              QuestManager, BasicResourceManager, FactionSystemManager, AffixManager,
              LevelProgressManager, DropManager, IntelItemBag
              Deferred: LoreManager, StatBoostManager, AchievementManager,
              DailyTaskManager, StatisticsManager, CardEnhancementManager, etc.

BlueprintManager → CardEvolutionManager, ModManager, EvolutionHelpers,
                    DefaultCards, PhaseLaws, UnitStatsTable, RankRules

CardEnhancementManager → DefaultCards, UnifiedRankSystem (military titles)

ModificationRegistry → 9 unit-type mod modules (infantry/armor/artillery/anti_air/air/recon/engineer/fort/universal)

EvolutionPathRegistry → 8 unit-type evolution modules (infantry/armor/air/artillery/fort/recon/engineer/anti_air)

FactionSystemManager → FactionReputation, FactionShop, FactionSkillManager,
                        FactionEventManager, FactionCardGenerator, SynthesisManager

IntelDiscoveryManager → IntelManual, IntelDimensions, IntelRevealEvents, EnemyOriginMods
IntelEvolutionManager → IntelManual, IntelEvolutionBranches
EnemyOriginModManager → IntelManual, IntelDimensions, EnemyOriginMods
```

### Battle Flow

1. `GameManager.go_to_battle()` → `BattleManager.start_battle(scene)`
2. Per-frame: wave spawning + win/lose check
3. `SignalBus.battle_ended.emit(player_won)` → `GameManager._on_battle_ended()` handles rewards, progression, save

### Scene Structure

- `scenes/main.tscn` — `BattleContainer` + `HudLayer` (CanvasLayer 40) + `PopupLayer` (CanvasLayer 100)
- `scenes/battlefield/battlefield.tscn` — Battlefield rendering + battle slot grid
- `scenes/ui/` — ~65+ UI panel scripts (backpack, store, faction, quest, achievement, evolution, enhancement, modification, affix, intel hub, leaderboard, daily task, etc.)
- `scenes/units/` — `construct_unit` (player), `enemy_unit`, `phase_field_driver` (base), `enemy_phase_field_driver`, `bullet`, `swarm_enemy_controller`, `unit_hp_bar`
- `scenes/effects/` — Damage numbers, screen shake, cast effects, law target indicator, battle audio/effects systems
- `scripts/battle/` — `attack_calculator`, `construct_unit_ai`, `construct_unit_deploy`, `damage_attenuation`, `target_selection`

### Data Layer (`data/`)

All data files are pure GDScript static classes (`extends RefCounted`), no JSON/CSV.

**Core Cards & Enemies:**
- `default_cards.gd` — ~110 battle unit definitions (WWI to near-future, 5 eras × 20 levels)
- `enemy_archetypes.gd` (+ era-split variants: `_ww.gd`, `_cold_modern.gd`, `_future.gd`) — Enemy types, drops
- `enemy_phase_masters*.gd` (5 era files + combined) — Phase master (boss) definitions
- `enemy_equipment_*.gd` — Enemy weapons, armor modules, specials
- `enemy_blueprints.gd`, `enemy_unit_manifest.gd`, `enemy_stat_context.gd`, `enemy_stat_resolver.gd`

**Law & Environment:**
- `phase_laws.gd` — Law definitions (4 families: STEEL/FLAME/THUNDER/VOID, passive + active)
- `battle_environments.gd` — Battlefield environment modifiers
- `phase_instruments.gd` — Phase instrument definitions (4-color slot configs)

**Economy & Progression:**
- `basic_resources.gd` — Resource ID definitions (nano/alloy/crystal/energy block/research points/permits)
- `blueprint_star_config.gd` — Star upgrade costs, mod costs, permit rules
- `battle_card_v3.gd` — Era HP/damage multipliers (v6.1: 近未来伤害倍率 1.90→1.80)
- `level_eras.gd` / `level_information.gd` — Level-to-era mapping (100 levels, 5 eras)
- `rank_rules.gd`, `card_progression_settings.gd` — Progression tuning

**v6.0 Intel System:**
- `intel_dimensions.gd` — 4 intel dimensions (basic/tactical/material/secret)
- `intel_reveal_events.gd` — 112 reveal events (7 enemy types × 4 dimensions × 4 tiers)
- `intel_evolution_branches.gd` — 4 hidden evolution branches
- `intel_manual_items.gd` — 6 intel consumable items
- `enemy_origin_mods.gd` — 9 enemy-origin MOD definitions

**Evolution:**
- `data/evolution_paths/` — 8 files: infantry/armor/air/artillery/fort/recon/engineer/anti_air evolution paths
- `unit_lineage_config.gd` — Unit lineage and evolution target mapping
- `evolution_paths_supplement.gd` — Supplementary evolution data

**Modification:**
- `data/modification_modules/` — 9 files: infantry/armor/artillery/anti_air/air/recon/engineer/fort/universal mods (140+ total)
- `mod_effects.gd` — Mod effect definitions and slot cost formulas

**Military Titles:**
- `data/military_titles/unified_rank_system.gd` — Unified rank system (13 ranks, power multipliers)
- `data/military_titles/title_display_names.gd` — Rank display names per combat_kind

**Faction:**
- `company_definitions.gd` — 7 faction definitions
- `faction_card_bonuses.gd`, `faction_exclusive_cards.gd`, `faction_skill_tree.gd`, `faction_war_events.gd`
- `synthesis_recipes.gd` — Hybrid card synthesis recipes

**Quest/Achievement/Challenge:**
- `quest_definitions.gd`, `achievement_definitions*.gd` (4 files), `challenge_definitions.gd`, `task_definitions_extended.gd`, `daily_task_definitions.gd`

### Resource Types (`resources/`)

- `CardResource` — Unified card model (combat_unit/energy/law), evolution, affix slots, mods, per-target attack speeds (v5.0)
- `AffixResource` — Modular affix with rarity, level scaling, stat caps
- `UnitStats` / `UnitStatsTable` — Derived combat stats from CardResource with era scaling
- `GameConstants` — All enums: CardType(3), WeaponType(4), CombatKind(5), Era(5), PlatformType(13, deprecated), WeaponTypeLegacy(12, deprecated)
- `DropTables` — Weighted drop entries (13 drop types), tables, guarantee drops
- `DesignTokens` — UI theming constants (neon palette, typography, spacing, glow, accessibility)
- `GameConfig` — Tunable game config (battle/economy/UI/performance/debug)

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
    managers/     — core managers (BlueprintManager, SaveManager, BattleManager, GameManager)
    progression/  — evolution HP floor, unit lineage
    resources/    — basic resource manager
    save/         — save integrity, save migration
  star_config_smoke.gd   — Quick smoke test (no GdUnit)
  syntax_check.gd         — Syntax validation
  gdunit4_runner.gd       — CI test runner entry point
```

### Save System

- Single JSON file: `user://save.json`, 3 save slots
- Schema version 5, migration chain v1→v2→v3→v4→v5 via `scripts/systems/save_migration.gd` + `save_migration_v4.gd` + `save_migration_v5.gd`
- Critical managers (10) load immediately; deferred managers (12) load in batches after scene ready
- Auto-save on battle end + window close; backup every 15s

## v6.1 UI修复记录 (2026-06-09)

**UI面板尺寸优化**:
1. card_enhancement_panel: 1200x640 → 1000x580
2. achievement_panel: 修复硬编码偏移量，改用居中布局 600x500
3. level_select_panel: 900x700 → 760x580
4. intelligence_hub_panel: 920x620 → 840x580
5. drops_inventory_panel: 添加尺寸定义 800x520

**UI布局优化**:
1. backpack_panel: Grid列数 17 → 12
2. affix_panel: 修复文本硬编码换行
3. modification_panel: 添加完整样式定义 960x600

**文档创建**:
- `docs/UI_AUDIT_REPORT.md` - UI检查报告
- `docs/UI_DESIGN_GUIDELINES.md` - UI设计规范
- `docs/UI_FIX_SUMMARY.md` - UI修复总结

## Engine Version Notes

LLM training data covers Godot up to ~4.3. This project uses Godot 4.5.
Check `docs/engine-reference/godot/VERSION.md` before suggesting API calls.

## Collaboration Protocol

User-driven collaboration. Every task follows: **Question → Options → Decision → Draft → Approval**

- Ask before writing to any filepath
- Show drafts before requesting approval
- Multi-file changes need explicit approval for the full changeset
- No commits without user instruction

## v6.1 平衡性调整记录 (2026-06-08)

**单位平衡性调整:**
1. 降低近未来伤害倍率：1.90 → 1.80 (battle_card_v3.gd)
2. 调整T-72/M1 HP关系：T-72 850→800，M1 800→850 (default_cards.gd)

**MOD平衡性调整:**
1. aa_01_radar：attack_interval -50% → -30% (已完成于v6.0)
2. art_06_fire_computer：attack_interval -40% → -30% (已完成于v6.0)
3. art_09_rapid_fire：attack_interval -30% → -20% (已完成于v6.0)
4. arm_06_apfsds：attack_armor +35% → +30% (已完成于v6.0)
5. aa_04_quad_mount：attack_interval -35% → -30% (v6.1新增)
6. aa_11_auto_fc：attack_interval -50% → -40% (v6.1新增)
7. air_05_helmet_sight：attack_interval -50% → -40% (v6.1新增)

**性能优化:**
1. 增加对象池大小：子弹池 2→25，伤害数字池 4→15 (object_pool.gd)

**架构修复:**
1. 移除7个重复的autoload配置，改用ManagerLazyLoader延迟加载 (project.godot)
2. 修复BattleManager依赖注入，使用运行时get_node_or_null() (battle_manager.gd)

**UI修复:**
1. 修复UILazyLoader配置：删除不存在的blueprint_workshop和blueprint_library配置
2. 统一路径字段命名：全部使用parent_path
3. 在main.tscn中添加11个缺失的Overlay容器
