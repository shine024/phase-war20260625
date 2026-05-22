# Daily Task System

> **Status**: Designed
> **Source**: `managers/daily_task_manager.gd`
> **Last Updated**: 2026-04-24

## Overview

Daily Task System generates 7 rotating objectives every 24 hours (3 Easy + 2 Normal + 1 Hard + 1 Expert), drawn from 8 task types. Each task tracks progress incrementally and rewards the player with nano materials, energy blocks, and blueprint fragments upon manual claim. Tasks refresh automatically based on elapsed time since last refresh, persisted via `SaveManager`.

## Player Fantasy

Players have a reason to log in every day. The daily task panel gives them a clear, achievable checklist — "win 1 battle," "kill 10 enemies," "use a phase law." Completing all 7 tasks feels satisfying and provides meaningful resources. The difficulty ramp (Easy to Expert) means there's always a stretch goal for dedicated players.

## Detailed Rules

### Task Types (8 total)

| Type | Description | Source Event |
|------|-------------|-------------|
| BATTLE_VICTORY | Win battles | `record_battle_victory()` |
| KILL_ENEMIES | Defeat enemies | Kill tracking in battle |
| COLLECT_CARDS | Obtain new cards | Card drop/collection events |
| UPGRADE_CARDS | Upgrade card star level | Star upgrade events |
| COMPLETE_LEVELS | Clear story levels | Level completion events |
| USE_PHASE_LAWS | Cast phase laws in battle | Law cast tracking |
| SYNTHESIS_CARDS | Synthesize cards | Synthesis completion events |
| EARN_XP | Gain phase instrument XP | XP gain events |

### Daily Task Composition

Each refresh generates exactly **7 tasks** with no duplicate types:

| Difficulty | Count | Purpose |
|-----------|-------|---------|
| EASY | 3 | Quick wins for casual play |
| NORMAL | 2 | Moderate engagement |
| HARD | 1 | Stretch goal |
| EXPERT | 1 | High-commitment challenge |

Since there are 8 types and 7 slots, one type is randomly excluded each day.

### Task Lifecycle

1. **Refresh**: `_check_refresh_needed()` runs on `_ready()`; if 24 hours elapsed, calls `refresh_daily_tasks()`
2. **Generation**: For each slot, pick a random unused task type, set target count based on difficulty
3. **Progress**: Source systems call `update_task_progress(task_type, amount)` to increment progress
4. **Completion**: When `current >= target`, task marked `completed = true`, `task_completed` signal emitted
5. **All Complete**: When all 7 tasks completed, `all_tasks_completed` signal emitted
6. **Claim**: Player calls `claim_task_reward(task_id)` — rewards granted, task marked `claimed = true`
7. **Next Refresh**: After 24 hours, tasks reset — unclaimed rewards from previous day are lost

### Reward Structure

Each task grants multiple reward types simultaneously. Rewards are randomized within ranges per difficulty:

| Difficulty | Nano Materials | Energy Blocks | Fragment |
|-----------|---------------|---------------|----------|
| EASY | 50-100 | 2-5 | common_fragment 1-2 |
| NORMAL | 100-200 | 5-10 | rare_fragment 1-2 |
| HARD | 200-400 | 10-20 | epic_fragment 1-2 |
| EXPERT | 400-800 | 20-40 | legendary_fragment 1-2 |

### Fragment Rewards

Fragment rewards grant blueprint copies of a random card matching the rarity tier:
- **common_fragment**: random from common card pool
- **rare_fragment**: random from rare card pool
- **epic_fragment**: random from epic card pool
- **legendary_fragment**: random from legendary card pool

Fragment grants go through `BlueprintManager.add_blueprint_copy()`.

## Formulas

### Refresh Interval

```
task_refresh_interval = 86400 seconds (24 hours)
needs_refresh = (current_time - last_refresh_time) >= 86400
```

### Task ID Generation

```
task_id = "daily_" + unix_timestamp + "_" + randi()
```

### Completion Rate

```
completion_rate = completed_count / total_tasks (7)
```

### Reward Value Estimation

```
nano_value = sum(nano_materials) + sum(energy_blocks * 20)
```

### Refresh Countdown

```
countdown = max(0, next_refresh_time - current_time)
```

## Edge Cases

- **All 8 types exhausted**: When generating the 7th+ task, if all types are used, fallback allows type reuse
- **Save loaded after refresh threshold**: `load_state()` calls `_check_refresh_needed()` — tasks auto-refresh if stale
- **Force refresh**: `force_refresh()` bypasses time check, used for testing
- **Claim already claimed task**: `claim_task_reward()` returns false if `claimed == true`
- **Claim uncompleted task**: Returns false if `completed == false`
- **BlueprintManager null**: Fragment reward grant silently skips if `BlueprintManager` autoload is null
- **BasicResourceManager null**: Nano/energy reward grant silently skips if null
- **Unclaimed rewards lost**: When tasks refresh, `_daily_tasks.clear()` is called — previous day's unclaimed rewards are discarded

## Dependencies

### Depends On
- `SaveManager` — persists task list and last_refresh_time via `save_state()` / `load_state()`
- `BasicResourceManager` — grants nano materials and energy block rewards
- `BlueprintManager` — grants blueprint fragment copies
- `SignalBus` — emits `daily_task_reward_granted` signal on reward claim

### Depended On By
- Battle system — reports victories and kills via `update_task_progress()`
- Synthesis system — reports synthesis operations
- Phase law system — reports law usage
- Level system — reports level completions
- Card system — reports card collection and upgrades

## Tuning Knobs

| Parameter | Current Value | Location | Effect |
|-----------|--------------|----------|--------|
| Refresh interval | 86400s (24h) | `_task_refresh_interval` | How often tasks regenerate |
| Tasks per day | 7 (3E+2N+1H+1X) | `plan` array in `refresh_daily_tasks()` | Total daily objectives |
| Task target counts | Type x Difficulty matrix | `_get_task_target()` | Difficulty scaling per type |
| Reward ranges | Per-difficulty pools | `_reward_pools` | Random reward amounts |
| Energy block value estimate | 20 nano | `get_task_stats():320` | Reward value calculation |

## Acceptance Criteria

- [ ] 7 tasks generated on refresh with correct difficulty distribution (3E+2N+1H+1X)
- [ ] No duplicate task types within same daily batch (when possible)
- [ ] Auto-refresh triggers after 24 hours elapsed since last refresh
- [ ] `update_task_progress()` increments only matching uncompleted tasks
- [ ] `current >= target` triggers completion, not strict equality
- [ ] `task_completed` signal emitted per task; `all_tasks_completed` when all 7 done
- [ ] `claim_task_reward()` grants rewards only for completed, unclaimed tasks
- [ ] Nano materials granted via `BasicResourceManager.add_resource()`
- [ ] Blueprint fragments granted via `BlueprintManager.add_blueprint_copy()`
- [ ] Save/load preserves task list and refresh timestamp
- [ ] Loaded stale tasks auto-refresh on `load_state()`
- [ ] `get_refresh_countdown()` returns 0 when refresh is overdue
