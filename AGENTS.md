# AGENTS.md

This file provides guidance to Codex (Codex.ai/code) when working with code in this repository.

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

### Autoload Singletons (24 total, in project.godot load order)

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
| 9 | `SaveManager` | `managers/save_manager.gd` | `user://save.json`, 3 slots, schema v6, migration chain v1→v6 |
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
| 20 | `InstanceRegistry` | `managers/instance_registry.gd` | **v7.x 卡牌养成核心**：所有玩家拥有的卡的实例（card_id#N）+ 养成数据。养成隔离的单一真身。改任何卡牌/养成代码前必读下方"⚠️ 核心架构"章节 |

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

**v6.0 情报系统管理器** (project.godot autoload，同时在 ManagerLazyLoader 保留 ensure_loaded 别名入口):
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

★ InstanceRegistry (v7.x 核心，autoload) → 所有"卡牌实例 + 养成数据"的唯一真身
  └─ 被 BlueprintManager/CardEnhancementManager/store_panel/drop_manager/
     phase_instrument_manager/battle_spawn_system/所有养成面板 依赖
  └─ 详见下方"⚠️ 核心架构：卡牌实例化与养成隔离"——改任何卡牌/养成代码前必读
```

### ⚠️ 改卡牌/养成代码前必读

**`InstanceRegistry` 是 v7.x 卡牌养成隔离的核心（autoload `/root/InstanceRegistry`）。** 它持有所有"玩家拥有的卡"的实例（`card_id#N` 带独立养成数据）。`DefaultCards.get_card_by_id()` 返回的是**只读共享模板**，**严禁**直接改其 enhance_level/mods 等养成字段（会导致所有同名卡被污染）。养成操作必须通过实例卡。详见下方"⚠️ 核心架构：卡牌实例化与养成隔离"章节的三大铁律。

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
- Schema version 6, migration chain v1→v2→v3→v4→v5→v6 via `scripts/systems/save_migration.gd` + `save_migration_v4.gd` + `save_migration_v5.gd` + `save_migration_v6.gd`
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

## v6.6 7星相位仪主动能力 (2026-06-20)

**新增能力系统**: 相位仪 `active_ability` 字段（之前 special_traits 是纯文本，无战斗实现）

**7个能力分配到各势力7星相位仪（含低星降级版）:**

| 能力 | 7星完整版 | 分配相位仪 | 低星降级 |
|------|----------|-----------|----------|
| 火炮连发 | 每10秒连发7发(间隔1秒) | pi_nova_03(新星-超弦) | 6星:15秒/5发, 4星:20秒/3发 |
| 幻影克隆 | 同卡可放2个,克隆体+100%攻/+80%血 | pi_helix_04(螺旋-幻影核,新增) | 5星:+50%/+40%, 3星:+20% |
| 直射穿透 | 100%穿透,每穿一个衰减10% | pi_umbra_04(影幕-虚空穿,新增) | 6星:70%, 3星:40% |
| 免能量 | 部署完全免能量 | pi_atlas_04(擎天-零点能,新增) | 6星:-50%, 4星:-30% |
| 核子轰炸 | 每30秒敌方全体轰炸 | pi_eon_03(永纪-终式) | 5星:45秒, 2星:60秒减半 |
| 致命酸雨 | 开局30秒敌方每秒掉2%血 | pi_aegis_04(神盾-壁垒核) | 6星:20秒, 4星:12秒 |
| 巨型能量罩 | 开局我方全体20000护盾 | pi_generic_12(天穹VII型) | 6星:10000, 4星:5000 |

**关键文件:**
- `data/phase_instruments.gd` — 7个ability_xxx(star)定义 + active_ability字段 + 3个新7星 + 低星降级
- `managers/battle/phase_instrument_abilities.gd`(新增) — periodic/on_battle_start能力触发
- `managers/battle/battle_manager.gd` — start_battle/on_battle_start + _process/update接入
- `managers/battle/battle_spawn_system.gd` — 免能量+幻影部署+克隆体加成
- `scripts/battle/attack_calculator.gd` — 直射穿透比例
- `managers/phase_instrument_manager.gd` — get_active_ability()

## v6.6 改造效果↔战斗卡属性关联修复 (2026-06-20)

**问题**: `ModificationRegistry._apply_single_mod_effects()` 的 match 分支是改造效果应用的唯一闸门；落入 `default` 分支的 effect key 被塞进 `result["_special"]`，而 `unit_stats_table._apply_mod_stat_effects()` 完全不读 `_special`（注释自承认"暂不处理"），导致一批改造在战斗中空转。

**修复范围**: A类——5个真正属于战斗卡属性范畴的缺口（涉及 art_04/05/11、eng_02、aa_05、gen_09、aa_09、air_08 共8个改造模块）。B/C类约30个 key（环境/情报/经济/光环/战术机制类，如 night_bonus/vision/ally_*/multi_target/missile_intercept 等）有意保留现状——它们本就不属于战斗卡属性范畴，强行映射会语义错位，留待对应系统实现时再接。

**5个修复点:**

| effect key | 修复方式 | 涉及改造 |
|-----------|---------|----------|
| `attack_fort` | 新增条件型字段 `attack_fort_bonus`，FORT目标在 get_attack_vs() 叠加（复用 armor_pen_vs_* 模式） | art_11温压弹+50%、eng_02爆破+40% |
| `splash_radius` | 新增 `splash_radius_bonus`，_apply_splash 半径改为 80×(1+bonus) | art_04子母弹+50%、aa_05近炸+30% |
| `single_target_penalty` | 新增字段，主目标伤害×(1+penalty)，放在暴击后溅射前，maxf(0,...)防负 | art_04子母弹-20% |
| `missile_dodge` | 映射为 dodge_chance（反导语义同源） | air_08/aa_09/gen_09 +0.25~0.30 |
| `counter_bonus` | 映射为 crit_chance（"精确还击"语义） | art_05反炮兵雷达+30% |

**关键文件:**
- `resources/unit_stats.gd` — 新增3字段：attack_fort_bonus / splash_radius_bonus / single_target_penalty
- `scripts/systems/modification_registry.gd` — _apply_single_mod_effects match增加5个分支
- `resources/unit_stats_table.gd` — _apply_mod_stat_effects 增加3字段的 base_dict + 写回
- `scripts/battle/attack_calculator.gd` — get_attack_vs() FORT分支叠加 attack_fort_bonus
- `scripts/battle/module_effect_handler.gd` — _apply_splash 动态半径 + on_bullet_hit 应用 single_target_penalty

**设计决策:**
1. attack_fort 用条件型字段而非新攻击维度——FORT仍走ARMOR维度，仅叠加条件加成，零侵入
2. single_target_penalty 放暴击后/溅射前——只惩罚主目标不影响溅射伤害，符合子母弹"散布换精度"语义
3. 向后兼容——3个新字段默认0，未装备相关改造时行为与改动前完全一致

**平衡性:** 8个改造数值全部通过复核。2处WARN（aa_05双重激活、missile_dodge系列dodge量级偏高）均为"从空转激活"而非叠加超模，有 min(1.0) 上限保护且与 power_mult 匹配，建议后续实机观察。

**验证说明:** Godot headless --check-only 因项目体量（133卡+19 autoload）5分钟超时（引擎成功启动到DefaultCards构建阶段，autoload链路无语法错误），改为静态一致性核对（Grep确认3字段全链路拼写一致+5个match key完整+缩进正确）——全部通过。

## v6.6 全面一致性修复 (2026-06-21)

基于全项目数据一致性/功能贯通性/UI属性衔接性审查，修复 5 个 CRITICAL + 1 个 HIGH 问题。

**修复点:**

| 编号 | 问题 | 修复 |
|------|------|------|
| C1 | 情报4 manager（IntelManual/IntelDiscoveryManager/IntelEvolutionManager/EnemyOriginModManager）进度不存档，重启丢失 | 新增 save_state/load_state 接口 + 注册到 SaveManager（critical+deferred）+ SK_常量；旧独立文件兼容读取 |
| C2 | SignalBus.show_toast 全程无连接，所有 toast 提示静默失效 | ToastManager._ready 连接 SignalBus.show_toast + save_manager 预加载 ToastManager |
| C3 | world_map_panel.tscn 缺失（UILazyLoader 配置死链） | 删除 ui_lazy_loader 的 map 配置（功能由 main.tscn 内联节点承担，lazy-load 永不触发） |
| C4 | 5 个信号（quest_completed/task_completed/achievement_unlocked/achievement_progress_updated/daily_tasks_refreshed）被 connect 但从不 emit，任务/成就完成 UI 不刷新 | 各 manager 在本地 signal.emit 后追加 SignalBus 镜像 emit |
| C5 | weapon_type 两套枚举混用：改造写入 legacy 值(5/6/9)污染 weapon_type 弹道字段，导弹(9)被 AI 误判为直射 | 新增 GC.is_indirect_weapon_type() 统一曲射判定（含 ROCKET/FLAK/MISSILE）；改造改写 legacy_weapon_type 字段（不污染 weapon_type）；bullet 传值优先 legacy |
| H1 | 情报5 manager 三重注册（autoload + lazy_loader + CORE 不同步） | 保留 lazy_loader 配置作 ensure_loaded 入口（4处调用依赖），加注释澄清 autoload+别名双层设计 |

**关键文件:**
- `scripts/systems/intel_manual.gd` / `intel_discovery_manager.gd` / `intel_evolution_manager.gd` / `enemy_origin_mod_manager.gd` — save_state/load_state + 去 _ready 自加载
- `managers/save_manager.gd` — 注册4 manager（CRITICAL/DEFERRED/RESETTABLE + SK_常量）+ 预加载 ToastManager
- `scripts/systems/save_constants.gd` — 4 个情报 SK_ 常量
- `managers/toast_manager.gd` — _ready 连接 show_toast
- `managers/ui_lazy_loader.gd` — 删 map 死配置
- `managers/quest_manager.gd` / `daily_task_manager.gd` / `achievement_manager.gd` — 补 SignalBus 镜像 emit
- `resources/game_constants.gd` — is_indirect_weapon_type() 辅助函数
- `scripts/battle/construct_unit_ai.gd` / `scenes/units/enemy_unit.gd` — 曲射判断改用统一辅助函数 + bullet 传值优先 legacy
- `scripts/systems/modification_registry.gd` / `resources/unit_stats_table.gd` — weapon_type key 改写 legacy_weapon_type
- `managers/manager_lazy_loader.gd` — intel 配置加 autoload 别名注释

**设计决策:**
1. C1 完全切换统一存档（清空字段重置），load_state 收到空字典时兼容读取旧独立文件（首次迁移不丢进度）
2. C5 用统一辅助函数而非分离双字段重构——改造写入 legacy_weapon_type（已存在字段），AI 判断用 is_indirect_weapon_type 扩展范围，bullet 传值优先 legacy，最小改动覆盖全链路
3. H1 保留 lazy_loader 配置（4处 ensure_loaded 调用依赖），仅加注释澄清——删除会破坏现有调用链

**文档同步:** AGENTS.md autoload 数量(19→24)、schema(v5→v6)、迁移链补 v6、情报系统说明；balance-check SKILL.md era 倍率(1.45/1.70→1.40/1.65)

## v6.7 自由模式剧情任务系统 (2026-06-22)

**目标**: 在自由模式中为关键关卡挂载剧情任务（对话面板演出），任务面板加"剧情"标签页。剧情模式原样保留，两套并存。

**核心策略**: 复用 QuestManager（不新建 manager）+ 数据扩展 + 触发器钩子 + 对话面板解耦。

