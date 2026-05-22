# UX Specification: Blueprint Collection Screen

> **Status**: Draft
> **Author**: UX Designer
> **Last Updated**: 2026-04-08
> **Screen / Flow Name**: BlueprintCollection
> **Platform Target**: PC (Steam/Epic) — Keyboard/Mouse primary
> **Related GDDs**: `design/gdd/blueprint-system.md` § Visual/Audio Requirements
> **Related ADRs**: None
> **Related UX Specs**: `design/ux/interaction-patterns.md` (all patterns), `design/ux/hud.md` (battle result integration)
> **Accessibility Tier**: Comprehensive

> **Note — Scope boundary**: This spec covers the Blueprint Collection screen (meta-game progression UI), not the in-combat fragment pickup feedback (which lives in HUD design). The screen is modal — game pauses when opened.

---

## 1. Purpose & Player Need

**What player need does this screen serve?**

The Blueprint Collection screen serves the player's need to **understand their collection progress and make meaningful upgrade choices**. Players open this screen to see what blueprints they've unlocked, how close they are to the next star level, and which blueprints are worth investing their limited nano materials into. The screen transforms raw fragment data into a visual representation of the player's long-term growth and mastery.

**The player goal**:

Find the blueprint they want to upgrade or manufacture from within three seconds of opening the screen, understand its current state (star level, fragments, next upgrade cost) at a glance, and execute the upgrade or manufacture action without navigating to sub-screens.

**The game goal**:

Communicate the player's collection progress, star upgrade options, and manufacturing availability in a way that encourages continued collection and creates celebration moments at star milestones. The screen must make the progression loop visible and satisfying.

---

## 2. Player Context on Arrival

| Question | Answer |
|----------|--------|
| What was the player just doing? | Completed a combat encounter and received blueprint fragments OR pressed the Blueprint shortcut key (B) from base/camp |
| What is their emotional state? | Anticipation — "What did I get?" or Curiosity — "How close am I to the next star?" |
| What cognitive load are they carrying? | Low — no active threats, but they may be tracking multiple fragment drops from the last battle |
| What information do they already have? | They know they just received blueprint fragments (saw the fly-to-collection animation), but not which blueprints or how many |
| What are they most likely trying to do? | Check if the new fragments pushed any blueprint to the next star level OR manufacture cards from a high-star blueprint |
| What are they likely afraid of? | Missing a star upgrade opportunity, accidentally consuming fragments needed for upgrade, wasting nano on suboptimal upgrades |

**Emotional design target for this screen**:

*Satisfying and empowering — the player should feel like a master craftsman reviewing their arsenal. Every fragment should feel like permanent progress, and star upgrades should feel like earned milestones. The screen should communicate "you are growing stronger" without demanding complex optimization.*

---

## 3. Navigation Position

**Screen hierarchy**:

```
[Root — Main Menu]
  └── [Base / Camp State]
        └── [Blueprint Collection Screen]
              ├── [Blueprint Detail Panel] (inline, not separate screen)
              ├── [Star Upgrade Confirmation Dialog]
              └── [Manufacture Confirmation Dialog]
```

**Modal behavior**: Overlay (game world visible in background but dimmed, game paused)

**Dismiss behavior**:
- Can be dismissed by pressing Escape, B (toggle), or clicking the close button
- Game state does NOT change on dismiss (all changes are committed immediately)
- No "unsaved changes" warning — blueprint state is auto-saved

**Reachability — all entry points**:

| Entry Point | Triggered By | Notes |
|-------------|-------------|-------|
| Base/Camp → Blueprint button | Player presses B or clicks Blueprint icon | Primary entry — 90% of use cases |
| Battle Result → "View Blueprints" | Player clicks button after combat results | Secondary — occurs after fragment drops |
| First unlock notification | Player clicks "View" on new blueprint unlock notification | Tutorial/introductory flow |

---

## 4. Entry & Exit Points

**Entry table**:

| Trigger | Source Screen / State | Transition Type | Data Passed In | Notes |
|---------|----------------------|-----------------|----------------|-------|
| Player presses B or clicks Blueprint icon | Base/Camp state | Overlay push — game pauses | Full blueprint collection data, newly obtained fragment IDs (if any) | Default view: all blueprints, sorted by star level (highest first) |
| Player clicks "View Blueprints" from battle result | Battle Result screen | Overlay push | Newly obtained fragment IDs (pre-highlight) | Newly obtained blueprints are visually distinguished with "New!" badge |
| First unlock notification | Base/Camp (notification overlay) | Overlay push | Newly unlocked blueprint ID (pre-selected) | First-time unlock — show brief tutorial tooltip on open |

**Exit table**:

| Exit Action | Destination | Transition Type | Data Returned / Saved | Notes |
|-------------|------------|-----------------|----------------------|-------|
| Player closes screen (Esc/B/Close button) | Previous state (Base/Camp or Battle Result) | Overlay pop — game resumes | No explicit save — blueprint state auto-saves on every change | No "discard" concept — all actions are immediate |
| Player clicks "Manufacture" and confirms | Same screen, updated state | In-place state change | Manufacture event fired, 1 fragment consumed | Card added to inventory, screen updates to reflect new fragment count |
| Player clicks "Upgrade Star" and confirms | Same screen, updated state | In-place state change | Star upgrade event fired, fragments+nano consumed | Star level increases, new affix revealed in detail panel |
| Player navigates to Inventory (shortcut) | Inventory Screen | Replace | No data | Blueprint collection state preserved if player returns |

---

## 5. Layout Specification

### 5.1 Wireframe

