# Tutorial System

> **Status**: Designed
> **Source**: `managers/tutorial_progression_manager.gd`
> **Last Updated**: 2026-04-24

## Overview

Tutorial System orchestrates a linear 8-step onboarding sequence that introduces new players to core game systems: card collection, equipment, battle, synthesis, factions, and phase laws. Each step contains instructional content (title, description, highlights) and an action target that triggers UI navigation via SignalBus. The system supports skip, reset, and auto-start on first launch. State persists via `SaveManager`.

## Player Fantasy

New players are guided through their first experience with clear, step-by-step instructions. Each tutorial step introduces one system at a time with highlighted UI elements showing where to look and action buttons that open the relevant panel. After completing all steps, players transition to freedom mode with full game access.

## Detailed Rules

### Tutorial Steps (8 steps, linear)

| Step | Enum | Title | Action Target | Highlights |
|------|------|-------|--------------|------------|
| 1 | INTRO_WELCOME | "欢迎来到 Phase War" | open_card_collection | 100 levels, 300+ cards, 7 factions |
| 2 | CARD_COLLECTION_INTRO | "卡牌收藏" | open_backpack | Platform=unit type, Weapon=attack, Synthesis |
| 3 | CARD_EQUIP_INTRO | "装备卡牌" | open_phase_instrument | Green=platform+weapon, Yellow=energy, Blue/Red=law |
| 4 | FIRST_BATTLE_INTRO | "首次战斗" | start_first_battle | Deploy on battlefield, protect driver, kill enemies |
| 5 | SYNTHESIS_INTRO | "卡牌合成" | open_synthesis | Card+Card merge, blueprint fragments, 80%/90% rates |
| 6 | FACTION_INTRO | "势力系统" | open_factions | 7 factions, exclusive instruments, reputation |
| 7 | PHASE_LAWS_INTRO | "相位法则" | open_phase_laws | 12 laws, 4 families, environment constraints |
| 8 | ADVANCED_TACTICS | "高级战术" | close_tutorial | Deck strategy, resource mgmt, tactical adaptation |

### Step Completion Flow

1. UI displays current step content (title, description, highlights, action button)
2. Player taps action button → `execute_tutorial_action(action_target)` called
3. Action emits SignalBus signal to open relevant UI panel
4. Player interacts with the system, then calls `complete_current_step()`
5. System marks step as completed, advances to next step
6. `tutorial_step_changed` signal emitted with new step
7. When reaching `FREEDOM_MODE` (step 9), `tutorial_completed` signal emitted

### Step Data Structure

Each step contains:
- `title` (String) — display heading
- `description` (String) — instructional text
- `highlights` (Array[String]) — bullet points shown to player
- `action_text` (String) — button label
- `action_target` (String) — action identifier for `execute_tutorial_action()`
- `highlight_elements` (Array[String]) — UI element IDs to visually highlight

### Action Targets and SignalBus Mapping

| Action Target | SignalBus Signal | Effect |
|---------------|-----------------|--------|
| open_card_collection / open_backpack | `toggle_backpack` | Opens backpack panel |
| open_phase_instrument | `toggle_phase_instrument` | Opens instrument equip panel |
| start_first_battle | `start_level(1)` | Starts level 1 |
| open_synthesis | `toggle_synthesis` | Opens synthesis panel |
| open_factions | `toggle_factions` | Opens faction panel |
| open_phase_laws | `toggle_phase_laws` | Opens law library |
| close_tutorial | `complete_current_step()` | Advances to FREEDOM_MODE |

### Skip and Reset

- **Skip**: `skip_tutorial()` immediately sets `current_step = FREEDOM_MODE`, emits `tutorial_completed`. No steps are marked as completed — skip state is indistinguishable from natural completion after load.
- **Reset**: `reset_tutorial()` sets `current_step = NONE`, clears `completed_steps`. On next `get_tutorial_content()` call, auto-advances to INTRO_WELCOME.

### Auto-Start Behavior

When `current_step == NONE`, calling `get_tutorial_content()` automatically sets step to `INTRO_WELCOME` (step 1). This means first-time players see the tutorial immediately.

## Formulas

### Completion Rate

```
completion_rate = completed_steps.size() / FREEDOM_MODE
```

Where `FREEDOM_MODE = 9`, so:
```
completion_rate = completed_steps.size() / 9.0
```

### Progress Display

```
progress = {
  current_step: enum value,
  completed_steps: int count,
  total_steps: 9,
  completion_rate: float (0.0 to 1.0)
}
```

## Edge Cases

- **NONE step auto-advance**: `get_tutorial_content()` with step NONE auto-sets to INTRO_WELCOME — no stuck state possible
- **Skip vs natural completion**: After skip, `completed_steps` is empty but `current_step == FREEDOM_MODE` — load_state restores this correctly
- **Step beyond FREEDOM_MODE**: `complete_current_step()` won't advance past FREEDOM_MODE (`next_step <= FREEDOM_MODE` check)
- **SignalBus null**: `execute_tutorial_action()` checks `if SignalBus and SignalBus.has_signal()` before emitting — safe if autoloads not ready
- **Reset after completion**: `reset_tutorial()` clears everything, next access starts from step 1
- **Duplicate completion**: `complete_current_step()` checks `not completed_steps.has(current_step)` before appending — idempotent

## Dependencies

### Depends On
- `SignalBus` — emits UI toggle signals (backpack, instrument, synthesis, factions, laws, start_level)
- `SaveManager` — persists current_step and completed_steps via `save_state()` / `load_state()`

### Depended On By
- Tutorial UI overlay — displays step content, handles action button clicks
- Battle system — first battle is triggered by tutorial step 4
- Achievement system — may unlock "complete tutorial" achievement

## Tuning Knobs

| Parameter | Current Value | Location | Effect |
|-----------|--------------|----------|--------|
| Total steps | 8 + FREEDOM_MODE | `TutorialStep` enum | Onboarding length |
| Step order | Linear, fixed | enum values 1-9 | Cannot reorder without code change |
| Tutorial data | Hardcoded in manager | `_initialize_tutorial_data()` | Content not externally configurable |
| Auto-start threshold | `current_step == NONE` | `get_tutorial_content()` | First launch triggers tutorial |

## Acceptance Criteria

- [ ] `get_tutorial_content()` returns correct content dict for current step
- [ ] NONE step auto-advances to INTRO_WELCOME on first access
- [ ] `complete_current_step()` advances to next step sequentially
- [ ] `tutorial_step_changed` signal emitted on step advance
- [ ] `tutorial_completed` signal emitted when reaching FREEDOM_MODE
- [ ] `skip_tutorial()` jumps directly to FREEDOM_MODE
- [ ] `reset_tutorial()` clears all progress, restarts from step 1
- [ ] All 7 action targets emit correct SignalBus signals
- [ ] SignalBus null-safe — no crash if autoload not ready
- [ ] `should_show_tutorial()` returns false when `current_step == FREEDOM_MODE`
- [ ] `get_tutorial_progress()` returns accurate completion rate
- [ ] Save/load preserves current_step and completed_steps
- [ ] `get_highlight_elements()` returns correct UI element IDs per step
