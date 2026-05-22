# Achievement System

> **Status**: Designed
> **Source**: `managers/achievement_manager.gd`, `managers/achievement/achievement_checker.gd`, `managers/achievement/achievement_rewards.gd`
> **Last Updated**: 2026-04-24

## Overview

Achievement System tracks long-term player milestones across 6 categories (battle, collection, progress, challenge, system, special), evaluates unlock conditions against cumulative statistics, and dispatches rewards via `AchievementRewards`. The system uses a delegated architecture: `AchievementManager` (autoload entry point) delegates condition checking to `AchievementChecker` and reward granting to `AchievementRewards`. Achievement definitions are loaded from `AchievementDefinitionsExtended` (100+ achievements, 5 rarity tiers) with a basic fallback if the autoload is absent.

## Player Fantasy

Players feel a sense of long-term progression and mastery. Every battle, collection, and exploration contributes to unlocking achievements that mark their journey. The achievement panel shows progress bars approaching completion, motivating players to push for "just one more win" or "just one more blueprint." Rare and legendary achievements serve as bragging rights.

## Detailed Rules

### Achievement Categories

| Category | Tracks | Example |
|----------|--------|---------|
| **Battle** | Combat outcomes — wins, kills, damage, streaks, masters defeated | "累计赢得100场战斗" |
| **Collection** | Cards and blueprints collected by rarity | "收集10张传说蓝图" |
| **Progress** | Level advancement, stars earned, era completion | "通关3个时代" |
| **Challenge** | Special mode completions — survival, boss rush, time attack | "完成5次生存模式" |
| **System** | Meta operations — saves, synthesis, enhancements, purchases | "执行50次合成" |
| **Special** | Manually triggered, story-related, or event achievements | "完成新手引导" |

### Achievement Rarity

| Rarity | Tier | Typical Reward Scale |
|--------|------|---------------------|
| COMMON | Green | nano 50-100 |
| UNCOMMON | Blue | nano 100-300, fragments 2-5 |
| RARE | Purple | nano 300-500, fragments 5-10 |
| EPIC | Orange | nano 500-1000, fragments 10-20, rare card |
| LEGENDARY | Red | nano 1000+, fragments 20+, guaranteed card |

### Unlock Flow

1. Gameplay event occurs (battle win, card collected, level cleared, etc.)
2. Source system calls `AchievementManager.record_*()` with event data
3. Manager updates the corresponding stats dictionary (battle_stats, collection_stats, etc.)
4. Manager calls `_check_category_achievements(category)` for the relevant category
5. `AchievementChecker.check_category()` iterates all achievements in that category
6. For each met condition that is not yet unlocked, `unlock_achievement()` is called
7. `achievement_unlocked` signal emitted with achievement_id and name
8. Progress auto-saved via SaveManager

### Reward Claiming

- Rewards are NOT auto-granted on unlock — player must manually claim via `claim_achievement_reward()`
- Claim state tracked in `reward_claimed` dictionary, persisted via SaveManager
- `get_claimable_rewards()` returns list of unlocked but unclaimed achievement IDs
- Reward types: `basic_nano` (nano materials), `energy_block` (energy blocks), `phase_xp` (instrument XP), `card` (specific card to backpack)

### Progress Display

- `get_achievement_progress(id)` returns `{current, max, percentage, unlocked, reward_claimed}`
- `get_recommended_achievements(count)` returns achievements with progress >= 50%
- `get_unlock_progress()` returns per-category completion percentages

### Statistics Tracked

**Battle Stats**: total_wins, total_battles, total_kills, total_damage_dealt, no_damage_wins, fast_wins (<=180s), win_streaks, max_win_streak, current_win_streak, masters_defeated (unique list)

**Collection Stats**: unique_blueprints (list), unique_cards (list), legendary_count, epic_count, rare_count

**Progress Stats**: max_level_reached, perfect_levels (3-star), era_completion (dict), total_playtime

**Challenge Stats**: survival_modes_completed, boss_rushes_completed, time_attacks_completed, no_loss_challenges, max_damage_dealt

