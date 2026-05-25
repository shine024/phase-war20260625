# Quest System

> **Status**: Designed
> **Source**: `managers/quest_manager.gd`, `data/quest_definitions.gd`
> **Last Updated**: 2026-04-24

## Overview

Quest System manages freely-accepted progression objectives ("委托任务") with 15 objective types spanning combat, collection, crafting, and faction interactions. Players can accept up to 5 quests simultaneously. Progress is tracked via a mix of internal counters (wins, kills, enhance count) and real-time queries (fragment counts, card counts, reputation). Quest definitions come from `QuestDefs` (preloaded `RefCounted`). Rewards are auto-granted on completion — no manual claim step.

## Player Fantasy

Players pick up quests from a quest board, choosing objectives that align with their current goals. Progress updates in real-time as they play naturally. Completing a quest grants blueprint fragments, nano materials, and sometimes faction reputation or blueprint unlocks. The 5-slot limit creates meaningful choices about which objectives to pursue.

## Detailed Rules

### Objective Types (15 total)

| Type | Tracks | Tracking Method | Target Format |
|------|--------|----------------|---------------|
| `win_battles` | Battle victories | Internal counter | int (N wins) |
| `kill_enemies` | Enemies defeated | Internal counter | int (N kills) |
| `clear_level` | Specific level cleared | Cleared levels list | int (level number) |
| `collect_fragments` | Blueprint fragments | Real-time query BlueprintManager | `{total: N}` or `{card_id: count}` |
| `attack_faction` | Defeat specific phase master | Internal defeated masters list | `{target_master: name, target_faction: id}` |
| `defend_faction` | Defeat master in faction territory | Internal + faction check | `{defend_faction: id}` |
| `enhance` | Enhancement operations | Internal counter | int (N enhances) |
| `collect_cards` | Total blueprints owned | Real-time query BlueprintManager | int (N cards) |
| `research_law` | Laws researched | Internal counter | int (N laws) |
| `reach_reputation` | Max faction reputation | Real-time query FactionSystemManager | int (reputation level) |
| `buy_items` | Shop purchases | Internal counter | int (N purchases) |
| `quick_win` | Win within time limit | Internal best time tracker | float (seconds) |
| `perfect_battle` | 3-star victories | Internal counter | int (N perfect wins) |
| `survive_waves` | Maximum survival waves | Internal best waves tracker | int (N waves) |

### Quest Lifecycle

1. **Accept**: Player calls `accept_quest(quest_id)` — checks slot limit (max 5), definition exists, not already accepted
2. **Progress**: Events from battle/enhancement/shop/etc. call `notify_*()` methods or SignalBus signals
3. **Check**: After each progress event, `_try_complete()` evaluates `is_quest_done(quest_id)`
4. **Complete**: If done, rewards auto-granted via `_grant_rewards()`, quest removed from active, ID added to `_completed_ids`
5. **Abandon**: Player can `abandon_quest()` to free a slot — progress is lost
6. **Signal**: `quest_completed` emitted with quest_id and rewards dict

### Progress Tracking Methods

- **Signal-driven**: `SignalBus.battle_ended` (wins), `SignalBus.unit_died` (kills)
- **Notify methods**: `notify_law_researched()`, `notify_item_bought()`, `notify_battle_result()`, `notify_fragments_changed()`, `notify_phase_master_defeated()`
- **Real-time queries**: Fragment counts via BlueprintManager, card counts via BlueprintManager, reputation via FactionSystemManager

### Reward Types

| Reward Type | Grant Method | Description |
|-------------|-------------|-------------|
| `blueprint_fragments` | `BlueprintManager.add_blueprint_fragment()` | `{card_id: count}` dict |
| `nano_materials` | `BlueprintManager.add_nano_materials()` | int amount |
| `unlock_blueprint` | `BlueprintManager.unlock_blueprint()` | card_id string |
| `faction_reputation` / `faction_rep` | `FactionSystemManager.add_faction_reputation()` | `{faction_id: delta}` dict |
| `company_rep` | `FactionSystemManager.add_faction_reputation()` | `{company_id: delta}` dict |

### Slot Management

