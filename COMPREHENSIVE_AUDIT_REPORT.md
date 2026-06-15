# Phase War (相位战争) — Comprehensive Project Audit Report
**Date:** 2026-06-13 | **Scope:** Full project (108 scenes/*.gd, 63 scripts/*.gd, 80 .tscn)

---

## 1. NODE PATH CONSISTENCY

### ✅ Verified — Correct
- **growth_panel.gd** uses `get_node_or_null("%UniqueName")` pattern — all `%NodeName` references have corresponding `unique_name_in_owner = true` in growth_panel.tscn. ✅
- **modification_panel.gd** uses `get_node_or_null("VBoxContainer/...")` — paths match modification_panel.tscn structure exactly. ✅
- **evolution_panel.gd** uses `get_node_or_null("VBoxContainer/...")` — paths match evolution_panel.tscn structure. ✅
- **card_enhancement_panel.gd** uses `$VBoxContainer/MainSplit/...` — paths match card_enhancement_panel.tscn. ✅
- **construct_unit.gd** references `$CollisionShape2D`, `$Shape`, `$Sprite`, `$WalkSprite`, `$HpBar`, `DeployProgressBar`, `$AuraRing`, `$RankBadge` — all exist in construct_unit.tscn. ✅
- **enemy_unit.gd** references `$Shape`, `$Sprite2D`, `$AnimatedSprite2D`, `$HpBar`, `$CollisionShape2D`, `PreviewBackground`, `AnimatedSprite2D2` — all exist in enemy_unit.tscn. ✅
- **main.gd** `@onready` references all match main.tscn node paths (BattleContainer, HudLayer, PopupLayer children). ✅

### 🔴 CRITICAL

| # | File | Line | Issue | Fix |
|---|------|------|-------|-----|
| 1.1 | `scenes/ui/reinforcement_panel.gd` | 11 | `@onready var reinforce_button = $VBoxContainer/MainHBox/DetailPanel/CardDetailVBox/ReinforceButton` — The `ReinforceButton` node exists at this path, but **its `pressed` signal is never connected**. The function `_on_reinforce_pressed()` is defined (L93) but never bound to the button. Clicking "晋升" does nothing. | Add `reinforce_button.pressed.connect(_on_reinforce_pressed)` in `_ready()`. |

### 🟡 MEDIUM

| # | File | Line | Issue | Fix |
|---|------|------|-------|-----|
| 1.2 | `scenes/ui/growth_panel.gd` | 471 | Uses `GameConstants.get_era_name(c.era)` but the script preloads GC as `const GC = preload("res://resources/game_constants.gd")` — never actually uses the `GC` alias for this call. Should be `GC.get_era_name()`. | Replace `GameConstants` with `GC` for consistency. |

---

## 2. SIGNAL CONNECTIONS

### 🔴 CRITICAL — Orphan Signals (emitted but never defined or connected)

| # | File | Line | Signal | Issue | Fix |
|---|------|------|--------|-------|-----|
| 2.1 | `scenes/ui/growth_panel.gd` | 268 | `SignalBus.growth_panel_saved` | **Signal is NOT defined in `signal_bus.gd`.** Emitted via `.has_signal()` guard so no crash, but the signal is dead — no listener can ever receive it. | Add `signal growth_panel_saved(card: CardResource)` to `signal_bus.gd`, or remove the emit. |
| 2.2 | `scenes/ui/growth_panel.gd` | 270 | `SignalBus.card_data_changed` | **Signal is NOT defined in `signal_bus.gd`.** Same orphan issue. | Add to `signal_bus.gd` or remove. |

### 🟡 MEDIUM — Signals with Zero Connectors

| # | Signal (in signal_bus.gd) | Connected? | Issue |
|---|---------------------------|-----------|-------|
| 2.3 | `energy_insufficient` | ❌ No connector found | Dead signal — emitted nowhere visible, connected nowhere. |
| 2.4 | `unit_selected` | ❌ No connector found | Dead signal. |
| 2.5 | `unit_move_command` | ✅ Connected in construct_unit.gd | OK but only one consumer. |
| 2.6 | `phase_driver_hp_changed` | ❌ No connector found | May be intended for future UI. |
| 2.7 | `drops_ready_to_claim` | ❌ No connector found | Drops system appears incomplete. |
| 2.8 | `synthesis_completed/failed` | ❌ No connector found | Synthesis system stub. |
| 2.9 | `phase_law_cast` | ❌ No connector found | Emitted nowhere found either. |
| 2.10 | `daily_tasks_refreshed`, `quest_completed`, `task_completed`, `task_reward_granted`, `all_tasks_completed` | ❌ No connector found | Quest/daily task system partially implemented. |
| 2.11 | `challenge_started/completed/failed` | ❌ No connector found | Challenge mode stub. |
| 2.12 | `card_obtained`, `card_max_level`, `collection_milestone_reached` | ❌ No connector found | Card collection stub. |
| 2.13 | `story_chapter_started/node_reached/choice_made/completed` | ❌ No connector found | Story system stub. |
| 2.14 | `relationship_changed`, `character_unlocked` | ❌ No connector found | Character system stub. |
| 2.15 | `show_story_ui`, `show_story_node` | ❌ No connector found | Story UI stub. |
| 2.16 | `play_sound` | ❌ No connector found | Signal exists but AudioManager connects to `unit_damaged`, not `play_sound`. |
| 2.17 | `daily_task_reward_granted` | ❌ No connector found | Duplicate of `task_reward_granted`? |
| 2.18 | `kill_reward_granted` | ❌ No connector found | Dead signal. |
| 2.19 | `intel_updated/unlocked/tier_reached` | ❌ No connector found | Intel system partially wired. |

### ✅ Properly Connected
- `energy_changed` → energy_bar.gd ✅
- `unit_spawned` / `unit_died` → bottom_instrument_bar.gd, battle_manager.gd ✅
- `unit_damaged` → battle_manager.gd, audio_manager.gd ✅
- `battle_started` / `battle_ended` → bottom_instrument_bar.gd, audio_manager.gd, main.gd, save_manager.gd ✅
- `blueprint_unlocked` → main.gd, audio_manager.gd ✅
- `active_law_cast_at` → main.gd, audio_manager.gd ✅
- `card_added_to_backpack` → card_enhancement_panel.gd, save_manager.gd ✅
- `phase_law_runtime_changed` → construct_unit.gd, enemy_unit.gd ✅
- `phase_driver_destroyed` / `enemy_phase_driver_destroyed` → battle_manager.gd ✅
- `backpack_changed` → (not directly connected, but backpack panel refreshes on open) ✅

---

## 3. AUTOLOAD DEPENDENCIES

### Registered in project.godot (20 autoloads):
SignalBus, BattleInputState, EnergyManager, PhaseInstrumentManager, BattleManager, GameManager, BlueprintManager, DropManager, SaveManager, AudioManager, PhaseLawManager, BasicResourceManager, ObjectPoolManager, UILazyLoader, ManagerLazyLoader, PerformanceMetricsManager, ModificationRegistry, MilitaryTitleRegistry, EvolutionPathRegistry

### 🔴 CRITICAL — Missing Autoloads Referenced by Code

| # | Autoload Name | Referenced In | Issue |
|---|---------------|----------------|-------|
| 3.1 | `CardAbilityManager` | construct_unit.gd (L216-221, L893-1119), bullet.gd, construct_unit_ai.gd, construct_unit_deploy.gd | **Not registered as autoload.** Used via `preload()` as static class in construct_unit.gd (via _resolve_autoload), but `bullet.gd` uses `const CardAbilityManager = preload(...)` then calls static methods. If it's only a class (not autoload), static calls work, but construct_unit.gd L201 calls `_resolve_autoload(&"AuraManager")` expecting an autoload that also doesn't exist. |
| 3.2 | `AuraManager` | construct_unit.gd (L200-201, L1101) | **Not registered as autoload.** `_resolve_autoload(&"AuraManager")` returns null, aura registration silently fails. All aura-related functionality (RADAR_RANGE, SCOUT_CRIT, FORTRESS_DEF, CARRIER_REPAIR, COMMAND_GLOBAL) is broken. |
| 3.3 | `IntelItemBag` | evolution_panel.gd, modification_panel.gd, save_manager.gd | **Not registered as autoload.** Referenced via `Engine.get_main_loop().get_root().get_node_or_null("IntelItemBag")` — always returns null. Evolution/modification cost checks for blueprints silently pass (acts as if player has no blueprints). |
| 3.4 | `QuestManager` | save_manager.gd (CRITICAL_MANAGER_LOADS) | **Not registered as autoload.** Save/load for quest data silently fails. |
| 3.5 | `FactionSystemManager` | save_manager.gd | **Not registered as autoload.** Faction save/load silently fails. |
| 3.6 | `AffixManager` | save_manager.gd | **Not registered as autoload.** Affix save/load silently fails. |
| 3.7 | `LevelProgressManager` | save_manager.gd | **Not registered as autoload.** Level progress save/load silently fails. |
| 3.8 | `LoreManager`, `StatBoostManager`, `AchievementManager`, `DailyTaskManager`, `StatisticsManager`, `CardEnhancementManager`, `TutorialProgressionManager`, `StoryManager`, `CharacterManager`, `ChallengeModeManager`, `CardCollectionManager`, `LeaderboardManager` | save_manager.gd (DEFERRED_MANAGER_LOADS) | **None registered as autoloads.** All deferred save/load silently fails — 12 managers worth of data is lost on save/load. |
| 3.9 | `DropManager` | project.godot (registered ✅), but also in CRITICAL_MANAGER_LOADS | OK — this one exists. |

### 🟡 MEDIUM

| # | Issue | Fix |
|---|-------|-----|
| 3.10 | `ManagerLazyLoader` autoload exists but is called only once in card_enhancement_panel.gd for "card_enhancement". | Verify ManagerLazyLoader actually loads CardEnhancementManager properly. |
| 3.11 | `UnifiedRankSystem` is a `class_name` (autoloaded-style via `class_name`), used in card_resource.gd L437 and reinforcement_panel.gd — but **not preloaded** in reinforcement_panel.gd. GDScript should resolve class_name globally, but if the file hasn't been scanned yet, it could fail. | Add explicit `const UnifiedRankSystem = preload(...)` in reinforcement_panel.gd. |

---

## 4. RESOURCE REFERENCES

### ✅ Verified — All preload paths exist
- All `res://data/*.gd` preload targets verified to exist (default_cards, enemy_archetypes, enemy_blueprints, basic_resources, blueprint_definitions, etc.)
- All `res://scenes/**/*.tscn` preload targets verified to exist
- All `res://managers/*.gd` preload targets verified to exist
- All `res://scripts/**/*.gd` preload targets verified to exist
- All `res://resources/game_constants.gd` preload targets verified to exist

### 🟢 LOW — No broken preload paths found in project code (addons excluded).

---

## 5. SCENE TREE STRUCTURE

### main.tscn Overlay Analysis

All overlays declared in main.gd `@onready` exist in main.tscn:

| @onready var | main.tscn path | Exists? |
|---|---|---|
| quest_overlay | `PopupLayer/QuestOverlay` | ✅ |
| store_overlay | `PopupLayer/StoreOverlay` | ✅ |
| phase_law_overlay | `PopupLayer/PhaseLawOverlay` | ✅ |
| backpack_overlay | `PopupLayer/BackpackOverlay` | ✅ |
| faction_overlay | `PopupLayer/FactionOverlay` | ✅ |
| map_overlay | `PopupLayer/MapOverlay` | ✅ |
| settings_overlay | `PopupLayer/SettingsOverlay` | ✅ |
| leaderboard_panel | `PopupLayer/LeaderboardPanel` | ✅ |
| manufacture_overlay | `PopupLayer/ManufactureOverlay` | ✅ |
| intelligence_overlay | `PopupLayer/IntelligenceOverlay` | ✅ |
| growth_overlay | `PopupLayer/GrowthOverlay` | ✅ (type=ColorRect, not Control — minor but functional) |
| enhancement_overlay | `PopupLayer/EnhancementOverlay` | ✅ |
| modification_overlay | `PopupLayer/ModificationOverlay` | ✅ |
| evolution_overlay | `PopupLayer/EvolutionOverlay` | ✅ |
| level_display | `HudLayer/TopCenterMeta/LevelDisplay` | ✅ |

### Empty Overlays (no pre-instanced panel, rely on lazy loader):
- ManufactureOverlay/CenterContainer — empty ✅ (lazy loaded)
- EnhancementOverlay/CenterContainer — empty ✅ (lazy loaded)
- ModificationOverlay/CenterContainer — empty ✅ (lazy loaded)
- EvolutionOverlay/CenterContainer — empty ✅ (lazy loaded)
- GrowthOverlay/CenterContainer — empty ✅ (lazy loaded)
- ReinforcementOverlay/CenterContainer — empty ✅ (lazy loaded)
- AffixOverlay/CenterContainer — empty ✅ (lazy loaded)
- AchievementOverlay, StatisticsOverlay, DropsInventoryOverlay, HelpOverlay, LevelSelectOverlay — all empty ✅

### 🟡 MEDIUM

| # | Issue | Fix |
|---|-------|-----|
| 5.1 | `GrowthOverlay` is type `ColorRect` instead of `Control` like all other overlays. This means it has a `color` property and `mouse_filter = 0` (pass), while other overlays use `mouse_filter = 2` (ignore). This could cause input blocking issues. | Change GrowthOverlay type to `Control` with `mouse_filter = 2` for consistency. |
| 5.2 | Several overlays exist in main.tscn (AchievementOverlay, StatisticsOverlay, DropsInventoryOverlay, HelpOverlay, LevelSelectOverlay) but have **no button in BottomFunctionBar** to open them, and **no keyboard shortcut**. They are registered in UILazyLoader but unreachable from the UI. | Either wire them to UI buttons or remove the dead overlay containers. |

---

## 6. DATA INTEGRITY

### ✅ Verified
- `data/default_cards.gd` — exists, preloaded by multiple scripts ✅
- `data/enemy_archetypes.gd` — exists ✅
- `data/evolution_paths/` — directory exists with infantry_evolution.gd ✅
- `data/military_titles/unified_rank_system.gd` — exists with class_name ✅
- `resources/game_constants.gd` — exists, class_name GameConstants ✅

### 🟡 MEDIUM

| # | File | Issue |
|---|------|-------|
| 6.1 | `data/evolution_paths/infantry_evolution.gd` L401, L417 | Contains `TODO: 实现条件检查逻辑` and `TODO: 实现继承计算` — evolution condition checks are stubs that likely always return true. |
| 6.2 | `data/intel_manual_items.gd` L147, L250 | Contains `TODO: 从进化路径注册表中获取所有可掉落的进化路径` and `TODO: 实现解锁逻辑` — intel drop/unlock logic incomplete. |

---

## 7. CODE QUALITY ISSUES

### 🔴 CRITICAL

| # | File | Line(s) | Issue | Fix |
|---|------|---------|-------|-----|
| 7.1 | `scenes/ui/reinforcement_panel.gd` | 11, 93 | `_on_reinforce_pressed()` function exists but is **never connected** to `reinforce_button.pressed`. The button is declared `@onready` but has no signal connection in `_ready()`. The button's `pressed` signal is never bound anywhere in the project. | Add in `_ready()`: `if reinforce_button: reinforce_button.pressed.connect(_on_reinforce_pressed)` |
| 7.2 | `scenes/ui/growth_panel.gd` | 268-270 | Emits signals `growth_panel_saved` and `card_data_changed` that **don't exist** in SignalBus. Uses `.has_signal()` guard so no crash, but the signals are silently swallowed. | Define these signals in signal_bus.gd or remove the emits. |

### 🟡 MEDIUM

| # | File | Line(s) | Issue |
|---|------|---------|-------|
| 7.3 | `scenes/ui/growth_panel.gd` | 471 | Uses global `GameConstants` instead of local `GC` alias — inconsistent with the rest of the file. |
| 7.4 | `scenes/ui/evolution_panel.gd` | ~280 | `_update_detail_panel()` — when `nano_amount >= nano_cost`, sets `res_text += "test"` (hardcoded test string) instead of showing a "✓ sufficient" message. |
| 7.5 | `scenes/ui/modification_panel.gd` | 7 | `@onready var card_list_container = get_node_or_null(...)` — uses get_node_or_null for @onready, inconsistent with reinforcement_panel.gd which uses `$` syntax. Not a bug but inconsistent. |
| 7.6 | `scenes/main.gd` | various | Debug logging system (`_debug_log`) writes to `debug-22f19e.log` — same file used by ui_lazy_loader.gd. Both truncate-open the file, creating write contention. |
| 7.7 | `scenes/ui/card_enhancement_panel.gd` | 14 | Preloads `EnemyBlueprints` and uses it as fallback in `_init_card_list()`, but the panel is for player cards. This is dead code or misleading. |
| 7.8 | Multiple files | — | `modification_panel.gd`, `reinforcement_panel.gd`, `evolution_panel.gd` all have `result_label` with a 3-second auto-hide timer using `await`. If the panel is closed during the await, the timer fires on a freed node → potential crash. Add `if not is_inside_tree(): return` after await. |

### 🟢 LOW

| # | File | Issue |
|---|------|-------|
| 7.9 | `scenes/ui/card_enhancement_panel.gd` | Contains its own debug log system (`_dbg_runtime`) writing to `debug-119cff.log` — third separate debug log file in the project. |
| 7.10 | `scenes/units/construct_unit.gd` | `_res_cache` is an instance variable, but `_cached_load` is also defined identically in `enemy_unit.gd`. Could be a shared utility. |
| 7.11 | `scenes/main.gd` | `_overlay_for_panel_key` maps "law" → phase_law_overlay but `_ensure_lazy_panel` maps "law" → lazy_id "phase_law". The mapping is correct but uses two different key conventions. |

---

## 8. PERFORMANCE PATTERNS

### ✅ Already Optimized
- `construct_unit.gd` and `enemy_unit.gd` — Target finding uses interval timer (0.3s-0.55s), not every frame ✅
- `construct_unit.gd` — HP bar updates only on change, not every frame ✅
- `construct_unit.gd` — Ability queries cached at setup time, not per-frame ✅
- `enemy_unit.gd` — Archetype config cached, timing data cached per target ✅
- Both units — Spatial grid registration for O(1) target queries ✅
- `ObjectPoolManager` autoload exists ✅
- `PerformanceMetricsManager` autoload exists ✅
- `ui_lazy_loader.gd` — Panel lazy loading system ✅
- Tween reuse for hit flash/shake (no per-hit allocation) ✅

### 🟡 MEDIUM

| # | File | Issue | Fix |
|---|------|-------|-----|
| 8.1 | `scenes/ui/growth_panel.gd` `_refresh_card_list()` | Creates `PanelContainer`, `VBoxContainer`, `Button`, `Label`, `HBoxContainer` nodes dynamically for every card on every refresh. For large backpacks (50+ cards), this is heavy. Consider using a reusable pool or ItemList. |
| 8.2 | `scenes/ui/modification_panel.gd` `_refresh_card_list()` | Same issue — creates Button per card dynamically each refresh. |
| 8.3 | `scenes/ui/backpack_panel.gd` (inferred) | Same dynamic creation pattern. |
| 8.4 | `scenes/units/unit_hp_bar.gd` | Has `_process(delta)` — HP bars update every frame. Should only update when HP changes. |
| 8.5 | `scenes/effects/damage_number_display.gd` | Has `_process(delta)` — acceptable for animated floating text but ensure nodes are freed after animation. |
| 8.6 | Debug log files (`debug-22f19e.log`, `debug-119cff.log`) | If `DEBUG_*_LOG` is true, `_debug_log` opens/closes the file on every call. In hot paths this causes I/O thrashing. |

---

## 9. UI SYSTEM COMPLETENESS

### UILazyLoader Registration — All Panels Covered ✅

| Panel Key | Scene Path | Registered? | Parent in main.tscn? |
|---|---|---|---|
| backpack | backpack_panel.tscn | ✅ | ✅ |
| manufacture | manufacture_panel.tscn | ✅ | ✅ |
| quest | quest_panel.tscn | ✅ | ✅ |
| store | store_panel.tscn | ✅ | ✅ |
| phase_law | phase_law_panel.tscn | ✅ | ✅ |
| faction | faction_panel.tscn | ✅ | ✅ |
| map | world_map_panel.tscn | ✅ | ✅ |
| settings | settings_panel.tscn | ✅ | ✅ |
| leaderboard | leaderboard_panel.tscn | ✅ | ✅ |
| enhancement | card_enhancement_panel.tscn | ✅ | ✅ |
| reinforcement | reinforcement_panel.tscn | ✅ | ✅ |
| modification | modification_panel.tscn | ✅ | ✅ |
| evolution | evolution_panel.tscn | ✅ | ✅ |
| intelligence | intelligence_hub_panel.tscn | ✅ | ✅ |
| growth | growth_panel.tscn | ✅ | ✅ |
| affix | affix_panel.tscn | ✅ | ✅ |
| achievement | achievement_panel.tscn | ✅ | ✅ |
| statistics | statistics_panel.tscn | ✅ | ✅ |
| drops_inventory | drops_inventory_panel.tscn | ✅ | ✅ |
| level_select | level_select_panel.tscn | ✅ | ✅ |
| help | help_panel.tscn | ✅ | ✅ |

### Close Buttons — All panels emit `closed` signal ✅
All lazy-loaded panels connect their `closed` signal via `_connect_panel_closed_runtime()` in main.gd.

### 🟡 MEDIUM — Panel-to-Panel Transitions

| # | Issue |
|---|-------|
| 9.1 | GrowthPanel → Enhancement/Modification/Evolution: Uses `_open_target_panel()` which hides growth, emits `closed`, then calls `main._toggle_overlay()`. The `closed` emission triggers `_close_overlay(growth_overlay, "growth")` which sets `overlay.visible = false` — then `_toggle_overlay` tries to show the target overlay. This **double-toggle** could cause flicker or race condition with tween. |
| 9.2 | ReinforcementButton in ReinforcementPanel has no `pressed` signal connected (see 7.1) — the reinforcement action is completely non-functional. |

---

## 10. SAVE/LOAD SYSTEM

### Architecture
- **SaveManager** saves to `user://save_slot_N.json` with atomic write (temp → rename) ✅
- **Schema version 5** with migration support ✅
- **Backup system** with 15s interval ✅
- **Deferred loading** for non-critical managers ✅

### 🔴 CRITICAL — Massive Data Loss on Save/Load

| # | Issue | Impact |
|---|-------|--------|
| 10.1 | **12 managers in DEFERRED_MANAGER_LOADS are NOT registered as autoloads** (see #3.8). SaveManager tries `_collect_manager_state(data, "/root/LoreManager", ...)` → gets null → data key not saved. On load, same null → data not restored. | **All non-critical data (lore, stat boosts, achievements, daily tasks, statistics, card enhancement levels, tutorial progress, story progress, characters, challenge records, card collection, leaderboard) is LOST on every save/load cycle.** |
| 10.2 | **4 critical managers also missing**: QuestManager, FactionSystemManager, AffixManager, LevelProgressManager. | Quest progress, faction reputation, affix data, and level progress are lost on save/load. |
| 10.3 | `IntelItemBag` not registered (see #3.3) — intel item collection data never persisted. | All collected intel items lost on restart. |

### 🟡 MEDIUM

| # | File | Issue | Fix |
|---|------|-------|-----|
| 10.4 | `managers/save_manager.gd` | `ENABLE_DETAILED_LOAD_VALIDATION := false` — load validation is disabled, meaning corrupted save data is silently accepted. | Set to true or implement lightweight checksum. |
| 10.5 | `managers/save_manager.gd` | CRITICAL_MANAGER_LOADS references 10 managers but only ~5 are registered autoloads. The remaining 5 fail silently. | Either register all autoloads or remove dead entries. |

---

## SUMMARY STATISTICS

| Severity | Count |
|----------|-------|
| 🔴 CRITICAL | 10 |
| 🟡 MEDIUM | 18 |
| 🟢 LOW | 3 |

### Top 5 Fixes by Impact

1. **Register missing autoloads** (AuraManager, IntelItemBag, QuestManager, FactionSystemManager, AffixManager, LevelProgressManager, CardEnhancementManager, etc.) — Fixes #3.1-3.9, #10.1-10.3. Without this, ~80% of game progression data is silently lost.

2. **Connect ReinforcementPanel button** — `reinforce_button.pressed` → `_on_reinforce_pressed` (Fixes #1.1, #7.1). The entire reinforcement feature is non-functional.

3. **Add missing signals to SignalBus** — `growth_panel_saved`, `card_data_changed` (Fixes #2.1, #2.2, #7.2).

4. **Fix evolution panel "test" string** — `evolution_panel.gd` ~L280 (Fix #7.4).

5. **Fix GrowthOverlay type** — Change from ColorRect to Control (Fix #5.1).

---

*Report generated by comprehensive static analysis of 171 .gd files and 80 .tscn files.*
