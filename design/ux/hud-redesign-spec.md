# HUD Redesign Spec

## 1. Overview
This specification unifies fragmented battle HUD elements into a single, state-aware structure. It implements approved decisions D1-D7 and defines migration, interaction, and accessibility behavior for implementation.

## 2. Goals
- Merge battle-critical HUD into one coherent hierarchy.
- Remove duplicate information and duplicate battle result flows.
- Keep bottom interaction throughput fast during deployment and law casting.
- Guarantee clear visibility rules by battle phase.

## 3. Information Architecture

### 3.1 Root HUD Hierarchy
- `HudLayer/BattleTopStatusBar`
  - `PlayerSpawnHUD` (left)
  - `BattleInfoDisplay` (center)
  - `EnemySpawnHUD` (right)
- `HudLayer/TopLeftMeta`
  - `ResourceInfoPanel` (compact/collapsible)
  - `LevelDisplay`
- `HudLayer/BattleBottomBar`
  - `BottomInstrumentBar` (row 1)
  - `BottomFunctionBar` (row 2)

### 3.2 Decision Mapping (D1-D7)
- **D1**: `PlayerSpawnHUD + EnemySpawnHUD` merged under one `BattleTopStatusBar`.
- **D2**: `BottomInstrumentBar + BottomFunctionBar` unified by `BattleBottomBar` parent container.
- **D3**: `BattleInfoDisplay` is promoted as top-center battle status source.
- **D4**: `ActiveLawCastPanel` is deprecated; active law cast entry remains red slot in `BottomInstrumentBar`.
- **D5**: `battle_result_dialog` is the only battle settlement system.
- **D6**: `ResourceInfoPanel` default compact mode shows 3 key resources.
- **D7**: each component follows explicit phase visibility state machine.

## 4. Component Ownership and Migration

### 4.1 Keep and Reposition
- Keep: `PlayerSpawnHUD`, `EnemySpawnHUD`, `BattleInfoDisplay`, `BottomInstrumentBar`, `BottomFunctionBar`, `ResourceInfoPanel`, `LevelDisplay`.
- Reposition under unified HUD parent containers in `HudLayer`.

### 4.2 Keep as Runtime Overlay
- Keep: `BattleClickOverlay` in battle container because it captures world-space clicks for deploy/cast/select.

### 4.3 Deprecate
- Deprecate duplicate cast entry panel: `ActiveLawCastPanel`.
- Deprecate duplicate settlement path: `battle_result_panel`.

## 5. Layout Rules (Phase 2 Visual Finalization)

### 5.1 Top Status Bar
- Anchor full width at top with 8 px margins.
- Horizontal structure: left/right fixed blocks + center flexible block.
- Recommended min heights:
  - left block (`PlayerSpawnHUD`): 90 px
  - center block (`BattleInfoDisplay`): 92 px
  - right block (`EnemySpawnHUD`): 90 px

### 5.2 Bottom Bar
- `BattleBottomBar` anchors to screen bottom and owns both rows.
- Row 1 (`BottomInstrumentBar`) height: 64 px.
- Row 2 (`BottomFunctionBar`) height: 60 px.
- Total reserved bottom space: 124 px.

### 5.3 Resource Compact Mode
- Default show: `energy`, `nano_materials`, `blueprint_fragments`.
- Expand action shows full resource list.
- In battle, compact mode is default; expansion is user-triggered.

### 5.4 Breakpoints
- >= 1280 width: full spacing and labels.
- 1024-1279 width: reduce horizontal spacing, keep all controls visible.
- < 1024 width: abbreviate labels and keep critical controls prioritized (deploy/cast/pause).

## 6. State-Aware Visibility Matrix (D7)

| Component | Preparation | Deploy | Battle | Casting | Pause | Victory | Defeat |
|---|---|---|---|---|---|---|---|
| BattleTopStatusBar | visible | visible | visible | visible | visible | visible | visible |
| PlayerSpawnHUD | hidden | visible | visible | visible | visible | hidden | hidden |
| EnemySpawnHUD | hidden | visible | visible | visible | visible | hidden | hidden |
| BattleInfoDisplay | hidden | visible | visible | visible | visible | visible | visible |
| BattleClickOverlay | hidden | visible | visible | visible | visible | hidden | hidden |
| BattleBottomBar | visible | visible | visible | visible | visible | visible | visible |
| ResourceInfoPanel (compact) | visible | visible | visible | visible | visible | visible | visible |
| LevelDisplay | visible | visible | visible | visible | visible | visible | visible |
| ResultDialog | hidden | hidden | hidden | hidden | hidden | visible | visible |

## 7. Interaction Rules
- Active law casting is triggered only from `BottomInstrumentBar` red slot in battle.
- Click-through world interactions continue to route via `BattleClickOverlay`.
- Bottom function bar keeps navigation and control actions (pause/back/save/start).

## 8. Accessibility Mapping
Based on current project interaction pattern baseline (`design/ux/interaction-patterns.md`, WCAG 2.1 AAA baseline):
- Text and key labels must preserve high contrast against panel backgrounds.
- Important state changes (battle start, cast fail, result) require non-color-only signals (text/icon).
- Interactive targets remain large enough for pointer precision (button min-height preserved).
- Focus order for keyboard navigation follows top meta -> bottom controls -> overlays.

Note: dedicated `design/ux/accessibility-requirements.md` will be backfilled in Phase 5.

## 9. Acceptance Criteria
- All D1-D7 mappings are reflected in scene hierarchy and runtime behavior.
- No duplicate settlement popup appears in a single battle.
- No separate active-law side panel is required for cast flow.
- Top status and bottom controls remain readable at target resolutions.