**数据扩展（向后兼容）** — quest 定义新增 4 个可选字段（`def.get()` 读，默认值不影响旧任务）:
- `category`: `"commission"`(委托,默认) / `"story"`(剧情) / `"daily"`(日常)
- `trigger_level`: 剧情任务绑定的关卡号（仅 story 用）
- `pre_battle_dialogues` / `post_battle_dialogues`: 对话队列，每项 `{speaker, text, choices?}`

**6 个剧情任务（取自 docs/补剧情.txt 关卡映射）:**

| 任务 ID | 触发关 | 标题 | 剧情幕 |
|---------|-------|------|--------|
| q_story_first_guardian | 20 | 第一个守护者 | 第六幕·铁血男爵 |
| q_story_zack_48 | 48 | 替扎克看看48关之后 | 第七幕·扎克的四十八 |
| q_story_truth_60 | 60 | 守护者的低语 | 第八幕·守护者说话 |
| q_story_locke_83 | 83 | 洛克止步之地 | 第八幕·洛克与83 |
| q_story_mirror_99 | 99 | 镜像自己 | 第九幕·镜像守护者 |
| q_story_final_100 | 100 | 最后的试炼 | 第十幕·相位之主 |

剧情任务通过 prereq 链串联（20→48/60→83→99→100），前置完成后自动揭示（不依赖 NPC，自由模式无 city_map）。

**触发流程:**
1. 玩家在任务面板"剧情"Tab 接取剧情任务
2. 进关时 GameManager.go_to_battle 检查该关是否有已接取的剧情任务 → emit `story_mission_dialogue(quest_id, "pre")`
3. story_dialogue_panel 监听信号，播放战前对话（复用 v6.3 对话格式 + v6.6 分支选项）
4. 战斗进行（objective_type=clear_level 自动追踪进度）
5. 过关后 GameManager emit `story_mission_dialogue(quest_id, "post")` → 播放战后对话 → 任务自动完成

**关键文件:**
- `data/quest_definitions.gd` — +4 字段注释、+6 story 任务、+get_quests_by_trigger_level/get_ids_by_category
- `data/json/quest_definitions.json` — 补 v6.6 支线 + 6 story 任务（修复 JSON/GDScript 不同步：原 JSON 缺真实者/林薇/扎克支线，运行时不加载）
- `managers/quest_manager.gd` — +get_quests_by_category/trigger_level_for_quest/get_active_story_quest_at_level；is_quest_available 对 story 任务自动揭示
- `managers/game_manager.gd` — go_to_battle/on_battle_ended 加 _check_story_mission_pre/post_battle 钩子；+_pending_story_mission_quest 字段
- `scripts/signal_bus.gd` — +story_mission_dialogue(quest_id, phase) 信号
- `scenes/ui/story_dialogue_panel.gd` — +play_dialogues 通用方法、+_on_story_mission_dialogue 监听、+_ensure_ancestor_visible/_hide_mission_overlay（自由模式 overlay 可见性管理）、_on_all_dialogues_done 分流（mission 路径不调 v6.3 story_proceed_to_battle）
- `scenes/ui/quest_panel.tscn` — 重构为 TabContainer（委托/剧情/日常三标签），CompanySummary 移入委托 Tab
- `scenes/ui/quest_panel.gd` — _refresh_list 按 category 分流；剧情任务紫色边框 + ★ 标题前缀 + 触发关卡提示
- `scenes/world_map.gd` — _make_level_button 查剧情任务，加紫色左边框 + ★ 前缀 + tooltip

**设计决策:**
1. 复用 quest 系统不新建 manager — QuestManager 已有 hidden/prereq/branches/progress 全套
2. category 默认 "commission" — 现有所有委托任务行为零变化，向后兼容
3. 对话面板解耦而非新建 — story_dialogue_panel 已支持分支选项/角色配色/多句队列，去 v6.3 硬绑定即可
4. 触发器钩子放 game_manager — go_to_battle/on_battle_ended 是所有战斗必经单点
5. JSON 同步是前置 bug 修复 — v6.6 剧情任务在 GDScript 写好但 JSON 缺失，运行时不加载，本次顺带修复
6. 剧情任务自动揭示 — 不依赖 city_map/NPC（自由模式没有），前置 prereq 完成即 reveal

**不做的事:**
- 不删/不改剧情模式（city_map、StoryModeButton、v6.3 章节代码全部保留）
- 不动 DailyTaskManager（日常 Tab 第一期空置提示）
- 不做结局分支（结局归剧情模式管）

**验证:** Godot headless --check-only 成功启动到 DefaultCards 构建（133卡），无语法错误；Grep 静态核对通过（4 字段全链路拼写一致、story_mission_dialogue 信号 emit×2 + connect/disconnect + 定义完整、6 个新方法定义/调用配对、quest_panel 7 个 @onready 路径与 tscn 节点全匹配）。

## v6.7 引导剧情扩展（系统教学）(2026-06-22)

**目标**: 在关键关卡（第1/5/10/15/21关）自动触发系统教学对话，引导玩家学习相位仪装配、强化、改造、进化、符文五大系统。与主线剧情并存。

**category 新增取值 "tutorial"** — 引导剧情任务，与 "commission"/"story"/"daily" 并列：
- **自动触发**：进关即播，不进任务面板、不需手动接取、不占任务栏名额
- **一次性**：用 StoryManager 标记（`tutorial_<quest_id>`）防重复，每个只播一次
- **仅战前对话**：引导只教系统（战前），无战后对话
- **即时奖励**：触发时立即发放纳米材料（不通过任务完成流程）

**5 个引导剧情任务:**

| 任务 ID | 触发关 | 标题 | 教学系统 |
|---------|-------|------|---------|
| q_tutorial_equip_1 | 1 | 相位仪与卡牌 | 相位仪槽位 + 卡牌装配 |
| q_tutorial_enhance_5 | 5 | 卡牌强化 | 纳米材料强化卡牌等级 |
| q_tutorial_modify_10 | 10 | 卡牌改造 | 安装改造模块 |
| q_tutorial_evolve_15 | 15 | 卡牌进化 | 卡牌升阶形态 |
| q_tutorial_rune_21 | 21 | 法则符文 | 相位仪法则研究（打完第20关守护者获得符文后） |

**同关多剧情依次播放机制:**
同一关可能挂载多个剧情任务（如某关同时有 tutorial + story，或主线 + NPC 支线）。触发顺序：tutorial 先于 story，依次入 `_story_mission_queue`，story_dialogue_panel 用 `_mission_queue` 排队播放——播完一个自动播下一个，不互相覆盖。

**关键文件（本次扩展）:**
- `data/quest_definitions.gd` — +5 tutorial 任务定义、+get_all_triggerable_at_level（返回 story+tutorial，区别于 get_quests_by_trigger_level 只返回 story）
- `data/json/quest_definitions.json` — 同步 5 个 tutorial 任务（66→71）
- `managers/game_manager.gd` — _check_story_mission_pre_battle 重构（收集 tutorial+story 形成队列）；+_is_tutorial_triggered/_mark_tutorial_triggered/_grant_tutorial_reward/_is_story_quest_active；_story_mission_queue/_story_mission_played 替代 _pending_story_mission_quest
- `scenes/ui/story_dialogue_panel.gd` — +_mission_queue 队列播放（同关多剧情依次播放，播完一个自动播下一个）
- `scenes/ui/quest_panel.gd` — _refresh_list 过滤 tutorial（不进任何 Tab）

**设计决策:**
1. tutorial 不进任务面板 — 纯自动触发，避免玩家困惑（看到任务却无法接取/无明确目标）
2. tutorial 触发即标记 + 发奖 — 不依赖对话播完（防中途退出重播，奖励保证给到）
3. get_all_triggerable_at_level vs get_quests_by_trigger_level — 前者含 tutorial（GameManager 用），后者只 story（world_map 用，避免教学关显示★）
4. 队列播放而非覆盖 — 同关多剧情用队列依次播放，避免后发信号覆盖前者

**验证:** Godot headless --check-only 通过（无语法错误）；JSON tutorial 任务字段完整；Grep 确认 get_all_triggerable_at_level/_story_mission_queue 链路一致。

## v6.7 剧情任务全面扩展（补剧情.txt 关卡锚点全铺满 + NPC 支线归剧情）(2026-06-22)

**目标**: 把 docs/补剧情.txt 的关卡锚点全部铺满，并把原有 6 个 NPC 支线（真实者/林薇/扎克）从 city_map 依赖改造为自由模式关卡触发。

**A. 新增 5 个主线剧情任务（补全时代 Boss + 主线节点）:**

| 任务 ID | 触发关 | 标题 | 剧情幕 |
|---------|-------|------|--------|
| q_story_realist_10 | 10 | 真实者的阴影 | 第四幕·真实者初次接触 |
| q_story_city_15 | 15 | 城市的轮廓 | 第二幕·城市功能解锁 |
| q_story_steel_marshal_40 | 40 | 钢铁洪流 | 时代Boss·钢铁元帅（二战） |
| q_story_void_lord_80 | 80 | 虚空之主 | 时代Boss·虚空领主（现代） |
| q_story_countdown_90 | 90 | 倒计时 | 第九幕前奏·海伦宣告 |

**B. NPC 支线归入剧情标签（6 个，触发关绑定）:**

| 任务 ID | 触发关 | 原揭示方式 | 现揭示方式 |
|---------|-------|-----------|-----------|
| q_realist_invite | 10 | city_map NPC 对话 | 进第10关自动揭示 |
| q_realist_join/reject/delay | - | 分支后续（prereq 链） | 完成 q_realist_invite 后分支揭示 |
| q_linwei_secret | 15 | city_map NPC 对话 | 进第15关自动揭示 |
| q_zack_beyond_48 | 40 | city_map NPC 对话 | 进第40关自动揭示 |

**主线 prereq 链（完整通关路径）:**
```
L10 真实者阴影 → L15 城市轮廓 → L20 铁血男爵 → L40 钢铁元帅
→ L48 扎克48关 → L60 守护者低语 → L80 虚空领主 → L83 洛克止步
→ L90 倒计时 → L99 镜像自己 → L100 相位之主
```

**关键改造点:**
- `managers/game_manager.gd` `_check_story_mission_pre_battle`：进关时对该关所有 story 任务调 `qm.reveal_quest(qid)` 自动揭示（自由模式无 city_map/NPC，NPC 支线必须靠关卡触发揭示）；只有"已接取 + 未完成 + 有 pre_battle_dialogues"的才入播放队列
- NPC 支线（q_realist_invite 等）无 pre_battle_dialogues，进关只揭示不播对话，玩家在任务面板接取后按各自 objective_type 完成（win_battles/collect_cards/clear_level/reach_reputation）

**剧情任务总量（v6.7 完整版）:**

| 类型 | 数量 | 说明 |
|------|------|------|
| 引导剧情 tutorial | 5 | 第1/5/10/15/21关，自动触发，系统教学 |
| 主线剧情 story（有对话） | 11 | 第10/15/20/40/48/60/80/83/90/99/100关 |
| NPC支线 story（无对话） | 6 | 真实者4 + 林薇1 + 扎克1，进关揭示 |
| **合计** | **22** | 覆盖补剧情.txt 全部关卡锚点 |

**关键文件（本次扩展）:**
- `data/quest_definitions.gd` — +5 主线任务定义、6 个 NPC 支线加 category/trigger_level、3 个现有任务 prereq 更新
- `data/json/quest_definitions.json` — 同步（71→76→80 任务；story 17 个、tutorial 5 个、commission 58 个）
- `managers/game_manager.gd` — _check_story_mission_pre_battle 加 story 任务自动揭示

