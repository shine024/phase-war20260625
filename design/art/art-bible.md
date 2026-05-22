# Art Bible — Phase War (构装纪元)

> **Status**: Draft
> **Created**: 2026-04-24
> **Authority**: Single source of truth for all visual decisions

---

## 1. Visual Identity Statement

Phase War is a military sci-fi auto-battler spanning five eras of warfare (WWI to Near Future). Its visual language merges **historical military authenticity** with **futuristic phase technology**, using a grounded color palette accented by energy-driven glows and era-specific material treatments. Every visual element must communicate two things simultaneously: *when* in history this unit belongs, and *what* faction or card type it represents. The UI is functional and information-dense, befitting a commander's tactical interface, with rarity and card type serving as the primary color signals that guide the player's eye across every screen.

---

## 2. Art Style Reference

### 2.1 Sprite Style

- **Enemy sprites**: Pixel-art sprite sheets with directional facing, housed in `assets/enemies/`.
  Naming pattern: `[tier]_[era_short]_[unit_name]` (e.g., `enemy_ww1_infantry_basic`, `boss_cold_mig`).
  Tier prefixes: `enemy_` (standard), `elite_` (elite variants), `boss_` (boss units).
- **Friendly unit sprites**: Located in `assets/unit_sprites/`, following similar naming conventions.
- **Backgrounds**: 112 level backgrounds in `assets/backgrounds/` as PNG. Era-identified by filename.
- **Style summary**: Clean pixel art, readable silhouettes at small scale, military color palette per era.
  Units must be distinguishable at 48-64px viewport scale.

### 2.2 Era Visual Differentiation

| Era | Short Code | Visual Cues |
|-----|-----------|-------------|
| WWI (一战) | `ww1` | Earth tones, browns/greens, trench-worn textures |
| WWII (二战) | `ww2` | Olive drab, dark steel, weathered equipment |
| Cold War (冷战) | `cold` | Industrial grey, dark green, Soviet/US hardware |
| Modern (现代) | `modern` | Digital camo, matte black, HUD-style accents |
| Near Future (近未来) | `future` | Neon edge glow, sleek alloys, phase-tech shimmer |

---

## 3. Color Authority Table

**Single authoritative source: `resources/game_constants.gd`**

All other files must reference `GameConstants.get_rarity_color()` or `GameConstants.get_rarity_name()` -- never define their own color values.

### 3.1 Rarity Colors (Canonical)

| Rarity Key | Display Name | RGBA (Godot) | Hex | Usage |
|------------|-------------|--------------|-----|-------|
| `common` | 普通 | (0.75, 0.75, 0.75, 1.0) | #BFBFBF | Card borders, font color, tooltip headers |
| `uncommon` | 优秀 | (0.40, 0.90, 0.50, 1.0) | #66E680 | Green accent for uncommon tier |
| `rare` | 稀有 | (0.40, 0.65, 1.00, 1.0) | #66A6FF | Card borders, font color, particle trails |
| `epic` | 史诗 | (0.75, 0.40, 1.00, 1.0) | #BF66FF | Card borders, font color, glow effects |
| `legendary` | 传说 | (1.00, 0.70, 0.30, 1.0) | #FFB34D | Card borders, font color, shimmer effects |
| `mythic` | 神话 | (0.75, 0.35, 1.00, 1.0) | #BF59FF | Tower relics only (tower_relics.gd) |

> **Rule**: No file may hardcode rarity hex values. Always call `GameConstants.get_rarity_color()`.

### 3.2 Card Type Colors (Canonical)

Source: `scenes/ui/card_affix_tooltip.gd` `_get_card_type_color()`.

| CardType Enum | Name | RGBA | Hex | Usage |
|---------------|------|------|-----|-------|
| `PLATFORM` | 平台卡 | (0.10, 0.50, 0.90) | #1A80E6 | Card type icon, header stripe |
| `WEAPON` | 武器卡 | (0.85, 0.45, 0.10) | #D9731A | Card type icon, header stripe |
| `ENERGY` | 能量卡 | (0.15, 0.75, 0.35) | #26BF59 | Card type icon, header stripe |
| `LAW` | 法则卡 | **NOT DEFINED** | -- | See issue #3 below |
| `COMBINED` | 合成卡 | (0.55, 0.25, 0.90) | #8C40E6 | Card type icon, header stripe |

