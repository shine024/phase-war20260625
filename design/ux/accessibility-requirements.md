# Accessibility Requirements (MVP)

## 1. Scope
This document defines baseline accessibility requirements for battle HUD and core interaction flows. It extends project interaction patterns and targets WCAG 2.1 AAA-aligned behavior where practical in game UI constraints.

## 2. Visual Contrast and Legibility
- Primary HUD text must keep high contrast against panel backgrounds.
- State-critical text (battle status, cast fail, result) must remain readable at default scale.
- Resource and status icons must not be the only information carrier; pair with text labels.

## 3. Interaction Targets
- Bottom action buttons and law slots should maintain large click targets.
- Important controls (start battle, pause, cast flow entry) must stay visible in combat phases.
- Compact/expanded resource mode must be operable with one clear control.

## 4. Non-Color-Only Feedback
- Victory/defeat/status transitions require icon or text, not color alone.
- Cast/deploy failures should provide explicit textual feedback.
- Selection mode transitions should show both spatial indicator and text hint.

## 5. Input Consistency
- Same intent should map to consistent interaction:
  - deploy: select slot then click battlefield
  - cast: select law then click battlefield
- Pause state must not break basic input discoverability.

## 6. Cognitive Load Controls
- Default to compact resource display in battle.
- Keep top status layout stable across battle phases to reduce scanning cost.
- Avoid duplicated information panels in the same phase.

## 7. QA Checklist (MVP)
- HUD text readability checked at supported resolutions.
- Keyboard/pointer navigation order validated for major controls.
- Battle result shown once only, with clear confirm action.
- No duplicated cast entry panel active during battle.