**验证:** Godot headless --check-only 通过；JSON 76 任务字段完整；Grep 确认 reveal_quest 钩子调用正确。

## v6.8 收敛我方加成来源 (2026-06-23)

**背景**: 审查发现我方战斗卡的属性加成来源多达 10+ 个系统，且存在"时代缩放只加我方、不加敌方"的不对称设计。本轮收敛加成来源，停用 4 套非核心加成 + 压缩稀有度，保留各系统的数据/UI/存档/掉落。

**核心原则**: 我方加成来源收敛为——强化、改造、相位仪、符文（玩家可投入养成的核心）+ 战力星级/进化/军衔/稀有度（派生乘区）+ 兵种修正/平台光环/改造光环（单位设计/战场协同）。

**5 个改动点:**

| # | 改动 | 详情 |
|---|------|------|
| 1 | **稀有度乘区压缩** | 6档 1.0/1.1/1.25/1.4/1.5/1.8 → 1.0/1.04/1.08/1.12/1.16/1.20（common/uncommon/rare/epic/legendary/mythic），避免稀有度过度主导战力 |
| 2 | **势力停用** | 移除势力变体生成路径（effective_card 直接用原始 platform_card）+ apply_faction_special_to_stats + _apply_skill_tree_effects；势力声望商店/合成/卡生成养成保留 |
| 3 | **敌源MOD断开** | 移除 apply_eom_to_stats；EOM 面板/装备/战后碎片掉落/存档全部独立保留 |
| 4 | **我方相位法则被动停用** | 删 construct_unit 的 _apply_phase_law_passives + connect/disconnect + _law_regen_per_sec 回血块 + 7 个孤立 _base_* 变量；**敌方减益不受影响**（enemy_unit/swarm_enemy_slot 各自独立实现继续生效） |
| 5 | **时代缩放移除** | build_stats_from_card 不再按 era 放大我方 HP/三维攻击/射程/武器伤害；_apply_evolution_hp_floor 同步去掉 era 倍率（避免主属性不缩放、HP下限仍按时代抬高的矛盾） |

**关键设计决策:**
1. **时代缩放本就不对称**——核实发现敌方（enemy_stat_resolver.gd）走独立的 `wave × level × pressure × master` 难度链，从不调用 era_*_multiplier。时代缩放原本就是"只放大我方"的隐形优势，移除后关卡难度完全由敌方难度链承担，符合"缩放应为调整简单"的本意。
2. **停用而非删除系统**——势力/敌源MOD/相位法则的数据类、管理器、UI、存档、掉落全部保留，只断开战斗数值注入链路。可随时恢复，风险最小。
3. **敌方相位法则减益不动**——_apply_phase_law_passives 在我方/敌方三处是各自独立函数（同名不同体），只删我方版本，敌方 burn_on_hit/anchor_field 等减益继续生效。
4. **连带清理孤立代码**——删除被孤立的函数定义（apply_faction_special_to_stats/apply_eom_to_stats/_apply_skill_tree_effects）和孤立变量（_law_regen_per_sec/_base_* 系列），代码更清爽；保留 get_active_faction_skill_effects 公共方法（养成查询接口）和 skill_tree_specials 字段（避免破坏序列化）。
5. **连带传播属正常**——稀有度压缩后，estimate_power_score_meta_only（战力分）、get_base_power_for_mod_cost（改造消耗）数值自动变小，非重复定义，不另作处理。combat_power_from_unit_stats 读 stats 本身，时代缩放移除后战力分自动跟随，UI/战斗数值保持一致。

**关键文件:**
- `managers/evolution/evolution_helpers.gd` — get_rarity_multiplier 压缩 + _apply_evolution_hp_floor 去 era 倍率
- `managers/battle/battle_spawn_system.gd` — 简化势力变体查询 + 删势力/EOM 注入调用块 + 删 _apply_skill_tree_effects 定义 + 清 2 个孤立 preload
- `managers/faction/faction_card_generator.gd` — 删 apply_faction_special_to_stats（保留 generate_faction_variant 数据）
- `scripts/systems/enemy_origin_mod_manager.gd` — 删 apply_eom_to_stats（保留面板/掉落/存档接口）
- `resources/unit_stats_table.gd` — build_stats_from_card 删 3 处 era_*_multiplier 块（主属性/多武器/武器槽）
- `scenes/units/construct_unit.gd` — 删 _apply_phase_law_passives + _on_phase_law_runtime_changed + connect/disconnect + _law_regen_per_sec 回血块 + 7 个孤立 _base_* 变量（顺带捎上会话前预存的 combat_kind 透传改动）
- `scenes/ui/enemy_origin_mod_panel.gd` — 注释同步（EOM 战斗加成已停用）

**保留不动的 era_*_multiplier 残留**: summarize_weapon_stats_from_card / get_weapon_base（UI 摘要/旧接口，纯死代码无调用方）；BattleCardV3.era_*_multiplier 函数定义本身（敌方系统/测试仍在引用）。

**验证:** Godot headless --check-only 通过（133卡构建，无语法错误，5分钟超时属项目既有现象）；Grep 确认 build_stats_from_card 战斗路径 era_*_multiplier 100% 清零、evolution_helpers era_*_multiplier 清零、删除的 4 个函数名 + _law_regen_per_sec 在我方代码无残留（敌方独立实现保留）。

## v6.9 势力占领关卡系统 (2026-06-23)

**背景**: 玩家设想——20关后各关卡由各势力占领，势力能力影响关卡敌人加成，势力相位师在各势力关卡分布，任务栏任务动态更新，主角完成任务影响各势力，部分任务随机结果。

**核心原则**: 静态归属（不动占领状态机）+ 前20关无势力（教学时代）+ 势力只增强敌方（不复活 v6.8 已停用的我方加成）+ 复用现有链路（任务影响势力走成熟 _grant_rewards → add_faction_reputation）。

**4个阶段实现:**

### 阶段0：数据基础与命名统一
| 改动 | 详情 |
|------|------|
| **前20关去势力** | level_information.gd 的 `_add_ww1_levels()` 1-20关 faction_id 从 "iron_wall_corp" → ""（空=无主之地，无势力加成/相位师/声望反应） |
| **新建势力能力表** | data/faction_conquest_buffs.gd — 7势力×5档（Lv1/3/5/7/10）敌人加成表，每势力一个战斗风格主题（钢壁=血厚/新星=攻猛/以太=速快/量子=量多/螺旋=闪避/虚空=暴击/边境=通用） |
| **相位师命名核查** | 发现 check_phase_master_encounter 用 NPC_PHASE_MASTERS（已是公司ID）+ _enrich_master_config 已有公司ID→法则家族映射，无需改 enemy_phase_masters*.gd |
| **on_level_conquered 守卫** | 已有现成 `if conquered_faction.is_empty(): return` 守卫（faction_system_manager.gd:285），1-20关攻克天然不扣声望 |

### 阶段1：势力对关卡敌人加成（核心机制）★
占领势力等级越高，该关敌人越强。接入敌方加成链（wave×level×pressure×master 末尾加 faction_buff 乘区）。

| 文件 | 改动 |
|------|------|
| `data/enemy_stat_context.gd` | +faction_buff 字段（复用 player_pressure 设计模式） |
| `data/enemy_stat_resolver.gd` | +_collect_faction_buff()（make_default_context 按关卡faction_id+势力等级填值）；resolve_classic_enemy 的 dmg_mul_chain/hp_mul_chain 末尾乘 f_atk/f_hp；move_speed 接入 f_spd（顺带修复 p_spd 历史遗留无效问题） |

### 阶段2：势力相位师分布
| 改动 | 详情 |
|------|------|
| **匹配已生效** | check_phase_master_encounter（game_manager.gd:107-114）已按 get_level_faction 优先抽该势力相位师，21关起生效，1-20关走随机 |
| **关卡弹窗显示驻防势力** | world_map.gd 的 _collect_level_info 加 garrison_* 字段（查 FactionSystemManager.get_faction_info）；_show_level_info_popup 加驻防势力行（橙色=占领势力+敌方加成描述，灰色=无主之地） |

### 阶段3：动态任务系统（扩展 QuestManager）★
任务栏任务随势力/关卡动态生成。核心策略：**扩展 QuestDefinitions 静态查询**（加 _DYNAMIC_QUESTS 集合 + get_by_id/get_available_ids 同时查两个集合），让所有现有代码（接受/进度/完成判定）自动支持动态任务。

| 文件 | 改动 |
|------|------|
| `data/quest_definitions.gd` | +_DYNAMIC_QUESTS 集合；+register/unregister/get_dynamic_quest_ids/get_all_dynamic_quest_defs/clear_dynamic_quests；get_by_id/get_available_ids 同时查静态+动态 |
| `data/faction_quest_generator.gd`（新增） | 势力动态任务生成器：5势力×4类型模板（win_battles/kill_enemies/attack_faction/defend_faction），按势力等级生成，奖励含 company_rep/faction_rep（影响势力） |
| `managers/quest_manager.gd` | +refresh_faction_quests（生成+注册+揭示+toast）；_try_complete 完成后 unregister 动态任务；save/load_state 持久化 dynamic_quests 字段；+is_dynamic_query 辅助 |
| `managers/game_manager.gd` | set_current_level 末尾调 _maybe_refresh_faction_quests_for_level（进入势力领地关卡触发该势力发布委托） |
| `scenes/ui/quest_panel.gd` | _make_quest_row 加 is_dynamic 视觉标记（橙红边框+暖橙标题，与剧情任务紫色/普通蓝色区分） |

### 阶段4：任务随机结果机制
部分任务完成时结果不确定（成功/部分成功/意外缴获）。

| 文件 | 改动 |
|------|------|
| `data/quest_definitions.gd` | +outcome_table 字段注释（[{weight,label,rewards}]，缺省走固定 rewards 向后兼容） |
| `managers/quest_manager.gd` | _try_complete 加 _roll_outcome 按权重抽取，用抽取 rewards 替代固定值；toast 显示结果 label |
| `data/faction_quest_generator.gd` | win_battles 任务带 outcome_table（圆满成功50%/部分成功35%/意外缴获15%） |

**关键设计决策:**
1. **静态归属而非动态占领**——用户选择，沿用 level_information.gd 固定 faction_id，不做"运行时势力攻占他关"状态机，风险最小
2. **前20关无势力**——一战教学时代设为无主之地，21关起启用势力机制，符合"20关后"描述
3. **势力只增强敌方**——与 v6.8 收敛方向一致，不复活已停用的我方势力加成；乘区接入 enemy_stat_resolver 敌方加成链末尾，零侵入
4. **扩展 QuestDefinitions 而非改每个查询函数**——动态任务接入 get_by_id/get_available_ids，所有现有代码（_on_enhancement_completed/notify_*/is_quest_done/get_current_progress_for_quest）自动支持，避免改每个函数
5. **outcome_table 向后兼容**——缺省走固定 rewards，所有现有 76 个静态任务行为零变化，只有显式定义 outcome_table 的任务才有随机结果
6. **动态任务存档**——未完成的动态任务定义持久化到 dynamic_quests 字段，旧存档无此字段时为空数组自动初始化

**平衡性:** 7势力满级威胁倍率（攻×HP）全部 ≤ 1.80 阈值（最高 void_research 1.624），单维度 ≤ 1.40/1.30 上限；与历史 master_stats 乘区同量级。

**验证:** Godot headless --check-only 成功构建到 133 卡（无语法错误，5分钟超时属项目既有现象）；Grep 静态核对全部通过（faction_buff 链路、garrison_* 链路、动态任务 API 链路、outcome_table 链路全拼写一致）。