### 3.3 Slot Colors (Canonical)

Source: `scripts/ui_theme_manager.gd` `colors` dictionary.

| Key | RGBA | Hex | UI Element |
|-----|------|-----|------------|
| `slot_green` | (0.30, 0.90, 0.50) | #4DE680 | Phase instrument slots (platform+weapon) |
| `slot_red` | (0.90, 0.30, 0.30) | #E64D4D | Active law slots |
| `slot_blue` | (0.30, 0.60, 1.00) | #4D99FF | Passive law slots |
| `slot_yellow` | (0.95, 0.85, 0.20) | #F2D933 | Energy slots |

### 3.4 Theme Primary Color

| Source | RGBA | Hex |
|--------|------|-----|
| `ui_beautifier.gd` default theme | (0.20, 0.60, 1.00) | #3399FF |
| `interaction-patterns.md` spec | -- | #66D9FF |

> **Resolution needed**: Pick one primary blue as canonical. Currently these differ.

### 3.5 UI System Colors (Canonical)

Source: `scripts/ui_theme_manager.gd`.

| Key | RGBA | Hex |
|-----|------|-----|
| `error` | (0.95, 0.30, 0.30) | #F24D4D |
| `info` | (0.60, 0.80, 1.00) | #99CCFF |
| `border_normal` | (0.30, 0.35, 0.45) | #4D5A73 |
| `border_active` | (0.40, 0.85, 1.00) | #66D9FF |
| `border_hover` | (0.50, 0.90, 1.00) | #80E6FF |
| `bg_dark` | (0.08, 0.10, 0.15) | #141A26 |

---

## 4. Card Visual Specifications

### 4.1 Card Layout Structure

```
+--[ Rarity Border (2px, rarity color) ]--+
|  [Type Icon] [Card Name]      [Rarity]  |  <- Header row
|  ────────────────────────────────       |  <- Type color stripe (1px)
|                                          |
|         [ Unit Sprite / Icon ]           |  <- Central visual
|                                          |
|  ────────────────────────────────       |
|  Stat: Value    Stat: Value             |  <- Stats row
|  [Affix tags / bonuses]                 |  <- Modifiers
+------------------------------------------+
```

### 4.2 Rarity Visual Treatment

| Rarity | Border | Background Tint | Special Effect |
|--------|--------|----------------|----------------|
| Common | #BFBFBF solid | None (neutral dark) | None |
| Rare | #4D99FF solid | Faint blue wash | None |
| Epic | #B34DFF solid | Faint purple wash | Subtle shimmer on hover |
| Legendary | #FFB31A solid | Faint gold wash | Animated glow pulse |

### 4.3 Card Type Identification

- Color stripe at top of card body (1px line in card type color)
- Small type icon in top-left corner using card type color
- Tooltip headers use card type color for the type label text

---

## 5. Asset Naming Convention

### 5.1 General Format

```
[category]_[name]_[variant]_[size].[ext]
```

### 5.2 Category Prefixes

| Prefix | Directory | Description |
|--------|-----------|-------------|
| `enemy_` | `assets/enemies/` | Standard enemy unit sprite sheets |
| `elite_` | `assets/enemies/` | Elite enemy variants |
| `boss_` | `assets/enemies/` | Boss enemy sprite sheets |
| `unit_` | `assets/unit_sprites/` | Friendly unit sprites |
| `bg_` | `assets/backgrounds/` | Level backgrounds |
| `card_` | (planned: `assets/cards/`) | Card artwork |
| `icon_` | (planned: `assets/icons/`) | UI icons |
| `ui_` | (planned: `assets/ui/`) | UI elements and frames |
| `vfx_` | (planned: `assets/vfx/`) | Visual effects |
| `sfx_` | `assets/sfx/` | Sound effects |
| `mus_` | `assets/music/` | Music tracks |

### 5.3 Enemy Naming Pattern (Current Convention)

```
[tier]_[era_code]_[unit_descriptor]
```

**Examples**（战场立绘为单张卡图，见 `EnemyArchetypes.resolve_card_icon_texture_path`）:
- `res://assets/card_icons/enemy_ww1_infantry_basic.png`（或 `work_全卡面加工/` 下同名）
- `elite_modern_abrams.png`
- `boss_cold_mig.png`
- `enemy_future_drone.png`