- `MAX_ACCEPTED = 5`
- `accept_quest()` returns false if at capacity
- `abandon_quest()` frees a slot; progress is lost (not preserved)
- `get_accepted_quest_ids()` returns current active quest IDs
- `is_completed_ever()` checks if a quest was ever completed (persisted in `_completed_ids`)

## Formulas

### Fragment Progress (total mode)

```
progress = min(100, (have / need) * 100)
```

### Fragment Progress (per-card mode)

```
progress = min(ratio) for each card_id in target:
  ratio = have(card_id) / need(card_id)
progress *= 100
```

### Quick Win Check

```
done = best_time > 0.0 AND best_time <= target_seconds
```

### Collection Completion Query

```
current_cards = BlueprintManager.get_all_blueprint_ids().size()
done = current_cards >= target_count
```

### Max Reputation Query

```
max_reputation = max(faction.reputation for all factions)
done = max_reputation >= target_reputation
```

## Edge Cases

- **Accept at capacity**: `accept_quest()` returns false — no error signal
- **Accept unknown quest**: Returns false if `QuestDefs.get_by_id()` returns empty
- **Accept already accepted**: Returns true (idempotent)
- **BlueprintManager null**: Fragment/card quests show 0 progress, never complete
- **FactionSystemManager null**: Reputation queries return 0
- **Defend faction quest with wrong current faction**: `get_quest_progress_for_mission()` returns 0
- **Abandoned quest progress lost**: `abandon_quest()` erases from `_accepted` — no recovery
- **Completed quest re-accept**: `is_completed_ever()` prevents re-completion but doesn't block re-accept (progress restarts)
- **SignalBus null**: `_ready()` checks `if SignalBus:` before connecting — safe for editor

## Dependencies

### Depends On
- `QuestDefs` — preloaded `RefCounted` with quest definitions (`data/quest_definitions.gd`)
- `LevelInformation` — preloaded `RefCounted` for faction lookup per level
- `BlueprintManager` — queries fragment counts, card counts; grants blueprint rewards
- `FactionSystemManager` — queries max reputation; grants faction reputation rewards
- `SignalBus` — listens for `battle_ended` and `unit_died`
- `GameManager` — provides `current_level`
- `SaveManager` — persists accepted quests and completed IDs

### Depended On By
- Battle system — emits battle_ended and unit_died signals
- Enhancement system — calls `notify_*()` after enhancement completion
- Enhancement system — calls enhancement notification
- Shop system — calls `notify_item_bought()`
- Phase master battles — calls `notify_phase_master_defeated()`
- Quest UI panel — displays progress, handles accept/abandon

## Tuning Knobs

| Parameter | Current Value | Location | Effect |
|-----------|--------------|----------|--------|
| MAX_ACCEPTED | 5 | `quest_manager.gd:33` | Maximum simultaneous quests |
| Quest definitions | External data | `data/quest_definitions.gd` | All quest configs, targets, rewards |
| Auto-grant rewards | Immediate on completion | `_try_complete()` | No manual claim step |
| Progress persistence | Full save/load | `save_state()`/`load_state()` | Active quests and completed history |

## Acceptance Criteria

- [ ] `accept_quest()` rejects when 5 quests already active
- [ ] `accept_quest()` rejects unknown quest IDs
- [ ] `accept_quest()` is idempotent for already-accepted quests
- [ ] Battle victory increments `win_battles` counter for all active quests
- [ ] Enemy death (non-player) increments `kill_enemies` counter
- [ ] Cleared levels tracked uniquely — same level doesn't double-count
- [ ] `collect_fragments` with `{total: N}` checks `BlueprintManager.get_total_fragment_count()`
- [ ] `collect_fragments` with `{card_id: count}` checks per-card fragment counts
- [ ] `quick_win` tracks best time, completes when best_time <= target
- [ ] `defend_faction` checks current level faction matches defend target
- [ ] Rewards auto-granted on completion — blueprint fragments, nano, reputation
- [ ] `abandon_quest()` removes quest and frees slot
- [ ] `_completed_ids` persists across save/load
- [ ] `quest_completed` signal emitted with rewards dict on completion