**延后项（润色，不影响核心功能）:** leaderboard_data.gd 的 FACTION_RANGES 仍按旧关卡归属（iron_wall 1-20、frontier_union 1-10），排行榜显示与关卡弹窗"无主之地"矛盾，但仅影响排行榜领地统计展示，不影响战斗/任务/声望。

## v6.10 占领状态机 + 势力状态机 + 势力领地图面板 (2026-06-23)

**背景**: 在 v6.9 静态势力占领基础上，用户要求加"状态机+任务面板"。明确为：(1) 占领状态机（动态领地易主）+ (2) 势力状态机（派生标签）+ (3) 新建势力领地图面板。

**核心原则**: 占领转移=玩家攻克即易主（给激活势力，无激活则解放为无主之地）；势力状态=派生标签（从占领数+声望实时计算，不存储避免双源真理）；level_occupation 存进 faction_system 子字段（不升 schema，靠 load_state 守卫兼容）；加成数据源从静态切到动态占领。

**4个阶段实现:**

### 阶段A：占领状态机（核心）
| 文件 | 改动 |
|------|------|
| `scripts/signal_bus.gd` | +occupation_changed(level, old_faction, new_faction) 信号 |
| `managers/faction_system_manager.gd` | +level_occupation 字段；+occupation_changed 信号及转发；+get_level_occupation/_init_level_occupation/transfer_occupation/get_territory_count API；on_level_conquered 接入占领转移（守卫调整：静态空也执行转移）；save/load_state 持久化 level_occupation |
| `data/enemy_stat_resolver.gd` | _collect_faction_buff 数据源从静态 get_level_faction 切到动态 get_level_occupation（玩家攻克易主后敌方加成跟随） |

### 阶段B：势力状态机（派生标签）
| 文件 | 改动 |
|------|------|
| `data/faction_status.gd`（新增） | 派生状态枚举（EXTINCT/DECLINING/STABLE/EXPANDING/DOMINANT）+ 中文名+配色；derive_status(territory_count, reputation) 双维度组合判定 |
| `managers/faction_system_manager.gd` | +get_faction_status/get_faction_status_name/get_faction_status_color 派生查询（实时计算，不存储） |

### 阶段C：势力领地图面板（新建）★
| 文件 | 改动 |
|------|------|
| `scenes/ui/occupation_panel.tscn`（新增） | 占领地图面板骨架（标题/图例/领地网格/详情） |
| `scenes/ui/occupation_panel.gd`（新增） | 7势力图例（色块+名称+状态标签+占领数+声望）+100关网格（5时代×20关，按钮=占领势力配色）+点击详情；监听 occupation_changed/faction_reputation_changed 实时刷新；FACTION_COLORS 7势力代表色定义 |
| `managers/ui_lazy_loader.gd` | +occupation 注册（PopupLayer/OccupationOverlay/CenterContainer） |
| `scenes/main.tscn` | +OccupationOverlay/CenterContainer/OccupationPanel 节点 + ext_resource |
| `scenes/world_map.gd` | +_on_territory_map_button 入口（顶部"◆势力领地图"按钮，懒加载+显示面板） |

### 阶段D：world_map 占领可视化联动
| 文件 | 改动 |
|------|------|
| `scenes/world_map.gd` | _make_level_button 加占领色标（右边框=势力色，与剧情关紫色左边框不冲突）；_collect_level_info 弹窗读动态占领（_get_level_occupation_safe）；_ready 监听 occupation_changed → refresh_levels 实时刷新色标；+_OCCUPATION_BORDER_COLORS 7势力配色（与面板一致） |

**关键设计决策:**
1. **玩家攻克即易主**——用户选择，攻克某关直接归玩家激活势力；未激活势力则解放为无主之地。简单直接，玩家掌控感强
2. **派生标签不存储**——势力状态从占领数+声望实时计算，避免"状态字段与底层数据不一致"的双源真理问题
3. **level_occupation 存进 faction_system 子字段**——不升 schema，靠 load_state 守卫兼容（旧存档无此字段→空字典→get_level_occupation 回退静态表，零破坏）
4. **加成数据源切到动态**——_collect_faction_buff 从 get_level_faction 改为 get_level_occupation，让占领真正影响战斗（攻克易主后该关敌人加成跟随新占领势力）
5. **on_level_conquered 守卫调整**——原 L285 静态空即 return 会阻止已接管关卡再攻克时转移；改为静态空时跳过声望反应但仍执行占领转移
6. **新面板独立而非加 Tab**——occupation_panel 是世界视角（100关占领网格），与 faction_panel 的单势力详情视角 UI 范式不同，新建独立面板更干净
7. **信号驱动实时刷新**——occupation_changed 经 SignalBus 转发，occupation_panel 和 world_map 都监听，攻克易主后两边都实时更新

**关键文件:**
- `managers/faction_system_manager.gd` — +level_occupation 字段/API/转移/存档/信号转发（核心）
- `data/faction_status.gd`（新增）— 派生状态枚举+计算
- `data/enemy_stat_resolver.gd` — 加成数据源切动态占领
- `scenes/ui/occupation_panel.tscn/.gd`（新增）— 占领地图面板
- `scenes/world_map.gd` — 占领色标+弹窗读动态+入口按钮+实时刷新
- `scripts/signal_bus.gd` — occupation_changed 信号
- `managers/ui_lazy_loader.gd` / `scenes/main.tscn` — 面板注册与挂载

**验证:** Godot headless --check-only 成功构建到 133 卡（无语法错误，5分钟超时属项目既有现象）；Grep 静态核对全部通过（occupation_changed 信号链路、get_level_occupation API 链路、get_faction_status 链路、occupation_panel 节点路径与 tscn 全匹配）。

## v6.11 敌方相位师影响普通敌兵 + master 系数收敛 (2026-06-24)

**背景**: 平衡性审查发现敌方相位师的 `master_stats`（attack_power/defense）应影响普通敌兵，但 `make_default_context` 从不注入 master_stats，导致经典敌兵和蜂群走 `resolve_classic_enemy` 时 m_atk/m_hp 恒为 1.0——只有相位师召唤的产兵（走 `apply_phase_master_to_unit_stats`）才生效。同时 v6.2 把 m_atk 系数从 0.0005 提到 0.002，但漏改了测试（`test_enemy_stat_resolver.gd` 仍断言旧值），该测试处于失败状态。

**3 个改动点:**

| # | 改动 | 详情 |
|---|------|------|
| 1 | **make_default_context 注入 master_stats** | 函数末尾从 BattleManager._phase_master_config.stats 取 master_stats 写入 ctx.master_stats；经典敌兵(enemy_unit)与蜂群(swarm_enemy_slot)都经此函数 → resolve_classic_enemy，修复后都吃相位师属性加成。非相位师战时 _phase_master_config 为空 → master_stats 保持默认空，普通波次行为零变化 |
| 2 | **master_attack_multiplier 系数收敛** | 0.002 → 0.0005。master030(attack_power1000)从过猛的 3.0x 收敛到温和的 1.5x；master001(120)从 1.24x→1.06x |
| 3 | **master_defense_hp_multiplier 系数恢复** | 0.0001 → 0.0003。v6.2 曾削弱(0.0003→0.0001)导致防御属性对敌兵几乎无效（master016 def200 仅 1.02x）；恢复后 1.06x，与攻击侧量级对称 |

**关键设计决策:**
1. **普通敌兵走 master_stats 生效 + 排名加成保留叠加**——用户确认。make_default_context 注入 master_stats 让普通敌兵/蜂群吃相位师属性，同时保留 apply_enemy_phase_master_bonus_to_unit_stats（+14~21% 排名加成），双乘区叠加
2. **系数收敛到 v6.2 之前的值**——0.0005/0.0003 正好让过时失败的测试自动通过（测试断言反映的就是旧系数）
3. **向后兼容**——非相位师战时 master_stats 恒空 → 行为与修复前 100% 一致；相位师遭遇战从"仅排名加成"变为"master_stats + 排名加成叠加"，温和增强

**关键文件:**
- `data/enemy_stat_resolver.gd` — make_default_context 末尾注入 master_stats（取 BattleManager._phase_master_config.stats）；m_atk 系数 0.002→0.0005、m_hp 系数 0.0001→0.0003
- `tests/unit/combat/test_enemy_stat_resolver.gd` — +test_master_multipliers_new_coefficients（锁定新系数防回归）、+test_resolve_classic_enemy_with_master_stats（比值验证 master_stats 对普通敌兵生效）

**数值影响（温和）:** 中等关（第40关 + 相位师013 + 排名3星）ATK +17%/HP +2%；极端堆叠（第100关 + 满级势力 + master030 + 满排名）ATK +50%/HP +4%。

**验证:** Godot headless --check-only 通过（133 卡构建）；独立运行时验证 12 项全 PASS（系数验证 + resolve_classic_enemy 比值验证 + 向后兼容）；Grep 静态核对通过。

## v6.11b 战场敌方信息卡"武装：无"误显示修复 (2026-06-24)

**背景**: 用户反馈战场敌方信息卡显示"武装：无"。调查证实 36 个敌方 archetype 100% 都有 weapon_type，但 `_show_generic_enemy_unit`（card_info_panel.gd）判断武器的逻辑只依赖 `EnemyArchetypes.get_config(archetype_id)`——一旦该 cfg 返回空字典（动态生成单位时序/manifest 未合并/某些 archetype 查不到），weapon_type_val 保持默认 -1 → 直接显示"武装：无"，即使该单位实际有武器且正在开火。附带 bug：`_enemy_surface_combat_stats` 用 `unit.hp`（当前剩余血量）而非 `max_hp`（满血上限），残血敌人显示被打掉后的血。

**2 个改动点:**

| # | 改动 | 详情 |
|---|------|------|
| 1 | **武器显示三级回退** | `_show_generic_enemy_unit` 武器判断改为：①优先 archetype cfg；②cfg 空时回退 unit.stats.weapon_type + unit.stats.attack_damage（经典敌人和蜂群都同步了这两字段）；③仍查不到才显示"无"。杜绝误显示 |
| 2 | **HP 显示改用 max_hp** | `_enemy_surface_combat_stats` 优先读 max_hp（满血上限），单位无该字段时回退 hp（防御性兼容）。残血敌人血量现在稳定显示上限 |

**关键设计决策:**
1. **防御性回退而非改 get_config**——manifest 合并时序属正常缓存行为，显示层做兜底更稳妥，不触动数据查询逻辑
2. **不改 archetype 数据**——36 单位本就有武器，数据没问题；问题是显示层只依赖单一数据源太脆弱

**关键文件:**
- `scenes/ui/card_info_panel.gd` — `_show_generic_enemy_unit` 武器判断三级回退（L1322-1333）；`_enemy_surface_combat_stats` HP 改用 max_hp（L1022）

**验证:** Godot headless --check-only 通过（133 卡构建）；Grep 确认 stats.weapon_type/stats.attack_damage 在 enemy_unit.gd:413 和 swarm_enemy_slot.gd:103 都有设置（回退链完整）。注：显示层改动需游戏内实机验证点击交互。

## v6.12 敌方产兵改用真实数据 + master 系数增强 (2026-06-25)

**背景**: 用户反馈"敌方卡和我方同样卡差异太大"。调查证实敌方相位师产兵走 `build_multi_stats`（通用平台表 `_PLATFORM_BASE`/`_WEAPON_BASE`，数值偏弱），而非真实敌人数据；叠加的 master 加成也偏温和（HP 仅 ×1.03-1.06）。同一概念单位（如 T-72）敌我可差 3-5 倍。