```
┌──────────────────────────────────────────────────────────────────────────────┐
│ [← Back]     BLUEPRINT COLLECTION     [Search...]  [Grid/List]  [? Help]  │ ← HEADER ZONE
├──────────────────────────────────────────────────────────────────────────────┤
│ Filters:                                                                   │
│ [All] [Platform] [Weapon] [Law]    Rarity: [☑] ☐ ☐ ☐ ☐   Sort: [Star▼]   │ ← FILTER BAR
├───────────────────────────────┬─────────────────────────────────────────────┤
│ ┌─────────────────────────┐   │ ┌─────────────────────────────────────────┐ │
│ │ BLUEPRINT GRID          │   │ │ DETAIL PANEL                            │ │
│ │ (or LIST VIEW)          │   │ │                                         │ │
│ │ ┌───┬───┬───┬───┐      │   │ │ ★★★ TITAN MECHA MK2                    │ │
│ │ │ ▲ │ ▲ │ ▲ │ ▲ │      │   │ │ ─────────────────────                   │ │
│ │ ├───┼───┼───┼───┤      │   │ │ Rarity: Epic  Type: Platform            │ │
│ │ │ ▲ │ ★ │ ★ │ ★ │      │   │ │                                         │ │
│ │ ├───┼───┼───┼───┤      │   │ │ ┌─────────────────────────────────────┐ │ │
│ │ │ ★ │ ★ │ ★ │ ▲ │      │   │ │ │ STAR PROGRESS                       │ │ │
│ │ ├───┼───┼───┼───┤      │   │ │ │ ████████████░░░░ 120/150            │ │ │
│ │ │ ★ │ ★ │ ★ │ ★ │ ...   │   │ │ │ 120 total fragments | 30 to next ★  │ │ │
│ │ └───┴───┴───┴───┘      │   │ │ └─────────────────────────────────────┘ │ │
│ │                       │   │ │                                         │ │
│ │ Selected: 1/45        │   │ │ ┌─────────────────────────────────────┐ │ │
│ │                       │   │ │ │ STATS (at current star)             │ │ │
│ │                       │   │ │ │ • HP: 500 (+150 from star)          │ │ │
│ │                       │   │ │ │ • Attack: 45 (+12)                  │ │ │
│ └─────────────────────────┘   │ │ • Defense: 20 (+5)                  │ │ │
│                               │ └─────────────────────────────────────┘ │ │
│ ┌─────────────────────────┐   │ │                                         │ │
│ │ LEGEND                  │   │ │ ┌─────────────────────────────────────┐ │ │
│ │ ▲ = Locked              │   │ │ │ AFFIXES (current star)              │ │ │
│ │ ★ = Unlocked            │   │ │ │ ★★: Heavy Armor +20% DEF            │ │ │
│ │ ★★★ = Selected          │   │ │ │ ★★★: Reinforced Hull +150 HP        │ │ │
│ │ ⬡ = New!               │   │ │ │ ★★★★: Auto-Repair 5 HP/sec          │ │ │
│ └─────────────────────────┘   │ └─────────────────────────────────────┘ │ │
│                               │ │                                         │ │
│                               │ │ ┌─────────────────────────────────────┐ │ │
│                               │ │ │ UPCOMING AFFIXES                    │ │ │
│                               │ │ │ ★★★★: Auto-Repair 5 HP/sec          │ │ │
│                               │ │ │ ★★★★★: Shockwave Stomp              │ │ │
│                               │ │ │ ★★★★★★: Fortification +40% DEF      │ │ │
│                               │ └─────────────────────────────────────┘ │ │
│                               │ │                                         │ │
│                               │ │ Cost: 30 fragments + 150 nano           │ │
├───────────────────────────────┴─────────────────────────────────────────────┤
│   [Upgrade to ★★★★]  [Manufacture Card]  [Add to Favorites]  [Close]      │ ← ACTION BAR
└──────────────────────────────────────────────────────────────────────────────┘
```

### 5.2 Zone Definitions

| Zone Name | Description | Approximate Size | Scrollable? | Overflow Behavior |
|-----------|-------------|-----------------|-------------|-------------------|
| **Header Zone** | Top bar: navigation, screen title, global actions (search, view toggle, help) | Full width, ~8% height | No | Search box expands to 200px on focus, truncates long titles with ellipsis |
| **Filter Bar** | Second bar: type filters, rarity filters, sort options | Full width, ~6% height | No | Filters collapse to icon-only below 1280px width |
| **Blueprint Grid** | Left/main panel: grid of blueprint icons showing all unlocked blueprints | ~60% width, ~80% height | Yes — vertical | Page-based grid: 5 columns × 4 rows per page, page indicators at bottom |
| **Detail Panel** | Right panel: stats, progress, affixes, and actions for selected blueprint | ~40% width, ~80% height | Yes — vertical | Scroll within panel for long affix lists; fade at bottom |
| **Action Bar** | Bottom: context-sensitive actions for selected blueprint | Full width, ~6% height | No | Actions collapse to icon-only below 4 items; tooltips show full text |
| **Legend** | Small reference guide (optional, can be dismissed) | ~20% width, ~10% height (bottom-left of grid) | No | Can be toggled on/off via Help menu |

### 5.3 Component Inventory