**Era codes**: `ww1`, `ww2`, `cold`, `modern`, `future`

---

## 6. Typography

### 6.1 Font Stack

| Context | Primary Font | Fallback |
|---------|-------------|----------|
| Chinese text | Microsoft YaHei | PingFang SC |
| English text | Segoe UI | Roboto |
| Monospace (numbers, codes) | Consolas | Courier New |

### 6.2 Size Scale (px at 1080p)

| Role | Size | Usage |
|------|------|-------|
| Title | 24-28 | Screen titles, modal headers |
| Heading | 18-20 | Section headers, card names |
| Subheading | 14-16 | Subsection labels, tab headers |
| Body | 12-13 | Descriptions, stat values |
| Caption | 10-11 | Tooltips, small labels, footnotes |

---

## 7. Animation Timing

### 7.1 Standard Durations

| Speed | Duration | Usage |
|-------|----------|-------|
| Instant | 0-50ms | State changes, button press feedback |
| Fast | 100ms | Hover states, small transitions |
| Standard | 200ms | Panel open/close, fade-in |
| Medium | 300ms | Card deal animation, screen transition |
| Slow | 500ms | Dramatic reveals, boss entrance |
| Emphasis | 800-1000ms | Legendary card glow loop, damage numbers |

### 7.2 Easing

- **UI transitions**: Ease-out (fast start, decelerate)
- **Particle effects**: Linear or ease-in-out
- **Card entrance**: Overshoot ease (slight bounce)

---

## 8. Code-Design Inconsistency Fix List

> These are concrete issues discovered during art bible creation. Each requires a
> code change to align with the canonical color authority.

### Issue #1: `game_constants.gd` Missing `uncommon` Rarity Color