**决策（与用户确认）:** 方式 1——敌方产兵改用敌方 archetype 真实数据（如 elite_cold_t72 的 hp250/atk40），替换通用平台表；同时增强 master 系数。

**3 个改动点:**

| # | 改动 | 详情 |
|---|------|------|
| 1 | **产兵改用真实 archetype 数据** | `_produce_unit_with_equipment` 的 `build_multi_stats`（通用表）→ `_build_stats_from_archetype`（真实 archetype cfg 构造 CardResource → build_stats_from_card）。复用已有平台→archetype 映射（_pick_visual_archetype_for_platform），archetype 查不到时回退通用表兜底 |
| 2 | **master_attack_multiplier 增强** | 0.0005 → 0.0008。master016(400)攻 ×1.32，master030(1000)攻 ×1.80 |
| 3 | **master_defense_hp_multiplier 增强** | 0.0003 → 0.0006。master016(200)血 ×1.12，master030 血 ×1.12 |

**关键设计决策:**
1. **用敌方 archetype 真实数据而非跨数据源读我方卡牌**——用户选择（推荐项）。复用 _pick_visual_archetype_for_platform 的平台→archetype 映射取真实 cfg，改动集中在 1 个函数，风险低；跨数据源读 default_cards 会引入耦合且需新建映射表
2. **保留 platform_data.stats 覆写**——master 装备的 hp/defense 覆写是其差异化体现，保留让不同 master 召唤的单位有区别
3. **系数增强同步影响两条路径**——m_atk/m_hp 系数同时影响普通敌兵（resolve_classic_enemy，v6.11 刚修的 master_stats 注入）和产兵（apply_phase_master_to_unit_stats），两者同步增强，符合"敌方变强"诉求
4. **兜底完善**——archetype 查不到/映射失败时回退 build_multi_stats 通用表，不会崩

**关键文件:**
- `scenes/units/enemy_phase_field_driver.gd` — `_produce_unit_with_equipment` 改用 `_build_stats_from_archetype`；新增 `_build_stats_from_archetype`（真实 archetype cfg → CardResource → build_stats_from_card）+ `_archetype_combat_kind`（按 tags 推断战斗类型）
- `data/enemy_stat_resolver.gd` — m_atk 系数 0.0005→0.0008、m_hp 系数 0.0003→0.0006
- `tests/unit/combat/test_enemy_stat_resolver.gd` — 3 处测试断言值更新匹配新系数

**数值影响（以 master016 召唤精英 T-72 为例）:** HP ~212→~336（+59%），ATK ~36→~53（+47%）。我方满养成 T-72 仍保持 ~12-17× 优势——养成碾压感保留，但敌方产兵不再过脆偏弱。

**验证:** Godot headless --check-only 通过（133 卡构建）；独立运行时验证 10 项全 PASS（系数验证 + resolve_classic_enemy 比值验证 + 向后兼容）；Grep 确认 _PLATFORM_DEFENSE/PLATFORM_TO_COMBAT_KIND 静态成员存在、archetype cfg 字段名与新函数读取匹配。注：`_build_stats_from_archetype` 依赖 autoload 环境（EnemyArchetypes.get_config），运行时构建结果需游戏内实机验证。

## v6.14 全系统贯通 (2026-06-26)

**背景**: 用户提出跨多系统的整体诉求——不同战力敌人有不同战力/掉不同改造、不同改造要不同战力安装、相位师有等级/相位仪/符文/出兵序列、打败相位师掉符文/改造/兵种卡、关卡掉兵种卡/改造、关卡波次序列式+随机、势力是玩家主动构筑的选择加成、占领关卡给敌方加成和改造掉落。

**核心策略**: 11 个子模块按"数据层→逻辑层→接入层"分 6 阶段一次实现。新增 2 个数据文件 + 扩展/改造约 16 个既有文件。全部向后兼容（新字段 `.get(key, default)`，缺省值保证旧存档/旧数据零变化）。

**6 个阶段实现:**

### 阶段1：战力分级基础
| 文件 | 改动 |
|------|------|
| `data/power_tiers.gd`（新增） | 5 档战力枚举（GRUNT/VETERAN/ELITE/CHAMPION/OVERLORD）+ get_tier_by_rank/get_tier_by_power/meets_requirement；统一所有"不同战力→不同X"的共用基础 |
| `data/intel_manual_items.gd` | roll_random_mod_blueprint 增加 power_tier + bias_unit_types 参数；新增 _apply_power_tier_to_weight（高档位抬高高稀有度权重）+ _unit_type_name_to_int |

### 阶段2：关卡波次序列系统
| 文件 | 改动 |
|------|------|
| `data/level_spawn_sequences.gd`（新增） | 程序化生成 per-level 波次序列（种子=level 可复现）；规则：每时代首关教学/wave%3精英波/最后波boss/难度随进度递增；get_sequence_for_level/get_wave_spec/pick_type_for_wave |
| `managers/battle/battle_spawn_system.gd` | 波次抽选从纯随机改为读序列（composition 抽签 + bias_tags 偏好抽签）；新增 _pick_archetype_with_bias；序列为空回退原随机 |

### 阶段3：势力主动构筑重接 + 占领掉落
| 文件 | 改动 |
|------|------|
| `managers/battle/battle_spawn_system.gd` | `_build_stats_cached` 重接 v6.8 停用的势力技能注入：取 get_active_faction_skill_effects 的 stat_bonus 注入我方单位（三维攻防/HP/攻速）；缓存 key 加 active_faction_cache_key |
| `data/faction_conquest_buffs.gd` | get_buff 返回新增 drop_mul（改造掉率×1.0~1.5）+ mod_pool_bias（偏好改造类型）；FACTION_MOD_BIAS 7势力主题映射 |
| `scripts/systems/intel_discovery_manager.gd` | `_roll_intel_item_drops` 注入占领势力：drop_mul 乘进掉率，改造蓝图传 bias_unit_types + power_tier |

### 阶段4：相位师装备/序列/掉落
| 文件 | 改动 |
|------|------|
| `data/enemy_phase_masters.gd` | 新增 get_enriched_equipment（程序化派生 runes/spawn_sequence）；_derive_runes（按level选稀有度梯度，2-4个）+ _derive_spawn_sequence（平台循环序列+elite/boss标记） |
| `data/json/enemy_phase_instruments.json` | 26 个相位仪补全 atk_bonus/hp_bonus/def_bonus（按level/rarity派生），让 _get_enemy_phase_instrument_bonus 真正生效 |
| `scenes/units/enemy_phase_field_driver.gd` | 产兵从纯随机改读 spawn_sequence（带elite/boss加成）；新增 _apply_master_rune_bonus（符文加成产兵）+ _apply_sequence_entry_bonus + _apply_enemy_phase_instrument_bonus（相位仪加成） |
| `managers/game_manager.gd` | 相位师掉落：符文改为从自带runes池抽（装什么掉什么）+ 新增改造蓝图掉落（必掉1+30%额外1）；新增 _pick_rune_from_pool_or_generic |

### 阶段5：改造战力门槛 + 关卡改造掉落
| 文件 | 改动 |
|------|------|
| `managers/evolution/mod_manager.gd` | 新增 get_min_power_tier_for_mod（按rarity派生门槛）+ can_install_by_power_tier |
| `managers/blueprint_manager.gd` | install_modification 加战力档位校验（卡牌战力不足拒绝安装，提示需X档） |
| `resources/drop_tables.gd` + `managers/drop_manager.gd` | 新增 DropType.MOD_BLUEPRINT 枚举 + _add_mod_blueprint claim 分支（写IntelItemBag） |

### 阶段6：情报面板统一显示
| 文件 | 改动 |
|------|------|
| `scenes/ui/card_info_panel.gd` | _show_enemy_phase_driver（点击基地）+ _show_enemy_phase_master_unit（点击单位）统一显示等级/相位仪名/符文；新增 _get_enemy_instrument_display_name + _format_enemy_runes |

**关键设计决策:**
1. **战力档位为统一基础**——所有"不同战力→不同X"经 PowerTiers 枚举，避免每系统各自定义阈值
2. **序列程序化生成+种子**——100关不手填，generate_sequence(level,era,seed=level) 可复现，序列内随机保留扰动
3. **势力注入重接而非新建**——v6.8 停用的 get_active_faction_skill_effects 和缓存 key 变量都已预留，只填入调用+注入
4. **占领掉落用buff扩展**——faction_conquest_buffs 已有 hp/atk/spd，加 drop_mul/mod_pool_bias 复用同通道
5. **相位师装备程序化派生**——不改30条静态数据，get_enriched_equipment 按 level/faction 派生 runes/spawn_sequence，所有相位师自动获得
6. **改造门槛按rarity派生**——不改140+改造定义，get_min_power_tier_for_mod 按 rarity 映射档位（common→无门槛, legendary→需OVERLORD）
7. **全部向后兼容**——新字段 .get(key, default)，缺省值保证旧存档零变化；JSON 数据脚本批量补全

**验证:** 14个改动/新建文件独立 Godot load 编译全部 ✅ 通过；项目 syntax_check 全通过；Grep 静态核对全部链路（PowerTiers/LevelSpawnSequences/get_enriched_equipment/get_active_faction_skill_effects/产兵加成/相位师掉落）拼写+调用配对完整；相位仪 JSON 26/26 加成字段完整。注：势力注入/序列波次/相位师产兵序列等运行时行为需游戏内实机验证。

## ⚠️ 核心架构：卡牌实例化与养成隔离（永久约束，改任何卡牌/养成相关代码前必读）

**这是 v7.x 的核心架构，所有"卡牌强化/改造/进化/部署/显示"相关改动都必须遵守。违反会导致"强化一张卡所有同名卡都变"等严重污染 bug。**

### 单一事实来源

| 概念 | 真身 | 说明 |
|------|------|------|
| **卡牌模板** | `DefaultCards.get_card_by_id(card_id)` 返回的 `CardResource` | **共享单例**，每个 card_id 全局唯一，`_id_lookup_cache` 缓存。**只读，永不直接改其养成字段**（enhance_level/mods/module_slots）。 |
| **卡牌实例** | `InstanceRegistry` 里的独立 `CardResource` 对象 | 通过 `create_instance(card_id)` → `template.clone()`（深拷贝）创建，带 `instance_id`（`card_id#N`，N 由计数器递增）。**养成数据（enhance_level/mods/module_slots/inherit_bonus）只挂在实例上，不挂模板**。 |

### 三大铁律

**铁律 1：养成操作（强化/改造/进化）必须落在实例卡上，严禁直接改模板。**
- 实例判定：`card.instance_id` 非空（如 `cold_t72#1`）才是实例；为空则是共享模板。
- 强化面板 `_on_reinforce_pressed`、改造面板 `_install_modification` 都有 `instance_id.is_empty()` 守卫，拒绝操作模板。**新增任何养成操作必须加同款守卫。**
- 数据层 `BlueprintManager.apply_reinforcement(card, ...)` / `install_modification(card, ...)` 写入传入 card 对象的养成字段——调用方必须保证传入的是实例，不是 `DefaultCards.get_card_by_id` 模板。