| Component Name | Type | Zone | Purpose | Required? | Reuses Existing Component? |
|----------------|------|------|---------|-----------|---------------------------|
| **Back Button** | Button | Header | Returns to previous screen | Yes | Yes — NavButton from interaction-patterns.md |
| **Screen Title Label** | Text | Header | Displays "BLUEPRINT COLLECTION" | Yes | Yes — ScreenTitle component |
| **Search Input** | Input Field | Header | Real-time filter by blueprint name | Yes | Yes — SearchInput from interaction-patterns.md §10 |
| **Grid/List Toggle** | Toggle Button | Header | Switch between grid and list view | Yes | No — new component |
| **Help Button** | Button | Header | Opens legend/tooltips | Yes | Yes — standard HelpButton |
| **Type Filter Buttons** | Radio Button Group | Filter Bar | Filter by blueprint type (All/Platform/Weapon/Law) | Yes | Yes — RadioFilter from interaction-patterns.md §10 |
| **Rarity Filter Checkboxes** | Checkbox Group | Filter Bar | Multi-filter by rarity (Common/Uncommon/Rare/Epic/Legendary/Mythic) | Yes | Yes — CheckboxFilter from interaction-patterns.md §10 |
| **Sort Dropdown** | Dropdown | Filter Bar | Sort order (Star Level/Fragments/Name/Rarity) | Yes | Yes — standard Dropdown |
| **Blueprint Slot** | Icon + Frame + Badge | Blueprint Grid | Represents one blueprint (locked/unlocked/new) | Yes | No — new component (custom grid item) |
| **Star Progress Bar** | Progress Bar | Detail Panel | Shows fragments toward next star | Yes | Yes — ProgressBar from interaction-patterns.md §3 |
| **Fragment Counter** | Text | Detail Panel | Shows total fragments and fragments to next star | Yes | Yes — StatText component |
| **Affix Card** | Card + Icon | Detail Panel | Displays one affix with star level indicator | Yes | No — new component (affix preview) |
| **Upgrade Button** | Primary Button | Action Bar | Initiates star upgrade (opens confirmation) | Yes | Yes — PrimaryAction from interaction-patterns.md |
| **Manufacture Button** | Secondary Button | Action Bar | Initiates card manufacturing (opens confirmation) | Yes | Yes — SecondaryAction component |
| **Confirmation Dialog** | Modal Dialog | Overlay | Confirms destructive actions (upgrade/manufacture) | Yes | Yes — ConfirmationDialog from interaction-patterns.md §5 |
| **Empty State Message** | Text + Icon | Blueprint Grid | Shown when filters match 0 blueprints | Yes | Yes — EmptyState component |
| **New Badge** | Badge + Icon | Blueprint Slot | "New!" indicator on recently obtained blueprints | Yes | Yes — NotificationBadge component |

**Primary focus element on open**: The first blueprint slot in the grid (highest star level, or newly obtained blueprint if deep-linked from battle result). If the grid is empty (no blueprints unlocked), focus lands on the Search input.

---

## 6. States & Variants

| State Name | Trigger | What Changes Visually | What Changes Behaviorally | Notes |
|------------|---------|----------------------|--------------------------|-------|
| **Loading** | Screen is opening, blueprint data not yet loaded | Blueprint Grid shows skeleton/shimmer placeholders; Detail Panel shows "Loading..." | No interactions possible except Close and Back | Should not be visible >300ms under normal conditions; investigate if slower |
| **Empty — no blueprints unlocked** | New game, player has not obtained any fragments | Blueprint Grid replaced by EmptyState: icon + "No blueprints yet. Complete battles to collect blueprint fragments!" | Detail Panel shows placeholder; Action Bar hidden except Close | Extremely rare — players should have starter blueprints by default |
| **Populated — blueprints available** | At least one blueprint unlocked | Blueprint Grid fills with blueprint slots; first slot auto-focused | All navigation and actions available | Default and most common state |
| **Blueprint Selected** | Player navigates to a blueprint slot | Detail Panel populates with selected blueprint's data; selected slot has focus ring and ★★★ badge | Action Bar updates to show valid actions (Upgrade/Manufacture based on state) | Upgrade disabled if insufficient fragments+nano; Manufacture disabled if 0 fragments |
| **New Blueprint Highlighted** | Screen opened from battle result with new fragments | Newly obtained blueprints have "New!" badge; Detail Panel pre-populated with first new blueprint | Same as Blueprint Selected but with badge until player navigates away | Badge persists until player manually navigates off that slot once |
| **Filter Active** | Player applies type/rarity filters or search | Blueprint Grid shows only matching blueprints; filter chips show active state | Detail Panel clears if previously selected blueprint is filtered out | Show "No blueprints match your filters" if grid is empty |
| **Star Upgrade Pending** | Player clicks "Upgrade" button | Confirmation dialog overlays the screen with upgrade cost and preview | All background interactions suspended until dialog resolves | Modal confirmation — cannot navigate grid until dialog resolved |
| **Manufacture Pending** | Player clicks "Manufacture" button | Confirmation dialog overlays with card preview and cost | All background interactions suspended until dialog resolves | Shows 1 fragment will be consumed |
| **Max Star Reached** | Selected blueprint is at 9★ | Star Progress Bar shows "MAX" with glow effect; Upgrade button replaced by "Max Star" label (disabled) | Upgrade action disabled; surplus fragments convert to nano (shown in notification) | Nano conversion notification appears when surplus fragments exist |
| **Error — insufficient resources** | Player clicks Upgrade/Manufacture but lacks fragments or nano | Error dialog overlays with "Insufficient Resources" message + required vs. current amounts | Only "OK" button available; action cancelled | Same error dialog for both Upgrade and Manufacture (context-aware text) |
| **Grid View** | Player selects Grid view toggle | Blueprints displayed as 5×4 icon grid with star badges | Navigation uses 2D arrow keys (up/down/left/right) | Default view |
| **List View** | Player selects List view toggle | Blueprints displayed as vertical list with larger preview images | Navigation uses 1D arrow keys (up/down only) | Better for text-heavy browsing or accessibility |

---

## 7. Interaction Map

### 7.1 Navigation Inputs

