# Player Journey (MVP)

## 1. Entry and Orientation
- Player enters `Main` scene and sees top-level battle context, resource summary, and bottom action bars.
- First objective is clear: configure phase instrument slots and start battle.

## 2. Preparation Loop
- Manage loadout through bottom controls (`backpack`, `manufacture`, `law`, `faction`, `quest`, `store`).
- Review compact resources and level progression before committing to battle.
- Trigger battle from bottom control after preparation.

## 3. Battle Loop
- Deploy from green slot -> click battlefield.
- Cast active laws from red slot -> click battlefield target.
- Observe status from top status bar:
  - left: player spawn/composition pressure
  - center: battle status/time/kill-damage summary
  - right: enemy wave pressure

## 4. Resolution Loop
- On victory/defeat, `battle_result_dialog` appears as the only settlement surface.
- Player confirms and returns to preparation state for next run.

## 5. Progression Signals
- Level display and resource changes provide short-term progression feedback.
- Battle result rewards provide medium-term goals (fragments, shards, phase XP).

## 6. Friction and Guardrails
- Keep click-input ownership on battlefield overlay to avoid cast/deploy conflicts.
- Keep battle-critical controls visible in all combat phases.
