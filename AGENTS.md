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
- `data/json/quest_definitions.json` — 同步（71→76 任务；story 17 个、tutorial 5 个、commission 54 个）
- `managers/game_manager.gd` — _check_story_mission_pre_battle 加 story 任务自动揭示

**验证:** Godot headless --check-only 通过；JSON 76 任务字段完整；Grep 确认 reveal_quest 钩子调用正确。