**铁律 2：卡牌列表（成长/强化/改造/进化面板）数据源必须是 InstanceRegistry 实例全集，不是 SaveManager 队列。**
- `SaveManager._pending_backpack_ids` / `_last_known_extra_ids` 队列在 `backpack_presenter` 存活时会被 `consume_pending_backpack_card_id` 掏空（买卡信号双监听：SaveManager 入队 + presenter 立即 consume），读这个队列会看到"空"。
- 正确数据源优先级：**① `InstanceRegistry.get_all_instance_ids()`（真·实例全集，永不被 consume）→ ② SaveManager 队列（presenter 未存活/旧档迁移兜底）→ ③ BlueprintManager 蓝图（已解锁但未拥有任何实例的卡，补一条无养成模板行）**。
- 去重：完整 instance_id 去重（`cold_t72#1` ≠ `cold_t72#2`，各自保留一行）；蓝图裸 card_id 仅在该 card_id **没有任何实例**时补一条。
- `modification_panel` 是参考实现：按 base card_id 分组，每个实例渲染一行（带 `#N` 序号后缀）。

**铁律 3：同名卡部署到战场必须按 instance_id 精确匹配各自的实例，严禁按裸 card_id 取"首个匹配"。**
- 部署入口 `bottom_instrument_bar._on_slot_gui_input`：`BattleInputState.pending_deploy_platform_card_id` 必须传 `instance_id`（非空时），不是裸 card_id。
- `get_loadout_by_platform_card_id(id)` 同时支持 instance_id 精确匹配（优先）和 card_id 回退（兼容旧卡）。
- `_reach_alive_limit_for_card` 的"同卡上限"检查用裸 base card_id（按卡种统计），**不是** instance_id——两者语义不同，不可混用。

### 关键链路速查

```
买卡  store_panel → InstanceRegistry.create_instance(card_id) → 注册实例 + emit card_added_to_backpack
                                                                    ├─ backpack_presenter._on_card_added → _data.add_extra_card
                                                                    └─ SaveManager fallback → 入队（presenter存活时立即被consume）

装备  phase_instrument_manager.equip_card(slot, card) → 槽位存 card 对象（实例）；存档存 instance_id

读档  _restore_loadout → 按 instance_id 从 Registry 取实例（get_instance）；裸 card_id 回退取首个同名实例（push_warning）

部署  bottom_instrument_bar → 传 instance_id → request_player_deploy →
       _reach_alive_limit_for_card(base_card_id)  # 上限按卡种
       get_loadout_by_platform_card_id(instance_id)  # 精确取该实例
       → _build_stats_cached(platform_card实例)  # stats 已含该实例养成

显示  card_info_panel._show_player_unit → _resolve_source_instance_card(unit) → 按 unit.source_instance_id meta 取实例卡
```

### 已踩过的坑（勿重复）

| 坑 | 现象 | 根因 | 修复 |
|----|------|------|------|
| 强化/改造面板列表按裸 card_id 去重 | 同名卡只显示一条 | `cold_t72#1`/`#2` 被折叠 | 按完整 instance_id 去重 |
| 面板列表读 SaveManager 队列 | 买卡后列表看不到新卡 | presenter 存活时队列被 consume 掏空 | 改读 InstanceRegistry 全集 |
| 强化面板选模板强化 | 强化一张卡→所有同名卡都变 | 选中 `DefaultCards.get_card_by_id` 共享模板并改其 enhance_level | 选中实例卡 + instance_id 守卫拒模板 |
| 部署传裸 card_id | 同名卡战场属性都相同 | loadout 按 card_id 回退取"首个匹配" | 部署传 instance_id 精确匹配 |
| 上限检查传 instance_id | 同名卡上限统计错位 | 按 instance_id 统计而非卡种 | 剥离 #序号 得 base_card_id 再统计 |

### 涉及的关键文件

- `managers/instance_registry.gd` — `create_instance`/`get_instance`/`get_all_instance_ids`/`get_instances_by_card_id`/`get_card_id_of`/`clone_for_instance`
- `managers/save_manager.gd` — `_pending_backpack_ids`/`_last_known_extra_ids`/`consume_pending_backpack_card_id`/`get_pending_backpack_ids`/`get_last_known_backpack_ids`/`_set_last_known_extra_ids_direct`
- `data/default_cards.gd` — `get_card_by_id`（**共享模板，只读**）/`clone_for_instance`
- `resources/card_resource.gd` — `clone()`（深拷贝，养成隔离的基础）/`instance_id`/`enhance_level`/`mods`/`module_slots`
- `managers/blueprint_manager.gd` — `apply_reinforcement`/`install_modification`（写入传入实例的养成字段）/`get_all_blueprint_ids`
- `managers/phase_instrument_manager.gd` — `equip_card`（存实例对象）/`get_loadout_by_platform_card_id`（instance_id 精确匹配 + card_id 回退）/`_restore_loadout`
- `managers/battle/battle_spawn_system.gd` — `request_player_deploy`（上限用 base_card_id，loadout 用原 id）
- `scenes/ui/bottom_instrument_bar.gd` — `_on_slot_gui_input`（部署传 instance_id）
- `scenes/ui/growth_panel.gd` — `_load_unlocked_cards`（Registry 全集数据源 + 完整 instance_id 去重）
- `scenes/ui/reinforcement_panel.gd` — `_refresh_card_list`（实例感知）/`_on_reinforce_pressed`（instance_id 守卫）
- `scenes/ui/modification_panel.gd` — `_refresh_card_list`（参考实现：分组+每实例一行）/`_install_modification`（守卫）
- `scenes/ui/card_info_panel.gd` — `_resolve_source_instance_card`（战场单位按 meta 取实例）

## v7.x 全面系统检查修复 (2026-06-28)

基于全项目三维度审查（数据一致性/潜在bug/死代码），修复 2 CRITICAL + 5 HIGH + 3 MEDIUM + 清理项。

**CRITICAL:**
| # | 文件 | 修复 |
|---|------|------|
| C1 | `instance_registry.gd` `_serialize_weapon_slots` | `_mod_effects` 取值后显式 typeof 校验，非 Dictionary 一律存 {}。原 `(x as Dictionary).duplicate(true)` 在异常值时 null 解引用崩溃，中断整个 save_state 丢失所有养成数据 |
| C2 | `battle_spawn_system.gd` `_build_stats_cached` | `faction_skill_states` 链式 `.has()` 加空值+类型守卫。原势力切换瞬间 null 上调 `.has()` 崩溃 |

**HIGH:**
| # | 文件 | 修复 |
|---|------|------|
| H1 | `enemy_phase_field_driver.gd` | boss 产兵加成补齐 defense_light/armor/air 三维（原只乘标量） |
| H2 | `enemy_phase_field_driver.gd` | 新增 `_sync_enemy_weapon_slot_damage()`，在符文/序列/仪器/tier 四处 attack 乘区后同步 weapon_slots[].damage。根因：AI 伤害结算读 weapon.damage（非 attack_damage），而原 `_sync_weapon_slots_damage` 方法在 UnitStats **从未定义**——has_method 守卫恒 false，同步空转 |
| H3 | `enemy_phase_masters.gd` `_derive_runes` | 用 `RandomNumberGenerator` + `hash(master_id)` 种子，保证同相位师每次符文一致（原裸 randi） |
| H4 | `power_tiers.gd` | 战力门槛 `[150,300,600,1000]` → `[150,260,420,720]`。原值过严，满强化稀有卡够不到 ELITE，rare/epic/legendary 改造几乎装不上 |
| H5 | `quest_manager.gd` | 本地 quest_progress_changed/quest_accepted 信号转发连接到 SignalBus（原 9 处 emit 只手动补 1 处镜像） |

**MEDIUM:**
| # | 修复 |
|---|------|
| M2 | `mod_manager.gd` get_modification_count/has_enemy_origin_mod 双 key 兼容（instance_id 与裸 card_id） |
| M6 | DebugLog 节点名统一为 `DebugLogManager`（7 处引用 + lazy_loader 配置）。预加载触发因 ManagerLazyLoader 对该脚本 .new() 失败已撤回，保持按需 |
| M7 | `blueprint_manager.gd` 修正过时注释（HP 下限 v6.8 起不再按时代缩放） |

**LOW:** ui_lazy_loader/main.gd 残留 print 加 DEBUG 守卫；删除 5 处孤儿 preload。

**验证:** Godot --check-only 启动到 133 卡构建无语法错误；Grep 链路核对全部通过。

## v7.x 相位师等级战力派生 (2026-06-28)

**背景:** 用户提出"相位师等级能不能和战力挂钩"。调查发现 `level`（Lv5-30）是手填值，与相位师 stats/equipment 没数学关系，却驱动符文稀有度/出兵序列/掉落梯度。而 `MasterPowerEvaluator` 虽已有 1-7★ 星级评估（接入战斗定 boss 星级），但**完全不读 `master.stats`**（max_hp/attack_power 等），只读 phase_instrument.base_stats —— 导致一战→近未来 HP 涨 9×/ATK 涨 8× 却不进战力分，星级分布偏低。

**核心改动:** 等级改派生 + MasterPowerEvaluator 纳入 master.stats。

**5 个改动点:**

| # | 改动 | 详情 |
|---|------|------|
| 1 | **G 维「军团本体战力」** | `MasterPowerEvaluator` 新增第 7 维 `_eval_master_stats`，读 master.stats 五项（max_hp/attack_power/defense/energy_regen/unit_limit）。复用 A 维标准化模式（value/REF × 500 × 内部权重 + 非线性加成）。基准值取 30 条相位师 stats 中位数（MASTER_REF_HP=3000 等）；内部权重 HP/ATK 各 0.30（区分度最强），DEF/EREG/ULIM 共 0.40。权重调整：B（刻印）0.25→0.20、F（装备槽）0.25→0.20，让出 0.20 给 G，总和仍 = 1.0。我方相位师无 master.stats → G 维回退 0，行为零变化 |
| 2 | **等级派生函数** | `EnemyPhaseMasters.compute_display_level(master)` 把总战力线性映射到 Lv5-30（250 分→Lv5，6000 分→Lv30，区间外 clamp）。另有 `get_display_level_by_id` 便捷重载 |
| 3 | **掉落梯度改用星级** | `game_manager.gd` 相位师击败掉落从 `level*40 → get_tier_by_power` 改为 `星级 → get_tier_by_stars → Tier`，让改造稀有度真正跟随相位师战力 |
| 4 | **get_tier_by_stars** | `PowerTiers` 新增映射：1★→GRUNT, 2★→VETERAN, 3★→ELITE, 4★/5★→CHAMPION, 6★/7★→OVERLORD，越界 clamp 到 [1,7] |
| 5 | **UI 显示战力** | `card_info_panel.gd` 两处（点击基地/点击相位师单位）等级改派生 Lv + 新增"总战力：XXXX · ★★★★★ 大师"行 |

**关键设计决策:**
1. **等级派生只接管展示+掉落**——底层 `_derive_runes`/`_derive_spawn_sequence`/`_era_from_level` 继续读原始手填 level，不打乱"一战相位师拿 common+rare 符文"的时代递进设计。派生 Lv（展示）≠ 原始 level（设计基准），两者语义不同不冲突
2. **G 维纳入 master.stats 五项**——这是区分度最强的分量（HP 9×、ATK 8×），修好后敌方有效评估权重从 0.75 提到 0.85
3. **STAR_TIERS 阈值不动**——加 G 维后总分会小幅上移（原 3★ 可能变 4★），属预期效果（之前偏低正因为 stats 不计分），实机观察后再决定是否微调
4. **职责分离**——派生函数放 `enemy_phase_masters.gd`（数据聚合入口），不放 `MasterPowerEvaluator`（评估器不应关心 Lv 展示规则）

**不动的东西（向后兼容）:** 原始 level 字段（30 条数据 + JSON，底层继续读）、STAR_TIERS 阈值、排行榜 enemy_phase_leaderboard 的 score（排名分非战力分）、get_masters_by_level 筛选、玩家侧评估（无 stats → G 维 0）。

