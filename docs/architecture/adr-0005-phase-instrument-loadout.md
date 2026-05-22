# ADR-0005: Phase Instrument Loadout Architecture

## Status

Accepted

## Date

2026-04-23

## Last Verified

2026-04-23

## Decision Makers

Project lead (reverse-documented from implementation)

## Summary

Phase War uses a four-color slot model for pre-battle loadout configuration: red slots (active laws), blue slots (passive laws), green slots (platform + weapon pairs), and yellow slots (energy cards). The `PhaseInstrumentManager` manages slot assignment, validates card-to-color compatibility, auto-routes law cards to the correct color, and computes cached loadouts for the battle system. Slot counts scale with instrument star level and faction.

## Engine Compatibility

| Field | Value |
|-------|-------|
| **Engine** | Godot 4.5 |
| **Domain** | Core / Gameplay |
| **Knowledge Risk** | LOW — Array manipulation and Resource handling are stable |
| **References Consulted** | `docs/engine-reference/godot/VERSION.md` |
| **Post-Cutoff APIs Used** | None |
| **Verification Required** | None |

## ADR Dependencies

| Field | Value |
|-------|-------|
| **Depends On** | ADR-0001 (Autoload), ADR-0002 (SignalBus), ADR-0003 (Data Layer) |
| **Enables** | None (enables gameplay, not other ADRs) |
| **Blocks** | None |
| **Ordering Note** | PhaseInstrumentManager depends on BlueprintManager (autoload), SignalBus (events), and DefaultCards/PhaseInstruments (static data) |

## Context

### Problem Statement

Players must assemble a pre-battle loadout from their collected cards: platforms, weapons, laws, and energy cards. The system needs to validate what goes where, compute the resulting combat loadouts for the battle system, and keep law card slots synchronized with `PhaseLawManager`'s equipped law state.

### Current State

`managers/phase_instrument_manager.gd` (839 lines) implements:
- 4-color slot system with `SLOT_COLOR_ORDER = ["red", "blue", "green", "yellow"]`
- Slot counts per instrument definition and star level (3-11 slots)
- 7 faction-specific layouts
- Law card auto-routing (red/blue swap with max depth 2)
- Cached loadout computation (`_loadouts_cache` with dirty flag)
- Bi-directional sync with `PhaseLawManager` (equipped laws)
- Phase XP/leveling system (16 levels, 0-7500 XP thresholds)

### Constraints

- UI must clearly show which cards go in which slots (color coding)
- Players should not need to know law types (active vs passive) to equip them
- Battle system needs loadout data instantly (cached, not computed on-demand)
- Law slot state must match PhaseLawManager at all times (prevents desync bugs)

### Requirements

- Card-to-color validation prevents mismatched equipment
- Law card auto-routing reduces player friction
- Loadout computation must complete in < 5ms
- PhaseLawManager sync must happen before battle starts
- Slot capacity scales with instrument star level

## Decision

Four-color slot model with auto-routing for law cards and cached loadout computation. The `PhaseInstrumentManager` is the single authority for loadout state; `PhaseLawManager` is a secondary sync target.

### Architecture

```
PhaseInstrumentManager
├── Slots (4 color groups)
│   ├── Red (Active Laws)    — 1-2 slots by star
│   ├── Blue (Passive Laws)  — 0-2 slots by star
│   ├── Green (Platform+Weapon) — 1-5 slots by star
│   └── Yellow (Energy Cards) — 1-2 slots by star
├── Loadout Computation (cached)
│   └── get_loadouts() → [{platform, weapons[], used_weight, capacity}]
├── Law Sync (bidirectional with PhaseLawManager)
│   ├── sync_law_cards_to_phase_law_manager()
│   ├── _compact_law_ids_for_kind()
│   └── _apply_law_slots_to_plm()
└── Phase XP System
    └── 16 levels, thresholds 0-7500 XP

Equip Flow:
  equip_card(slot_index, card)
    → validate card-to-color compatibility
    → if law card in wrong color: auto-route to correct color
    → validate with PhaseLawManager (for laws)
    → return old card to backpack
    → emit SignalBus.card_equipped
    → mark loadout cache dirty

Loadout Flow (before battle):
  get_loadouts()
    → check cache dirty flag
    → scan green slots for platforms
    → match weapons to platforms by weight capacity
    → cache result
    → return [{platform, weapons, used_weight, capacity}]
```

### Key Interfaces

```gdscript
# Public API:
func equip_card(slot_index: int, card: CardResource) -> CardResource
func unequip_card(slot_index: int) -> CardResource
func get_loadouts() -> Array[Dictionary]
func get_slots() -> Array[CardResource]
func get_max_deployable_units() -> int
func get_energy_output_rate() -> float

# Law sync (called before battle):
func sync_law_cards_to_phase_law_manager()
```

### Implementation Guidelines