| Input | Platform | Action | Visual Response | Audio Cue | Notes |
|-------|----------|--------|-----------------|-----------|-------|
| **Arrow keys / D-Pad** | All | Move focus within blueprint grid | Focus ring moves to adjacent blueprint slot | Soft navigation tick (short, low-pitch) | Grid view: 2D navigation; List view: 1D navigation |
| **Tab / R1** | KB / Gamepad | Move focus to next zone (Grid → Detail → Action Bar → Filters) | Focus ring jumps to first element in next zone | Distinct zone-change tone (two-note chime) | Shift+Tab / L1 goes backward; cycles through zones |
| **PageUp/Down / LT/RT** | KB / Gamepad | Jump one page in blueprint grid (20 slots per page) | Grid scrolls smoothly; focus moves to same relative position on next page | Page-turn sound (paper rustle) | Faster than repeated arrow keys for large collections |
| **Home/End** | KB | Jump to first/last blueprint in grid | Grid scrolls to top/bottom; focus on first/last slot | Longer navigation tone | Useful for quickly reaching extremes |
| **Mouse hover** | PC | Show hover state on interactive elements | Blueprint slot highlights; detail preview tooltip appears after 500ms | None (hover is not an action) | Hover does NOT move keyboard focus |
| **Mouse click** | PC | Select and focus the clicked blueprint slot | Pressed state flash (80ms), then selected/focused | Soft select tone (short, mid-pitch) | Left-click only; right-click opens context menu (if implemented) |
| **Mouse scroll wheel** | PC | Scroll blueprint grid vertically | Grid scrolls smoothly (3 rows per scroll wheel tick) | None | Follows system scroll speed setting |
| **Ctrl+F** | KB | Focus moves to Search input | Search box expands (if collapsed) and receives focus | Search focus tone (ascending chime) | Global shortcut for search |

### 7.2 Action Inputs

| Input | Platform | Context (What must be focused) | Action | Response | Animation | Audio Cue | Notes |
|-------|----------|-------------------------------|--------|----------|-----------|-----------|-------|
| **Enter / A button / Left click** | All | Blueprint slot focused | Select blueprint → populate Detail Panel | Detail panel slides in (or updates in place), selected slot gains ★★★ badge | Panel fade/slide in, 150ms, easing: out-quart | Soft select tone | If blueprint already selected: no-op |
| **Enter / A button** | All | Upgrade button focused | Open star upgrade confirmation dialog | Dialog scales up from 95% with backdrop dim | Dialog appear, 200ms, easing: out-back | Dialog open tone (confirming) | Disabled if insufficient resources |
| **Enter / A button** | All | Manufacture button focused | Open manufacture confirmation dialog | Dialog scales up with card preview | Dialog appear, 200ms | Dialog open tone | Disabled if 0 fragments |
| **Esc / B button / Back** | All | Any, screen level | Close screen and return to previous state | Screen exit transition (slide out to right) | Slide out, 200ms, easing: in-cubic | Back/close tone (descending) | All changes auto-saved, no "discard" concept |
| **Space / X button** | KB / Gamepad | Blueprint slot focused | Quick-toggle between Grid/List view | View animates transition (grid → list or list → grid) | Cross-fade, 180ms, easing: in-out-sine | View switch sound (soft whoosh) | Convenience shortcut; does not change selection |
| **F1** | KB | Any | Toggle help/legend overlay | Help panel slides in from right | Slide in, 250ms, easing: out-quart | Help open tone | Can be dismissed with F1 or Esc |
| **1-4 number keys** | KB | Any | Quick-set rarity filters (1=Common, 2=Uncommon, etc.) | Filter chips toggle, grid updates to show/hide matching blueprints | Fade update, 120ms | Filter toggle click | Convenience shortcut for power users |
| **Ctrl+R** | KB | Any | Cycle sort order (Star → Fragments → Name → Rarity) | Grid re-sorts with shuffle animation | Shuffle transition, 200ms | Sort swoosh | Skip if already on last sort |
| **Delete / Y button** | KB / Gamepad | Blueprint slot focused | Add/remove from Favorites (if implemented) | Heart icon toggles on slot | Heart pulse, 150ms | Favorite on/off tone | Non-critical action, can be post-MVP |

### 7.3 State-Specific Behaviors

| State | Input Restriction | Reason |
|-------|------------------|--------|
| **Loading** | All blueprint and action inputs disabled; only Close/Back active | No data to act on; prevent race conditions |
| **Confirmation dialog open** | Only Confirm and Cancel inputs active; Esc closes dialog | Modal — background is locked |
| **Error dialog open** | Only "OK" input active | Modal — player must acknowledge error |
| **Empty grid (no blueprints)** | Grid navigation disabled; focus skips to Filter Bar or Search | No items to navigate |
| **Max star reached** | Upgrade input disabled; focus skips to Manufacture or other actions | No valid upgrade action available |

---

## 8. Data Requirements

| Data Element | Source System | Update Frequency | Who Owns It | Format | Null / Missing Handling |
|--------------|--------------|-----------------|-------------|--------|------------------------|
| **Blueprint list (all blueprints)** | BlueprintManager | On screen open; on BlueprintChanged event | BlueprintManager | Array of BlueprintData structs: id, name, icon_path, type, rarity, star_level, total_fragments, unlocked, is_new | Empty array → show Empty State. Never null. |
| **Selected blueprint details** | BlueprintManager | On blueprint selection change | BlueprintManager | BlueprintData struct (same as above) + affixes array + stat_bonuses dict | If no blueprint selected, Detail Panel shows placeholder "Select a blueprint to view details" |
| **Fragment counts** | BlueprintManager | On screen open; on FragmentAdded event | BlueprintManager | Dict mapping blueprint_id → fragment_count | 0 fragments is valid state (cannot manufacture but can view) |
| **Star upgrade costs** | BlueprintManager | On blueprint selection change | BlueprintManager | Dict: {fragments_cost: int, nano_cost: int, target_star: int} | Costs calculated dynamically; never null |
| **Affix data** | AffixManager | On blueprint selection change; on star upgrade | AffixManager | Array of AffixData: star_level, affix_name, affix_description, value | Empty array for 1★ blueprints (no affixes yet) |
| **Player nano materials** | BasicResourceManager | On screen open; on NanoChanged event | BasicResourceManager | Int — current nano materials | 0 nano is valid (upgrade disabled) |
| **Newly obtained blueprints** | BlueprintManager | On screen open (from battle result) | BlueprintManager | Array of blueprint_ids flagged as new | Empty array → no "New!" badges shown |