**关键文件:**
- `scripts/master_power_evaluator.gd` — G 维 _eval_master_stats + MASTER_REF_*/MSW_* 常量 + 权重调整 + evaluate()/_build_details 接入
- `data/enemy_phase_masters.gd` — compute_display_level/get_display_level_by_id + preload MasterPowerEvaluator
- `data/power_tiers.gd` — get_tier_by_stars
- `managers/game_manager.gd` — 掉落梯度改用星级
- `scenes/ui/card_info_panel.gd` — 两处显示改派生 Lv + 战力行 + preload MasterPowerEvaluator

**验证:** Godot --check-only 通过（133 卡构建）；新增 `tests/master_power_smoke.gd`（SceneTree 模式，7 项断言全 PASS：G维空=0、master_001 G维 255.4、master_030 G维 1810、时代比值 7.1×、派生Lv 全部在[5,30]、master_030 Lv>master_001、get_tier_by_stars 9 case 全对、30 相位师 evaluate 全部不崩星级 1-7）。**注:** GdUnit4 插件存在 Godot 4.5.1 兼容性问题（`Class "GdUnitAssertImpl" hides a global script class`），现有 test_enemy_stat_resolver.gd 同样无法运行，故本次新增测试采用 smoke test 模式（与 star_config_smoke.gd 一致），不依赖 GdUnit 框架。

## v7.x 卡牌战力射程修复 + 相位师4分量战力重构 (2026-06-28)

**背景:** 用户提出两件事——① 卡牌战力公式有 bug："一个开局能买的大炮战力却能突破元帅级，是不是射程因素考虑太多"。② 把相位师战力对齐为"4分量"：卡牌战力 + 相位仪战力 + 符文（含符文之语）战力 + 载卡战力。并澄清：玩家侧载卡可重复部署（×3 经验权重），敌方侧看 unit_limit。

**修复 A：卡牌战力射程失控 bug**

根因核实：`combat_power_from_unit_stats`(evolution_helpers.gd:228) 用 `stats.attack_range`（像素值），而 `attack_range = range_value × 100`（unit_stats_table.gd:40 格转像素）。火炮 range_value=99 → 9900像素 → 射程项 `9900×0.22 = 2178`，**单这一项就破元帅阈值(1450)**；步兵3格→300像素→66分，火炮是步兵的 **33 倍**，完全淹没 HP/DPS 项。

| 修复 | 详情 |
|------|------|
| 射程项改平方根 | `range_f * 0.22`（像素）→ `sqrt(格数) * 8.0`，格数 = attack_range/100。步兵3格→13.9分，火炮99格→79.6分，比例 1:5.7（保留射程区分度但不碾压）。其他项权重不变 |

**实测验证:** ww1_105mm 火炮战力 修复前 2178+（破元帅）→ 修复后 **431.4**（合理）；ww1_mauser 步兵 91.1（量级正常）。

**重构 B：相位师 4 分量战力（MasterPowerEvaluator）**

把相位师战力对齐为用户的 4 分量设想。维度从 7 个扩到 8 个（A-H），权重重新分配，总和=1.00：

| 维度 | 权重 | 说明 |
|------|------|------|
| A 相位仪本体 | 0.15 | 不变（读 phase_instrument.base_stats） |
| B 刻印 | 0.10 | 0.20→0.10（让位 F/H） |
| C 特质 | 0.10 | 不变 |
| D 主动技能 | 0.10 | 0.15→0.10 |
| E 被动技能 | 0.10 | 不变 |
| **F 载卡战力** | 0.20 | **重构**：原"槽数×60"→ 卡牌战力加权（敌方=平台卡×unit_limit；玩家=卡战力×3） |
| G 军团本体 | 0.15 | 0.20→0.15（master.stats） |
| **H 符文+符文之语** | 0.10 | **新增**（原完全没评符文） |

**3 个新增/重构函数:**
- `_eval_runes(master)`（H维）：单符文 primary_effect.value × RUNE_STAT_WEIGHT(200) + 稀有度基础分；符文之语调 `RunewordMatcher.check_active_runewords()` 查激活词，按 TIER 加权(T2×100/T3×200/T4×350/T5×600) + effects 求和。clamp 800 上限防多词叠加爆分。
- `_eval_equipment_slots`（F维重构）：敌我分流——敌方读 EnemyPhaseEquipment 平台卡 stats 轻量公式（hp×0.5+atk×3+def×1.5）求和 × unit_limit；玩家 ×3（经验权重）。通过 `master.stats.max_hp` 是否存在判敌我。
- `_platform_power_light(platform_id, is_enemy)`：平台卡轻量战力（平台卡只有原始 stats 字典，无 UnitStats/range/interval，不能套完整公式）。

**配套：敌方符文派生改造（让 H 维有意义）**

原 `_derive_runes`（enemy_phase_masters.gd）随机抽 2-4 个 generic 符文，**不触发符文之语**（符文之语需特定组合）。改为**符文之语驱动**：按 level 选 TIER（Lv≤9→T2，Lv10-19→T2/T3，Lv20-29→T3/T4，Lv30→T4/T5）→ 从该 TIER 随机选一个符文之语 → 取它的 `required_runes` 作为装备符文（必然能组成该词）→ 槽位富余补 generic。沿用 H3 用 master_id 哈希种子保证可复现。

**关键设计决策:**
1. **射程用平方根而非除回格数**——除回格数后步兵3格→0.66几乎不算；平方根压平后步兵13.9/火炮79.6，比例1:5.7（非33:1），保留射程区分度又不会失控
2. **敌方平台卡用轻量公式**——平台卡只有 stats 字典（无 UnitStats），不能套 `combat_power_from_unit_stats`；轻量公式量级与完整公式同档（~100-500）
3. **符文之语驱动派生**——改 _derive_runes 让敌方符文必然组成词，H 维才反映符文之语加成（而非散装符文）
4. **H 维 clamp 800**——符文之语可叠激活多个+高 TIER，原始分易破千（实测 master_030 派5符文触发多词→原始9029），clamp 上限避免 H 维主导总分
5. **B/C/D/E 降权保留**——用户4分量是"物质战力"，但技能/特质也是相位师强弱的一部分，降权（非删除）保留避免丢失维度

**关键文件:**
- `managers/evolution/evolution_helpers.gd` — `combat_power_from_unit_stats` 射程项改 sqrt
- `scripts/master_power_evaluator.gd` — F维重构 + H维新增 + 权重重分配（8维总和=1.0）+ preload RuneDefs/RunewordDefs/RunewordMatcher + `_platform_power_light`
- `data/enemy_phase_masters.gd` — `_derive_runes` 改符文之语驱动 + `_derive_runes_generic_fallback` 兜底 + preload RunewordDefs

**验证:** Godot --check-only 通过（133 卡构建，exit 0）；`tests/master_power_smoke.gd` 全 PASS（修复A：火炮431<元帅1450、火炮>步兵；重构B：H维符文>0、F维载卡近未来>一战、G维时代递进、派生Lv[5,30]、get_tier_by_stars 9case、rw_2_01符文之语激活验证）。Grep 链路核对通过。**注:** smoke test 因 `--script` 模式下 `EnemyPhaseMasters.ENEMY_MASTERS` 静态 var 不初始化（项目既有限制），相位师测试改用手动构造的真实结构 dict 验证公式逻辑本身。

**实测数值（手动构造 master）:** master_001 总分359（F载卡800 G本体255 H符文800 2★精英）；master_030 总分940（F载卡2400 G本体1810 H符文800 3★高手）；派生Lv master_001=5 master_030=8（近未来更高）。

## v7.x 星级阈值校准 + 符文/符文之语拆分独立维 (2026-06-28)

**背景:** 前两轮加了 G维(本体)和 H维(符文)后总分结构变化，旧 `STAR_TIERS` 阈值（250/600/1200/2200/3800/6000）让 6★/7★ 永远为空、4★/5★ 割裂。同时用户要求"符文、符文之语都分别有计分"——原 H 维把两者合并成一个数，应拆成两个独立维各自计权重。

**阶段1：STAR_TIERS 阈值校准（基于真实分布）**

先解决数据获取障碍：发现 `EnemyPhaseMasters.LEGACY_ENEMY_MASTERS` 静态 var 跨类初始化顺序 bug（`_WW1.ERA_MASTERS + _WW2...` 求值时其他子文件 ERA_MASTERS 尚未初始化 → 拼接得 0），导致 `--script` 模式下 `ENEMY_MASTERS` 为空。**绕过方案**：直接遍历 5 个时代子文件的 ERA_MASTERS 收集 30 个相位师真实分布（不依赖聚合 var）。

实测 30 相位师总分分布：434~2210（最弱 master_001=434，最强 master_020=2210）。按分位数标定新阈值：

| 星级 | 旧阈值 | 新阈值 | 旧分布 | 新分布 |
|------|--------|--------|--------|--------|
| 1★ 新锐 | 0-250 | 0-450 | 0 | 1 |
| 2★ 精英 | 250-600 | 450-540 | 0 | 9 |
| 3★ 高手 | 600-1200 | 540-650 | 13 | 8 |
| 4★ 大师 | 1200-2200 | 650-780 | 1 | 6 |
| 5★ 宗师 | 2200-3800 | 780-950 | 1 | 3 |
| 6★ 传说 | 3800-6000 | 950-1600 | 0 | 1 |
| 7★ 神话 | 6000+ | 1600+ | 0 | 2 |

新分布钟形覆盖全 7 档（1/9/8/6/3/1/2），旧分布严重失衡（6★/7★ 全空、3★/2★ 扎堆）问题修复。派生 Lv 映射区间同步从 250/6000 改为 434/2210 贴合实际分布（最弱→Lv5，最强→Lv30，时代递进清晰）。

**阶段2：H/I 维拆分（符文 vs 符文之语独立计分）**

把原合并 H 维（符文+符文之语一起算 scores.runes）拆成两个独立维：

| 维度 | 权重 | 计分内容 |
|------|------|---------|
| H 单符文战力 | 0.06 | 稀有度基础分 + primary_effect.value × RUNE_STAT_WEIGHT(200) + secondary × 0.5，clamp 500 |
| I 符文之语战力 | 0.06（新增）| RunewordMatcher 查激活词，按 TIER 加权(T2×100/T3×200/T4×350/T5×600) + effects 求和 × RUNEWORD_EFFECT_WEIGHT(150)，clamp 600 |

权重重分配（9维总和=1.0）：B刻印 0.10→0.08（让位 I 维）。拆分后符文和符文之语在评分表里各自一行，分别计权重。

**关键文件:**
- `scripts/master_power_evaluator.gd` — STAR_TIERS 新阈值 + compute_display_level 区间注释（实际在 enemy_phase_masters.gd）；H 维 `_eval_runes` 去符文之语部分只留单符文；新增 I 维 `_eval_runewords`；W_RUNES 0.10→0.06 + W_RUNEWORDS 0.06 新增；evaluate/scores/total/_build_details 接入 I 维
- `data/enemy_phase_masters.gd` — `compute_display_level` 映射区间 250/6000 → 434/2210

**验证:** Godot --check-only 通过（exit 0）；smoke test 全 PASS（H单符文>0、I符文之语>0 各自独立、rw_2_01 拆分验证 H=89 I=137.5）。实测：master_001 总分318（H符文500 I词156 1★新锐）、master_030 总分926（H符文500 I词600 5★宗师）；30 相位师星级分布 1/9/8/6/3/1/2 钟形覆盖全 7 档。