- New card types that go into specific colors must add validation in `_can_equip_card_to_color()`
- Law card auto-routing has max depth 2 — do not increase to prevent infinite recursion
- Always call `_mark_loadouts_dirty()` after any slot change
- Loadout cache is invalidated by design; do not cache across battle sessions
- PhaseLawManager sync must happen in `sync_law_cards_to_phase_law_manager()` before battle start

## Alternatives Considered

### Alternative 1: Free-form slot system (no color coding)

- **Description**: Any card goes in any slot; player manages constraints manually
- **Pros**: Maximum flexibility; simpler validation
- **Cons**: Confusing for players; no visual affordance; law cards mixed with combat cards
- **Estimated Effort**: 1 session (simpler implementation)
- **Rejection Reason**: Color coding is core to the game's visual identity; removing it would harm UX

### Alternative 2: Equipment grid (like FFT or XCOM)

- **Description**: 2D grid where cards are placed in cells
- **Pros**: More strategic depth; positioning matters
- **Cons**: Much more complex UI; harder to implement; over-engineered for card game
- **Estimated Effort**: 5+ sessions
- **Rejection Reason**: Phase War is an auto-battler, not a tactical RPG; slot system is appropriate

### Alternative 3: Separate panels per card type

- **Description**: 4 separate UI panels (laws, platforms, weapons, energy) instead of unified instrument
- **Pros**: Simpler validation per panel; clearer organization
- **Cons**: Fragmented UX; no visual "loadout" concept; harder to see the whole picture
- **Estimated Effort**: 2-3 sessions for UI redesign
- **Rejection Reason**: The instrument is a core visual metaphor; splitting it loses the design intent

## Consequences

### Positive

- Color-coded slots provide clear visual affordance
- Law card auto-routing reduces player friction (don't need to know active vs passive)
- Cached loadouts avoid redundant computation during battle
- Star-level scaling provides meaningful progression for loadout capacity

### Negative

- Green slot loadout algorithm is O(n*m) (green slots × max weapons) — could be slow with many slots
- Red/blue law slot ↔ PhaseLawManager sync is complex with multiple fallback paths
- `_flat_index_to_slot()` / `_slot_to_flat_index()` conversions add indirection
- Debug logging hardcoded path (`F:/godot fair duel/phase-war/debug-585b52.log`) should be removed

### Neutral

- Slot count varies by faction (7 factions with unique layouts)
- Phase XP is separate from instrument star level (two progression axes)

## Risks

| Risk | Probability | Impact | Mitigation |
|------|------------|--------|-----------|
| Law sync desync with PhaseLawManager | Medium | High | Add assertion checks before battle; log warnings on mismatch |
| Loadout computation slow with many green slots | Low | Medium | Profile with max slots (5 green × 4 weapons); optimize if > 5ms |
| Auto-routing recursion overflow | Low | Medium | Max depth 2 is enforced; increase only if new law types added |
| Faction-specific slot layouts create edge cases | Medium | Medium | Comprehensive test coverage for all 7 faction layouts |

## Performance Implications

| Metric | Before | Expected After | Budget |
|--------|--------|---------------|--------|
| CPU (equip card) | ~1ms | ~2ms (with validation + sync) | 16.6ms |
| CPU (get_loadouts, cached) | ~0.01ms | ~0.01ms (cache hit) | 16.6ms |
| CPU (get_loadouts, uncached) | N/A | ~2ms (5 green slots × 4 weapons) | 16.6ms |
| Memory | ~5KB (slot data) | ~10KB (with cache) | 512MB |

## Migration Plan

No migration needed — current architecture reverse-documented from implementation.

**Rollback plan**: N/A (foundational architecture)

## Validation Criteria

- [ ] Card-to-color validation rejects mismatched cards
- [ ] Law card auto-routing places active laws in red, passive laws in blue
- [ ] Loadout cache returns identical results to fresh computation
- [ ] PhaseLawManager sync produces matching equipped laws before battle
- [ ] All 7 faction slot layouts validate correctly
- [ ] Max slot count (11 slots at star 7) computes loadout in < 5ms

## GDD Requirements Addressed

Foundational — no GDD requirement. Enables:
- `design/gdd/battle-system.md` — Pre-battle loadout determines available forces
- `design/gdd/phase-law-system.md` — Law card equipping and PhaseLawManager sync
- `design/gdd/energy-system.md` — Yellow slot energy cards determine energy capacity/regen
- `design/gdd/blueprint-system.md` — Card equipping from backpack
- `design/gdd/unit-stats-system.md` — Loadout determines UnitStats for spawned units

## Related

- `managers/phase_instrument_manager.gd` (implementation, 839 lines)
- `data/phase_instruments.gd` (instrument definitions and XP thresholds)
- ADR-0001: Autoload Singleton Architecture (PhaseInstrumentManager is autoload)
- ADR-0002: SignalBus Event Mediator (card_equipped, card_unequipped signals)
- ADR-0003: Data Layer Design (phase_instruments.gd static data)