**Severity**: ~~HIGH~~ RESOLVED
**File**: `resources/game_constants.gd` line 185
**Problem**: `get_rarity_color()` has no `"uncommon"` case, but `get_rarity_name()` maps
`"uncommon"` to "优秀" (line 175). Any UI querying uncommon rarity gets white fallback.
**Fix**: Add `"uncommon"` case to `get_rarity_color()` with the value from `affix_resource.gd`:
`(0.40, 0.90, 0.50, 1.0)` (#66E680) -- green.

### Issue #2: `ui_theme_manager.gd` Defines Non-Existent `mythic` Rarity

**Severity**: MEDIUM
**File**: `scripts/ui_theme_manager.gd` line 218
**Problem**: Defines `"神话"` (#FF804D) as a rarity color, but `game_constants.gd` has no
`mythic` rarity key or name mapping. This is a ghost definition.
**Fix**: Either add `mythic` to `game_constants.gd` (rarity enum, name, color) or remove
the mythic case from `ui_theme_manager.gd`.

### Issue #3: Missing `LAW` Card Type Color

**Severity**: ~~MEDIUM~~ RESOLVED (2026-04-24)
**File**: `scenes/ui/card_affix_tooltip.gd` line 226
**Problem**: `_get_card_type_color()` has no case for `GC.CardType.LAW`. Law cards get the
grey fallback `(0.5, 0.5, 0.5)`. Law cards are a core mechanic and deserve a distinct color.
**Fix**: Add a LAW case. Suggested color: warm white-gold `(0.95, 0.90, 0.60)` to reflect
the "rules of engagement" / "authority" feel.

### Issue #4: Rarity Colors Diverge Across 4 Files

**Severity**: ~~HIGH~~ RESOLVED (2026-04-24)
**Files**: `game_constants.gd`, `affix_resource.gd`, `ui_theme_manager.gd`, `synthesis_panel.gd`, `tower_relics.gd`

| Rarity | game_constants | affix_resource | ui_theme_manager | synthesis_panel |
|--------|---------------|----------------|------------------|-----------------|
| common | #BFBFBF | #BFBFBF | #B3B3BF | (no match) |
| uncommon | MISSING | #66E680 | (no match) | #66E680 |
| rare | **#4D99FF** | **#66A6FF** | **#66B3FF** | **#66A6FF** |
| epic | **#B34DFF** | **#B366FF** | **#B34DFF** | (no match) |
| legendary | **#FFB31A** | **#FFB34D** | **#FFD966** | **#FF80E6** |

**Fix**: All files must call `GameConstants.get_rarity_color()`. Remove duplicate color
definitions from `affix_resource.gd`, `ui_theme_manager.gd`, and `synthesis_panel.gd`.

### Issue #5: `ui_theme_manager.gd` Uses Chinese Rarity Keys

**Severity**: ~~HIGH~~ RESOLVED (2026-04-24)
**File**: `scripts/ui_theme_manager.gd` line 212
**Problem**: Uses Chinese strings (`"普通"`, `"稀有"`, etc.) as match keys, while all other
systems (game_constants, affix_resource, card_resource) use English keys (`"common"`, `"rare"`).
This causes silent mismatches when systems exchange rarity data.
**Fix**: Switch to English keys matching `game_constants.gd`. Add a display-name mapping
function for any UI that needs Chinese labels.

### Issue #6: `synthesis_panel.gd` Legendary Color Is Pink, Not Gold

**Severity**: ~~MEDIUM~~ RESOLVED (2026-04-24)
**File**: `scenes/ui/synthesis_panel.gd` lines 121, 298
**Problem**: `legendary` mapped to `(1.0, 0.5, 0.9)` (#FF80E6) -- pink-purple instead of gold.
This is clearly a typo/error.
**Fix**: Replace with `GameConstants.get_rarity_color("legendary")` call.

### Issue #7: Primary Blue Inconsistency

**Severity**: LOW
**Files**: `scripts/ui_beautifier.gd` vs `design/ux/interaction-patterns.md`
**Problem**: `ui_beautifier.gd` default primary = (0.20, 0.60, 1.00) = #3399FF.
Design doc specifies #66D9FF.
**Fix**: Decide canonical primary blue. Document the decision here and update the non-authoritative source.

### Issue #8: No `assets/cards/`, `assets/ui/`, `assets/icons/` Directories

**Severity**: LOW (infrastructure)
**Problem**: Card artwork, UI frames, and icon assets have no dedicated directories.
Assets are likely inline in scenes or scattered.
**Fix**: Create directory structure when card art and icon production begins.
Planned paths: `assets/cards/`, `assets/ui/`, `assets/icons/`, `assets/vfx/`.

---

## 9. Visual Hierarchy Rules

1. **Rarity is the strongest color signal** -- player must identify card quality in <200ms.
2. **Card type is the second signal** -- distinguished by the type color stripe and icon.
3. **Era is communicated through sprite style** and background, not color (to avoid overload).
4. **Slot colors are functional, not decorative** -- green/red/blue/yellow map directly to
   phase instrument slot types. Do not repurpose these colors for other UI elements.
5. **Error/danger always uses #F24D4D** -- never use red for any non-error purpose in the UI
   to avoid confusion with the red law slot.

---

## Appendix: Source File Cross-Reference

| Color System | File | Line(s) | Key Language | Status |
|-------------|------|---------|-------------|--------|
| Rarity colors | `resources/game_constants.gd` | 182-189 | English | AUTHORITY |
| Rarity names | `resources/game_constants.gd` | 172-179 | English->Chinese map | AUTHORITY |
| Rarity colors (removed) | `resources/affix_resource.gd` | — | English | RESOLVED — function removed 2026-04-24 |
| Rarity colors (delegated) | `scripts/ui_theme_manager.gd` | 212-213 | English | RESOLVED — delegates to GameConstants 2026-04-24 |
| Rarity colors (removed) | `scenes/ui/synthesis_panel.gd` | — | English | RESOLVED — inline matches removed 2026-04-24 |
| Rarity colors (delegated) | `data/tower_relics.gd` | 177-180 | English | RESOLVED — delegates to GameConstants 2026-04-24 |
| Card type colors | `scenes/ui/card_affix_tooltip.gd` | 221-227 | Enum int | AUTHORITY (LAW added 2026-04-24) |
| Slot colors | `scripts/ui_theme_manager.gd` | 18-21 | English | AUTHORITY |
| Theme primary | `scripts/ui_beautifier.gd` | 15 | English | CONFLICT -- resolve |
| UI system colors | `scripts/ui_theme_manager.gd` | 12-31 | English | AUTHORITY |
| Font spec | `design/ux/interaction-patterns.md` | Appendix C | -- | REFERENCE |
| Animation timing | `design/ux/interaction-patterns.md` | Appendix B | -- | REFERENCE |