**已知技术债（范围外）:** `EnemyPhaseMasters.LEGACY_ENEMY_MASTERS` 静态 var 跨类初始化 bug（拼接时其他子文件未初始化得 0）——本绕过（直接遍历子文件），根因修复需把 LEGACY 改成延迟函数，留待后续。

## v7.x 改造效果审计 + 情报面板翻译表补齐 (2026-06-28)

**背景:** 用户要求审计"改造相关有多少没实装、多少对游戏无用、多少无法在情报面板正确显示"。对全 9 改造模块文件（133 改造，70 个 effect key）做三维度审查。

**审计结论（三个核心数字）:**

| # | 指标 | 数值 | 说明 |
|---|------|------|------|
| ① | **未实装（战斗空转）** | **10 / 70** | 全是光环协同类（ally_*/formation_bonus/command_efficiency），落入 `_apply_single_mod_effects` 的 default 分支被塞进 `_special`，而 `unit_stats_table._apply_mod_stat_effects` 完全不读 `_special` |
| ② | **对当前游戏无用** | **10** | 就是上述 10 个（需独立光环系统才能生效）。另有 ~35 个属"数值生效但语义错位"（如 night_bonus 实际给暴击率而非真夜战逻辑） |
| ③ | **情报面板无法正确显示** | **44 / 70**（修复前） | `card_info_panel._translate_mod_key()` 仅 29 条翻译，44 个 key 显示原始英文（如 `command_efficiency: 15`）。改造面板 `modification_panel._translate_effect_key()` 则全覆盖 |

**10 个未实装的光环协同类改造:**
inf_19单兵电台(ally_bonus)、arm_15数据链(ally_hit_bonus)、for_10指挥塔(ally_hit_bonus)、eng_09弹药补给车(ally_ammo)、eng_08战场急救站(ally_hp_regen)、eng_07发电机(ally_fort_regen)、eng_10伪装网(ally_detection)、eng_04架桥设备(ally_river_bonus)、gen_06激光指示器(ally_arty_bonus)、air_12数据链系统(formation_bonus)、gen_02数字化单兵(command_efficiency)。需独立光环系统，本范围外。

**本轮修复（用户选择"只修显示"）:**

`scenes/ui/card_info_panel.gd` 的 `_translate_mod_key()` 从 29 条补齐到 70 条全覆盖。key 集合与 `modification_panel._translate_effect_key()` 对齐，文案用情报面板简短风格（轻攻/重攻/暴击 vs modification_panel 的"对轻装攻击/对装甲攻击/暴击率"）。补齐的 41 个 key 涵盖：暴抗/还击/持续射击/视野系/三防系/巷战系/弹药系/隐蔽系/光环协同系/武器型号等。

**设计决策:**
1. **只修显示不改战斗逻辑**——光环系统（10 个 key）工作量大且需独立设计，本轮范围外；战斗卡属性类 v6.6 修复后已 0 遗漏，无需动 _apply_single_mod_effects
2. **补齐而非复用**——card_info_panel 是懒加载 Node，跨面板直接调 modification_panel._translate_effect_key 有时序风险；维护一份简短风格副本更稳妥，且情报面板本就需要更短的文案
3. **两表 key 集合对齐但文案不同**——modification_panel 用完整文案（玩家专注查看改造），card_info_panel 用简短文案（情报面板空间有限）。Grep 核对：card_info_panel 覆盖了 modification_panel 除稀有度词(common/epic 等)和武器槽倍率(slot_*)之外的全部 effect key

**验证:** Godot --check-only 通过（exit 0）；Grep 覆盖率核对——card_info_panel 101 行 match 分支覆盖全部 70 个 effect key（modification_panel 的 slot_*/稀有度词除外，与改造效果显示无关），0 个 key 裸露显示英文。

**未处理（留待后续）:**
- 语义错位（~35 个 key，如 night_bonus 实际给暴击）——v6.6 设计决策"语义重定向让数值生效"，文案与机制不符但不影响战斗平衡，可后续重做战场环境系统时统一

## v7.x 光环协同改造实装（重映射为自身加成）(2026-06-28)

**背景:** 上轮审计发现 11 个光环协同改造（10 个 effect key）全部落 `_apply_single_mod_effects` default 分支被塞进 `_special` 空转，而 `unit_stats_table._apply_mod_stat_effects` 明确不读 `_special`。用户选择"不做光环系统，改为装载单位自身战斗属性加成"（复用 v6.6/v7.5 重映射模式）。

**10 个 effect key 重映射（全部 ×0.5 缩放，因原值按"多友军受益"设计）:**

| effect key | 改造 | 重映射目标 | 复用模式 |
|-----------|------|-----------|---------|
| ally_bonus | 单兵电台 | crit_chance +0.015 | v6.6 命中→暴击口径 |
| ally_hit_bonus | 数据链/指挥塔 | crit_chance +0.05/+0.075 | 同上 |
| ally_ammo | 弹药补给车 | 三维攻速 ×1.15 | ammo_capacity 模式 |
| ally_hp_regen | 急救站 | hp_regen +0.0015 | 直接加成 |
| ally_fort_regen | 发电机 | 三维防御 ×1.12 | 二次缩放×0.25（堡垒回血给非堡垒自身折半） |
| ally_detection | 伪装网 | dodge_chance +0.15 | detection_reduce 模式（取绝对值） |
| ally_river_bonus | 架桥设备 | deploy_delay_bonus -0.0025 | urban_move_bonus 模式 |
| ally_arty_bonus | 激光指示器 | attack_armor ×1.10 | 对装甲伤害 |
| formation_bonus | 数据链系统 | 三维攻击 ×1.075 | "全属性微升"按字面 |
| command_efficiency | 数字化单兵 | 三维防御 ×1.075 | 指挥效率=整体耐打 |

**关键设计决策:**
1. **不做光环系统，改为自身加成**——光环需新建单位间协同传递机制太重；重映射到现有战斗属性零新机制，复用 v6.6 验证过的模式
2. **×0.5 缩放**——原 effect 值按"给周围多个友军加 buff"设计，改为"装载单位单受益"后必须减半平衡，否则 +15%暴击/攻击偏强
3. **ally_fort_regen 二次缩放（×0.25）**——堡垒回血给非堡垒单位自身，强度再降一档（发电机装在工兵车上，不是堡垒）
4. **数据层原值保留**——与 move_speed/attack_interval 处理一致，effects 字段不动，只在应用闸门 `_apply_single_mod_effects` 重定向

**关键文件:**
- `scripts/systems/modification_registry.gd` — `_apply_single_mod_effects` 在 default 分支前插入 10 个 match 分支（L468-517）
- `tests/aura_mods_smoke.gd`（新增）— 11 个真实改造重映射验证

**验证:** Godot --check-only 通过（exit 0）；aura_mods_smoke 全 PASS（11 个改造全部不再落 _special，写入正确字段且数值符合 ×0.5 缩放预期：crit_chance/dodge_chance 加法叠加、三维攻击/防御/攻速乘法叠加、hp_regen 直接加成）。Grep 核对 10 个 key 全在 match 分支 L468-517，无残留 default 落入。

**实测数值:** 单兵电台 crit+0.015、数据链 crit+0.05、指挥塔 crit+0.075、弹药车 攻速×1.15、急救站 hp_regen+0.0015、发电机 防御×1.12、伪装网 闪避+0.15、架桥 部署加速5%、激光 对装甲×1.10、数据链系统 三维攻击×1.075、数字化单兵 三维防御×1.075。全部温和增益，无超模。

## v7.x 改造描述文案校正 + 闪避/架桥数值平衡修复 (2026-06-28)

**背景:** 用户指出 10 个改造的描述文案与实际生效效果明显不符（经 v6.6/v7.5/v7.x 多轮重映射后，文案还停留在原始设计意图），要求把描述改成实际效果，并修复发现的两个数值隐患。

**A. 描述文案校正（10 个改造，6 个数据文件）:**

| 改造 | 文件 | 改前描述 → 改后描述 |
|------|------|-------------------|
| 主动防护 | armor_mods | 拦截30% → 减伤30%（拦截机制重定向为减伤） |
| 热成像瞄准镜 | armor_mods | 无视烟雾+射程 → 射程+30（无视烟雾未实装） |
| 扫雷滚/犁 | armor_mods | 免疫地雷 → 三维防御提升（地雷免疫重定向为减伤） |
| 烟幕弹发射器 | anti_air_mods | 闪避制导武器 → 闪避+30%（反导闪避重定向为通用闪避） |
| 光学伪装 | recon_mods | 暴击率提升 → 暴击+50%（侦测范围走 vision 类映射暴击） |
| 红外抑制 | recon_mods | 热成像免疫 → 减伤提升（重定向为减伤） |
| 消音器 | recon_mods | 开火暴露降低 → 闪避+50%上限（重定向为闪避，限幅0.50） |
| 架桥设备 | engineer_mods | 友军涉渡 → 部署加速5%（重定向为自身部署，系数修复） |
| 通风过滤系统 | fort_mods | 免疫生化攻击 → 减伤提升（重定向为减伤） |
| 数字化单兵 | universal_mods | 指挥效率提升 → 三维防御+7.5%（重定向为自身防御） |

**B. 两个数值隐患修复:**

| # | 问题 | 修复 |
|---|------|------|
| 1 | **闪避值过高**：消音器 fire_exposure=-0.80 映射闪避+0.80（半无敌），光学伪装/伪装网等同路径偏高 | 所有闪避映射分支（detection_reduce / lock_reduction / fire_exposure / aggro_reduce / missile_dodge / ally_detection）统一 `min(0.50)` 上限。消音器 0.80→0.50，其余在阈值内的不变 |
| 2 | **架桥设备系数太弱**：ally_river_bonus=1.00(百分比) ×0.005×0.5=0.0025（0.25%部署加速，无感） | 系数 0.0025→0.05（×20倍），epic 稀有度获得 5% 部署加速体感 |

**关键设计决策:**
1. **闪避统一上限 0.50**——闪避是"完全免伤"的随机机制，0.80 意味着 80% 攻击无效（接近无敌），0.50 是合理的"高闪避单位"天花板。数据层直接给 dodge_chance 的小值改造（inf_08/inf_13 的 0.03-0.15）仍走原 min(1.0) 路径不受影响
2. **架桥系数提升 20 倍**——ally_river_bonus 是百分比语义（1.00=100%涉渡）不是像素值，原按像素口径×0.005×0.5 换算导致 epic 改造几乎无效果；改为×0.05（5%部署加速）匹配稀有度
3. **描述暴露真实机制**——不回避"重定向"事实，括号注明原机制→现机制，让玩家理解为何"拦截导弹"实际是"减伤"

**关键文件:**
- `scripts/systems/modification_registry.gd` — 闪避映射 6 处分支 min(1.0)→min(0.50)；架桥设备系数 0.005×0.5→0.05
- `data/modification_modules/armor_mods.gd` — 3 个描述更新
- `data/modification_modules/anti_air_mods.gd` — 1 个描述更新
- `data/modification_modules/recon_mods.gd` — 3 个描述更新
- `data/modification_modules/engineer_mods.gd` — 1 个描述更新（架桥）
- `data/modification_modules/fort_mods.gd` — 1 个描述更新
- `data/modification_modules/universal_mods.gd` — 1 个描述更新

**验证:** Godot --check-only 通过（exit 0）；运行时验证 5 项全 PASS（消音器 0.80→0.50、伪装迷彩 0.20 不变、架桥 0.0025→0.05、烟幕 0.30 不变、红外干扰机 0.25 不变）。