**Rule**: This screen must never write directly to any system listed above. All player actions fire events (see Section 9). Systems update their own data and notify the UI via events.

---

## 9. Events Fired

| Player Action | Event Fired | Payload | Receiver System | Notes |
|---------------|-------------|---------|-----------------|-------|
| **Player opens Blueprint screen** | BlueprintScreenOpened | {source: string (battle_result/base)} | Analytics System | Analytics only; no game state change |
| **Player selects a blueprint** | BlueprintSelected | {blueprint_id: string} | Analytics System | Analytics only; selection is local UI state |
| **Player confirms star upgrade** | BlueprintStarUpgradeRequested | {blueprint_id: string, target_star: int} | BlueprintManager | BlueprintManager validates and processes upgrade; fires BlueprintChanged event on success |
| **Player confirms manufacture** | BlueprintCardManufactureRequested | {blueprint_id: string} | BlueprintManager | BlueprintManager validates fragments, consumes 1 fragment, creates card; fires InventoryChanged event |
| **Player changes filters** | BlueprintFilterChanged | {type_filter: string, rarity_filters: array, sort_order: string} | Analytics System | Analytics only; filters are local UI state |
| **Player toggles grid/list view** | BlueprintViewChanged | {view_mode: string (grid/list)} | Analytics System | Analytics only; view preference saved to user settings |
| **Player closes screen** | BlueprintScreenClosed | {session_duration_ms: int, blueprints_viewed: int} | Analytics System | Analytics only; no game state change |
| **Player clicks help** | BlueprintHelpOpened | {} | Analytics System | Analytics only; help is local UI overlay |

---

## 10. Transition & Animation

| Transition | Trigger | Direction / Type | Duration (ms) | Easing | Interruptible? | Skipped by Reduced Motion? |
|------------|---------|-----------------|--------------|--------|----------------|---------------------------|
| **Screen enter** | Screen pushed onto stack | Fade in + slight scale up (95% → 100%) | 200 | Ease out cubic | No — must complete before interaction enabled | Yes — instant appear at 100% |
| **Screen exit** | Player presses Back/B/Esc | Fade out + slight scale down (100% → 95%) | 150 | Ease in cubic | No | Yes — instant disappear |
| **Blueprint slot focus** | Player navigates to slot | Focus ring fades in + slot scales up (1.0 → 1.05) | 80 | Ease out | Yes — if player navigates quickly, previous animation cancels | No — focus indicator is essential feedback |
| **Detail panel populate** | Player selects blueprint | Panel content cross-fades (old content fades out, new fades in) | 120 | Linear | Yes | Yes — instant content swap |
| **Star progress bar fill** | Player selects blueprint OR fragments added | Bar fills from 0 to current percentage | 300 | Ease out quart | Yes | Yes — instant jump to value |
| **Star upgrade celebration** | Player confirms upgrade AND BlueprintManager confirms success | Star burst animation + panel flash + new affix cards reveal | 600 | Ease out back | No — this is a celebration moment, should play fully | No — reduced motion only speeds up to 300ms, does not skip |
| **Manufacture confirmation** | Player clicks Manufacture | Dialog scales up (90% → 100%) + backdrop dims | 150 | Ease out | No | Yes — instant appear |
| **New badge appear** | Screen opens with newly obtained blueprint | Badge pops from 0% to 120% to 100% scale | 200 | Ease out back | No | No — badge is critical information |
| **Filter change** | Player toggles filter | Grid fades out filtered items, fades in matching items | 180 | Ease in-out sine | Yes | Yes — instant grid update |
| **Grid ↔ List view transition** | Player toggles view toggle | Grid morphs into list (or list into grid) with cross-fade | 250 | Ease in-out sine | Yes | Yes — instant switch |
| **Error dialog appear** | Action fails due to insufficient resources | Dialog shakes horizontally (error gesture) + fades in | 200 | Ease out bounce | No | Yes — instant appear (no shake) |

**Animation priority**:
1. **Essential feedback** (focus, selection) — never skipped, even with reduced motion
2. **Celebration moments** (star upgrades) — sped up but not skipped with reduced motion
3. **Decorative transitions** (screen enter/exit, filter changes) — fully skipped with reduced motion

---

## 11. Input Method Completeness Checklist

**Keyboard**
- [x] All interactive elements are reachable using Tab and arrow keys alone
- [x] Tab order follows visual reading order (Header → Filters → Grid → Detail → Action Bar)
- [x] Every action achievable by mouse is also achievable by keyboard
- [x] Focus is visible at all times (focus ring on all interactive elements)
- [x] Focus does not escape the screen while it is open (Esc closes, does not quit game)
- [x] Esc key closes screen (B key also closes as toggle)

**Gamepad**
- [ ] All interactive elements reachable with D-Pad and left stick (PLANNED — not implemented for MVP)
- [ ] Face button mapping documented and consistent with platform conventions (PLANNED)
- [ ] No action requires analog stick precision that cannot be replicated with D-Pad (PLANNED)
- [ ] Trigger and bumper shortcuts documented if used (PLANNED — LT/RT for page navigation)
- [ ] Controller disconnection while screen is open is handled gracefully (PLANNED)

**Mouse**
- [x] Hover states defined for all interactive elements
- [x] Clickable hit targets are at minimum 32x32px (blueprint slots are 64x64px)
- [x] Right-click behavior defined (no-op for MVP; future: context menu)
- [x] Scroll wheel behavior defined in scrollable zones (Grid, Detail Panel)