**System Stats**: total_saves, manual_saves, auto_saves, synthesis_operations, enhancement_operations, shop_purchases

## Formulas

### Win Streak

```
current_win_streak += 1  (on victory)
current_win_streak = 0   (on defeat)
max_win_streak = max(max_win_streak, current_win_streak)
```

### Fast Win Threshold

```
fast_win: battle_time <= 180 seconds
```

### Progress Percentage

```
progress_percentage = (current_value / required_count) * 100
```

### Category Completion Rate

```
completion_rate = (category_unlocked / category_total) * 100
```

### Overall Completion Rate

```
overall_rate = (total_unlocked / ACHIEVEMENT_DATABASE.size()) * 100
```

## Edge Cases

- **Achievement ID not in database**: `unlock_achievement()` logs error and returns — no crash
- **Already unlocked**: Both `unlock_achievement()` and `update_achievement_progress()` check `is_achievement_unlocked()` first — idempotent
- **Load state with unknown achievement IDs**: `load_state()` filters saved IDs against current database — stale references from removed achievements are silently dropped
- **AchievementDefinitionsExtended autoload missing**: Falls back to `_setup_basic_achievements()` with 2 hardcoded achievements (first_win, wins_10)
- **Reward type not recognized**: `AchievementRewards.grant()` returns false — achievement remains unlockable but reward not granted
- **Resource manager not available**: `AchievementRewards.grant()` returns false if target manager autoload is null
- **Special achievements**: `check_single()` returns false for type "special" — must be unlocked via `unlock_special_achievement()` explicitly

## Dependencies

### Depends On
- `SaveManager` — persists achievement state (unlocked list, progress, rewards claimed, all stats)
- `StatisticsManager` — provides supplementary stat data
- `BasicResourceManager` — grants nano material and energy block rewards
- `PhaseInstrumentManager` — grants phase XP rewards
- `DropManager` — grants card rewards to backpack
- `BlueprintManager` — checks unlocked blueprint IDs for collection achievements
- `LevelProgressManager` — checks max level for progress achievements

### Depended On By
- `BattleManager` — records battle victories/defeats via `record_battle_victory()` / `record_battle_defeat()`
- Achievement UI panel — displays progress, handles reward claiming
- Tutorial system — may trigger special achievements

## Tuning Knobs

| Parameter | Current Value | Location | Effect |
|-----------|--------------|----------|--------|
| Fast win threshold | 180 seconds | `achievement_manager.gd:270` | Battles <= this time count as fast wins |
| Recommended threshold | 50% progress | `achievement_manager.gd:504` | Achievements shown as "close to completion" |
| Recent achievements count | 5 | `get_recent_achievements()` default | How many recent unlocks shown in UI |
| Reward: basic_nano amounts | 50-1000+ | `achievement_definitions_extended.gd` | Nano material reward per achievement |
| Reward: phase_xp amounts | Varies | `achievement_definitions_extended.gd` | XP reward per achievement |
| Stat reset on load | Full restore | `load_state()` | Loading save restores all stats from saved data |

## Acceptance Criteria

- [ ] 100+ achievement definitions load from `AchievementDefinitionsExtended` autoload
- [ ] Fallback to 2 basic achievements when extended definitions autoload is absent
- [ ] Battle victory updates total_wins, total_battles, kills, damage, streaks, masters_defeated
- [ ] Battle defeat resets current_win_streak and increments total_battles
- [ ] `AchievementChecker.check_single()` correctly evaluates all 24 condition types
- [ ] Unlock is idempotent — calling unlock on already-unlocked achievement is a no-op
- [ ] `achievement_unlocked` signal emitted on first unlock only
- [ ] Reward claiming requires manual player action — not auto-granted
- [ ] `reward_claimed` state persists across save/load cycles
- [ ] `load_state()` silently drops unknown achievement IDs from older saves
- [ ] Progress percentage calculation matches `(current / max) * 100`
- [ ] Recommended achievements list only includes unlocked=false and progress >= 50%
- [ ] All 5 reward types (basic_nano, energy_block, phase_xp, card, special) grant correctly
- [ ] `get_unlock_progress()` returns accurate per-category and overall completion rates
