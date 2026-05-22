# Leaderboard System

> **Status**: Designed
> **Source**: `managers/leaderboard_manager.gd`, `data/leaderboard_definitions.gd`
> **Last Updated**: 2026-04-24

## Overview

Leaderboard System manages 12 local leaderboards across 6 categories (challenge, speed, damage, wins, collection, progress). Each leaderboard tracks player scores with configurable sort order (ascending for time, descending for everything else), max entry limits (20-100), and reset periods (daily/weekly/monthly/never). `LeaderboardManager` is the autoload entry point; `LeaderboardDefinitions` (preloaded `RefCounted`) provides static configuration. The system is currently **local-only** — no network leaderboard implementation.

## Player Fantasy

Players see how they stack up across multiple dimensions — not just "who has the most wins" but fastest clear times, highest single-hit damage, collection completion percentage, and survival wave records. The leaderboard panel motivates optimization: "Can I clear this level faster?" or "Can I push my survival record to 20 waves?"

## Detailed Rules

### Leaderboard Categories (6 categories, 12 boards)

| Category | Leaderboards | Sort Order | Max Entries | Reset |
|----------|-------------|------------|-------------|-------|
| **Challenge** | survival_highscore, time_attack_best | Descending | 100, 50 | Weekly, Daily |
| **Speed** | fastest_clear_all, fastest_level_clear | **Ascending** (lower is better) | 20, 50 | Never, Monthly |
| **Damage** | highest_single_damage, total_damage_dealt | Descending | 30, 100 | Weekly, Monthly |
| **Wins** | total_wins, win_rate | Descending | 100, 50 | Never, Monthly |
| **Collection** | collection_completion, blueprint_unlocked | Descending | 100, 50 | Never, Never |
| **Progress** | highest_level, all_stars | Descending | 100, 50 | Never, Never |

### Score Submission Flow

1. Source system calls `update_battle_stats()`, `update_level_progress()`, etc.
2. Manager updates `_player_scores` internal tracking dictionary
3. Manager auto-submits to relevant leaderboards via `submit_score()`
4. If player already has an entry, only updates if new score is higher (or lower for time)
5. Leaderboard sorted, truncated to max_entries, ranks recalculated
6. `score_updated` signal emitted; `new_high_score` emitted if rank improved

### Entry Structure

Each leaderboard entry contains: `player_id` (OS unique ID + "player_" prefix), `player_name` (from SocialSystemManager, fallback "Player"), `score`, `rank` (1-based), `timestamp` (unix), `additional_data`.

### Player Stats Tracked

| Stat | Type | Default |
|------|------|---------|
| total_wins | int | 0 |
| total_battles | int | 0 |
| highest_damage | int | 0 |
| total_damage | int | 0 |
| fastest_clear | float | INF |
| survival_best | int | 0 |
| collection_completion | float | 0.0 |
| blueprint_count | int | 0 |
| highest_level | int | 1 |
| total_stars | int | 0 |

### Score Formatting

| Format | Display | Example |
|--------|---------|---------|
| waves | "波次 N" | "波次 15" |
| kills | "击杀 N" | "击杀 42" |
| time | "MM:SS" | "03:25" |
| damage | "N,NNN 伤害" | "12,500 伤害" |
| wins | "胜场 N" | "胜场 100" |
| percentage | "N.N%" | "85.3%" |
| count | "N" | "47" |
| level | "关卡 N" | "关卡 12" |
| stars | "N" | "15" |

### Rank Colors

| Rank | Color |
|------|-------|
| 1st | Gold (1.0, 0.8, 0.2) |
| 2nd | Silver (0.75, 0.75, 0.75) |
| 3rd | Bronze (0.8, 0.5, 0.2) |
| 4-10 | Green (0.2, 0.8, 0.4) |
| 11-50 | Blue (0.3, 0.6, 0.9) |
| 51+ | Gray (0.7, 0.7, 0.75) |

## Formulas

### Collection Completion Rate

```
collection_completion = (unlocked_cards / total_cards) * 100.0
```

### Sort Order

```
Descending (default): score_a > score_b
Ascending (FASTEST_CLEAR_TIME): score_a < score_b
```

### Rank Calculation

```
rank = index + 1  (1-based)
```

### Truncation

```
if leaderboard.size() > max_entries:
    leaderboard.resize(max_entries)
```

## Edge Cases

- **Unknown leaderboard ID**: `submit_score()` logs error and returns empty dict
- **Player already has entry**: Updates only if new score beats existing (higher for normal, lower for time)
- **Player not found**: `get_player_rank()` returns -1
- **SocialSystemManager null**: Player name defaults to "Player"
- **Import invalid JSON**: `import_leaderboard()` returns false on parse error
- **Reset leaderboard**: `reset_leaderboard()` clears entries for one board; `clear_all_leaderboards()` clears all
- **Deferred initialization**: `_deferred_init()` ensures player_scores are initialized in first idle frame, not during autoload tree setup

## Dependencies

### Depends On
- `LeaderboardDefinitions` — preloaded `RefCounted` with all board configs, entry factory, formatters
- `SaveManager` — persists leaderboard data and player scores via `save_state()` / `load_state()`
- `SocialSystemManager` — provides player name for leaderboard entries

### Depended On By
- Battle system — reports battle outcomes via `update_battle_stats()`
- Level system — reports progress via `update_level_progress()`
- Collection system — reports completion via `update_collection_progress()`
- Blueprint system — reports count via `update_blueprint_count()`
- Challenge modes — reports survival/speed records

## Tuning Knobs

| Parameter | Current Value | Location | Effect |
|-----------|--------------|----------|--------|
| Max entries per board | 20-100 (per board) | `LeaderboardDefinitions.LEADERBOARDS` | Leaderboard size limit |
| Reset periods | daily/weekly/monthly/never | Per-board config | How often entries are cleared |
| Score format strings | 9 formats defined | `LeaderboardDefinitions.format_score()` | Display formatting |
| Auto-submit boards | 5 boards on battle, 2 on level | `update_battle_stats()`, `update_level_progress()` | Which boards update automatically |

## Acceptance Criteria

- [ ] 12 leaderboards load from `LeaderboardDefinitions.LEADERBOARDS`
- [ ] Score submission updates existing entry only if score improves
- [ ] Fastest-clear-time boards sort ascending (lower time = higher rank)
- [ ] All other boards sort descending (higher score = higher rank)
- [ ] Leaderboard truncates to `max_entries` after sort
- [ ] Ranks are 1-based after every sort
- [ ] `score_updated` signal emitted on every submission
- [ ] `new_high_score` signal emitted only when rank improves
- [ ] `get_top_entries(id, count)` returns min(count, board_size) entries
- [ ] `get_player_rank()` returns -1 when player not found on board
- [ ] Save/load preserves all leaderboard data and player scores
- [ ] `import_leaderboard()` rejects invalid JSON
- [ ] Score formatting matches 9 defined format types