**Touch**
- [ ] NOT SUPPORTED — Phase War is PC-only for MVP
- [ ] If touch support is added post-MVP, all touch targets must be minimum 44x44px

---

## 12. Screen-Level Accessibility Requirements

**Accessibility Tier**: Comprehensive (WCAG 2.1 AAA equivalent)

**Text contrast requirements for this screen**:

| Text Element | Background Context | Required Ratio | Current Ratio | Pass? |
|--------------|-------------------|---------------|---------------|-------|
| **Blueprint name in Detail Panel** | Dark panel background (~#141A22) | 4.5:1 (WCAG AA normal) | TBD — verify in implementation | [ ] |
| **Star level badge (★★★)** | Blueprint slot background (varies by rarity) | 4.5:1 | TBD | [ ] |
| **Fragment counter text** | Detail panel background | 4.5:1 | TBD | [ ] |
| **Progress bar label** | Progress bar background (dark track) | 4.5:1 | TBD | [ ] |
| **Affix card text** | Affix card background (semi-transparent) | 4.5:1 | TBD | [ ] |
| **Action button labels** | Button color (varies by action) | 4.5:1 | TBD | [ ] |
| **Filter button labels** | Filter bar background | 4.5:1 | TBD | [ ] |

**Colorblind-unsafe elements and mitigations**:

| Element | Colorblind Risk | Mitigation |
|---------|----------------|------------|
| **Rarity color coding (grey/blue/purple/gold)** | Multiple types — rarity color is a common industry failure | Add rarity name text label below icon; use shape icons (◆ for common, ● for uncommon, etc.) as redundant indicator |
| **Star progress bar (blue fill)** | Blue-yellow colorblindness (Tritanopia) — rare | Use texture pattern on progress fill (diagonal stripes) + percentage text; color is supplemental |
| **Stat delta indicators (if showing +HP in green)** | Red-green colorblindness (Deuteranopia) — most common | Add arrow icons (↑ / ↓) and +/- prefix; use blue/orange instead of green/red if possible |
| **Affix type icons (if color-coded by type)** | Any color distinction | Use distinct icon shapes + text labels; avoid color as sole indicator |

**Focus order** (Tab key sequence, numbered):

1. Back button (Header)
2. Search input (Header)
3. Grid/List toggle (Header)
4. Help button (Header)
5. Type filter: All
6. Type filter: Platform
7. Type filter: Weapon
8. Type filter: Law
9. Rarity filter: Common
10. Rarity filter: Uncommon
11. Rarity filter: Rare
12. Rarity filter: Epic
13. Rarity filter: Legendary
14. Rarity filter: Mythic
15. Sort dropdown
16. Blueprint Slot [0,0] (grid traverses left-to-right, top-to-bottom)
17. Blueprint Slot [0,1] ... (continues through all visible slots)
18. Last blueprint slot on current page
19. Page indicator / Page navigation buttons (if grid has multiple pages)
20. Upgrade button (Action Bar) — if enabled
21. Manufacture button (Action Bar) — if enabled
22. Add to Favorites button (Action Bar) — if implemented
23. Close button (Action Bar)
→ Cycles back to Back button

**Focus does NOT enter the Detail Panel** — it is a display panel driven by blueprint slot focus, not independently navigable.

**Screen reader announcements for key state changes**:

| State Change | Announcement Text | Announcement Timing |
|--------------|------------------|---------------------|
| **Screen opens** | "Blueprint Collection screen. [N] blueprints unlocked. [M] new blueprints from recent battle." | On screen focus settle |
| **Player focuses a blueprint slot** | "[Blueprint name]. [Type]. [Rarity]. Star level [X] out of 9. [Y] total fragments. [Z] fragments to next star. [Current / Not current] selection." | On focus arrival |
| **Player upgrades a blueprint** | "[Blueprint name] upgraded to star level [X]. New affix: [affix name]. [Remaining fragments]." | After BlueprintChanged event confirmed |
| **Player manufactures a card** | "[Card name] manufactured from [blueprint name]. [Remaining fragments]. Card added to inventory." | After InventoryChanged event confirmed |
| **Player changes filters** | "[N] blueprints match current filters." | On filter change, after grid updates |
| **Max star reached** | "[Blueprint name] is at maximum star level 9. Surplus fragments will convert to nano materials." | On blueprint focus (if max star) |
| **Insufficient resources error** | "Cannot upgrade. Need [X] fragments and [Y] nano. Current: [A] fragments, [B] nano." | On error dialog appear |
| **Empty state shown** | "No blueprints match current filters. Try adjusting filters or search terms." | When empty state renders |

**Cognitive load assessment**:

The Blueprint Collection screen requires tracking **4 concurrent information streams**:
1. Blueprint grid position (which blueprint am I looking at?)
2. Detail panel data (star level, fragments, stats)
3. Upgrade/manufacture costs (can I afford this?)
4. Filter state (which blueprints are shown?)

This is **within the standard 7±2 limit** and is lower than many inventory screens. Mitigations:
- Detail panel auto-updates on navigation (no manual retrieve needed)
- Upgrade/manufacture buttons are disabled when unaffordable (clear visual feedback)
- Star progress bar provides visual anchor (players can "feel" progress without counting)
- Filters are optional; default view shows all blueprints (no forced decision)

---

## 13. Localization Considerations

**General rules for this screen**:
- All text elements must tolerate a minimum of 40% expansion from English baseline
- CJK languages (Chinese, Japanese, Korean): text may be 20-30% shorter — verify layouts do not look broken with less text
- RTL languages (Arabic, Hebrew): mirrored layout required — document which elements mirror and which do not
- Do not use text in images — all text must be from localization strings

| Text Element | English Baseline Length | Max Characters | Expansion Budget | RTL Behavior | Overflow Behavior | Risk |
|--------------|------------------------|----------------|-----------------|--------------|-------------------|------|
| **Screen title "BLUEPRINT COLLECTION"** | 21 chars | 30 chars | 43% | Center-align (acceptable) | Truncate with ellipsis — title is not critical content | Low |
| **Blueprint name** | ~15 chars avg, max ~35 "Energy Cannon Platform MK2" | 50 chars | 43% | Right-align in RTL layouts | Truncate with tooltip showing full name on hover/focus | Medium — long fantasy names are common |
| **Affix description** | ~40-60 chars avg, max ~80 "Increases defense by 20% when below 50% HP" | 120 chars | 50% | Right-align, wrap normally | Scroll within Affix Card; no truncation | Low — card is scrollable |
| **Action button "Upgrade to ★★★★"** | ~15 chars | 25 chars | 67% | Button layout mirrors; text right-aligns | Shrink font to 90% minimum, then truncate | Medium — German "Aufwerten auf" is longer |
| **Filter label "Platform"** | 8 chars | 14 chars | 75% | Mirror tab position | Abbreviate: "Plat." — define per language | Medium — long filter labels are common |
| **Fragment counter "120 / 150 fragments"** | 20 chars | 30 chars | 50% | Keep numbers LTR even in RTL (standard for numerals) | No overflow — fixed format | Low |
| **Star progress label "30 to next star"** | 18 chars | 28 chars | 56% | Right-align | Shrink font to 85% minimum | Low |

**Number formatting**:
- Fragment counts use locale-specific thousands separators (1,000 in English, 1.000 in German, 1 000 in French)
- Nano materials use same formatting
- Star levels (★) are universal symbols — not translated

**Iconography**:
- Star icons (★) are universal — not culturally specific
- Rarity icons (shapes) are colorblind-safe and culturally neutral
- Affix icons should be abstract, not relying on text or cultural metaphors

---

## 14. Acceptance Criteria

**Performance**
- [ ] Screen opens (first frame visible) within 150ms of trigger on minimum-spec hardware
- [ ] Screen is fully interactive (all data loaded) within 300ms of trigger on minimum-spec hardware
- [ ] Navigation between blueprints produces no perceptible frame drop (maintain 60 FPS ±3 FPS)
- [ ] Star upgrade celebration animation does not cause frame drop below 50 FPS

**Layout & Rendering**
- [ ] Screen displays correctly (no overlap, no cutoff, no overflow) at 1920×1080 (primary resolution)
- [ ] Screen displays correctly at 1280×720 (minimum supported resolution)
- [ ] Screen displays correctly at 2560×1440 and 3840×2160 (high-resolution support)
- [ ] Screen displays correctly at 16:9 aspect ratio
- [ ] Blueprint grid scrolls smoothly without frame drops when all slots are populated (100+ blueprints)
- [ ] Detail panel scrolls smoothly for blueprints with 9+ affixes (long content)
- [ ] All states (Loading, Empty, Populated, Selected, New Highlighted, Filtered, Max Star, Error) render correctly

**Input**
- [ ] All interactive elements reachable by keyboard using Tab and arrow keys only
- [ ] All interactive elements reachable by mouse without keyboard
- [ ] Focus is visible at all times on keyboard navigation
- [ ] Focus does not escape the screen while it is open
- [ ] Esc key closes screen from any state
- [ ] B key toggles screen open/closed from base state
- [ ] Ctrl+F focuses search input from any state
- [ ] Arrow keys navigate 2D grid correctly (up/down/left/right wrapping)

**Events & Data**
- [ ] BlueprintScreenOpened event fires with correct payload on every screen open
- [ ] BlueprintStarUpgradeRequested event fires with correct payload on upgrade confirmation
- [ ] BlueprintCardManufactureRequested event fires with correct payload on manufacture confirmation
- [ ] Screen does not write directly to BlueprintManager or BasicResourceManager (verify: no direct state mutation calls)
- [ ] Screen handles BlueprintChanged events fired by other systems while it is open without crashing
- [ ] Blueprint state persists correctly after screen is closed and reopened
- [ ] Fragment counts update correctly when fragments are added via battle drops

**Accessibility**
- [ ] All text passes minimum contrast ratios specified in Section 12
- [ ] Rarity color coding has non-color indicators (text labels + shape icons)
- [ ] Star progress bar has percentage text + patterned fill (not just color)
- [ ] Screen reader announces blueprint name, star level, and fragment count on focus (verify with NVDA/JAWS)
- [ ] Reduced motion setting results in instant transitions for all non-essential animations
- [ ] Focus order follows logical visual sequence (verified with Tab key)
- [ ] All actions have keyboard equivalents (no mouse-only actions)

**Localization**
- [ ] No text element overflows its container in English
- [ ] No text element overflows its container in German (longest translation target)
- [ ] Blueprint names truncate gracefully with tooltip for full text
- [ ] Affix descriptions scroll within cards without overflow
- [ ] All text elements are driven by localization strings — no hardcoded display text

**Game Feel**
- [ ] Star upgrade celebration feels satisfying (subjective QA assessment)
- [ ] "New!" badges draw attention without being intrusive
- [ ] Progress bar provides clear visual feedback for fragment accumulation
- [ ] Manufacture action feels impactful but not momentous (appropriate for common action)
- [ ] Error messages are clear and constructive (explain what's needed)

**Edge Cases**
- [ ] Empty state (no blueprints) shows helpful message
- [ ] Filtered to zero results shows "no matching blueprints" message
- [ ] Max star (9★) shows correct UI state (no upgrade button, nano conversion notification)
- [ ] Manufacturing with 1 fragment succeeds and leaves 0 fragments (blueprint still unlocked)
- [ ] Insufficient resources (fragments or nano) shows clear error dialog
- [ ] First-time unlock shows tutorial tooltip (if tutorial system active)
- [ ] Large collection (100+ blueprints) scrolls and performs smoothly

---

## 15. Open Questions

| Question | Owner | Deadline | Resolution |
|----------|-------|----------|-----------|
| **Should star upgrades be batchable?** (e.g., upgrade multiple stars at once with cumulative cost) | Systems Designer | Sprint 5, Day 3 | Pending — current design is one-star-at-a-time for celebration moments |
| **What is the nano cost scaling for star upgrades?** (current GDD mentions base_nano_cost but no specific values) | Balance Designer | Sprint 5, Day 3 | Pending — needs tuning based on economy model |
| **Should there be a "favorites" system for quick access to frequently-used blueprints?** | UX Designer | Sprint 6, Day 1 | Pending — nice-to-have, can be post-MVP |
| **How should the system handle blueprint renaming?** (if players can customize names) | Systems Designer | Sprint 7, Day 1 | Pending — current design assumes no renaming |
| **Should the Detail Panel show historical data?** (e.g., "last upgraded 3 days ago") | Analytics Designer | Sprint 8, Day 1 | Pending — analytics feature, low priority |

---

## Appendix A: User Flow Diagrams

### Flow A: First-Time Blueprint Unlock

```
1. Player completes battle
2. Battle Result screen shows: "New Blueprint Obtained!"
3. Player clicks "View Blueprints"
4. Blueprint Collection opens with new blueprint pre-selected
5. "New!" badge pulses on blueprint slot
6. Detail Panel shows: "★★ TITAN MECHA MK2 (New!)"
7. Player sees 1★ stats and affixes
8. Progress bar shows: "1 / 20 fragments to next star"
9. Tutorial tooltip: "Collect more fragments to upgrade star level!"
10. Player presses Esc to return to base
```

### Flow B: Star Upgrade Journey

```
1. Player opens Blueprint Collection (presses B)
2. Grid shows all blueprints, sorted by star level
3. Player navigates to "★★★ TITAN MECHA MK2"
4. Detail Panel shows: "★★★ 120 / 150 fragments (30 to next star)"
5. Player realizes they have enough for ★★★★ upgrade
6. Player clicks "Upgrade to ★★★★" button
7. Confirmation dialog: "Upgrade to ★★★★? Cost: 30 fragments + 150 nano"
8. Player clicks "Confirm"
9. Star upgrade celebration animation plays (500ms)
10. Blueprint updates to ★★★★, new affix revealed
11. Progress bar updates: "0 / 150 fragments to next star"
12. Player feels satisfaction at milestone achieved
```

### Flow C: Manufacturing Card

```
1. Player opens Blueprint Collection
2. Player navigates to "★★★★ TITAN MECHA MK2"
3. Detail Panel shows: "50 fragments available"
4. Player clicks "Manufacture Card" button
5. Confirmation dialog: "Manufacture TITAN MECHA MK2 card? Cost: 1 fragment"
6. Preview shows: "★★★★ TITAN MECHA MK2 with 4 affixes"
7. Player clicks "Confirm"
8. Manufacturing animation plays (card materializes, 300ms)
9. Fragment count updates: "49 fragments remaining"
10. Notification: "Card added to inventory!"
11. Player can now use card in deck building
```

---

## Appendix B: Mockup References

**Wireframe tools recommended**:
- Figma (for high-fidelity visual design)
- Adobe XD (for prototyping interactions)
- Pencil + paper (for initial sketching)

**Key visual elements to prototype**:
1. Blueprint slot layout (grid vs list)
2. Star progress bar visualization
3. Affix card design (icon + text + star indicator)
4. New badge animation (pulse effect)
5. Star upgrade celebration (particle effects)

**Reference games for visual inspiration**:
- **Slay the Spire**: Relic collection screen (grid layout, rarity colors)
- **Monster Hunter**: Weapon upgrade tree (progress visualization, star milestones)
- **Slay the Spire**: Card library (card preview with stat breakdown)
- **Hades**: Keepsake collection (tooltip-driven details, clean grid)

---

## Appendix C: Implementation Notes for UI Programmers

**Component architecture**:
- BlueprintSlot: Custom Control node extending Button
- DetailPanel: VBoxContainer with dynamic child nodes
- StarProgressBar: Custom ProgressBar with textured fill
- AffixCard: HBoxContainer with icon + label + description
- FilterBar: HBoxContainer with radio buttons and checkboxes
- ConfirmationDialog: Godot AcceptDialog with custom content

**Data binding**:
- Use BlueprintManager's blueprint_changed signal to refresh UI
- Use BasicResourceManager's resource_changed signal to update nano display
- Do NOT poll — use event-driven architecture

**Performance optimization**:
- Blueprint grid should use virtual scrolling if >100 blueprints
- Affix cards should be pooled/recycled (not created/destroyed)
- Lazy-load blueprint icons (only load visible slots)

**State management**:
- Selected blueprint is local UI state (not persisted)
- Filter/sort preferences are saved to user settings
- Grid/list view toggle is saved to user settings

**Testing recommendations**:
- Unit tests: BlueprintSlot focus management, Detail Panel data binding
- Integration tests: Event firing on upgrade/manufacture, screen open/close
- Playtest: Star upgrade feel, navigation flow, error message clarity

---

**Document Status**: Draft (2026-04-08) — Ready for review and approval before implementation.

**Next Steps**:
1. Art Director to create visual mockups based on wireframes
2. UI Programmer to review data requirements and event contracts
3. QA to review acceptance criteria and create test plan
4. Accessibility audit to verify WCAG 2.1 AAA compliance

**Document Maintainer**: UX Designer
**Reviewers**: Game Designer, Art Director, UI Programmer, QA Lead
**Next Review Date**: 2026-05-08 (or before implementation sprint begins)
