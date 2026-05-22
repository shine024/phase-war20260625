# Control Manifest

> **Engine**: Godot 4.5
> **Last Updated**: 2026-04-24
> **Manifest Version**: 2026-04-24
> **ADRs Covered**: ADR-0001, ADR-0002, ADR-0003, ADR-0004, ADR-0005, ADR-0006, ADR-0007
> **Status**: Active — regenerate with `/create-control-manifest update` when ADRs change

This manifest is a programmer's quick-reference extracted from all Accepted ADRs,
technical preferences, and engine reference docs. For the reasoning behind each
rule, see the referenced ADR.

---

## Foundation Layer Rules

*Applies to: scene management, event architecture, save/load, engine initialisation*

### Required Patterns
- **Two-tier autoload strategy**: 16 core autoloads via Project Settings + ~20 lazy-loaded via `ManagerLazyLoader` with priority tiers (CRITICAL/HIGH/NORMAL/LOW) — source: ADR-0001
- **ManagerLazyLoader placement**: `_instantiate_manager()` must place each manager at `/root/Name` to mimic Autoload behaviour — source: ADR-0001
- **Priority tier ordering**: CRITICAL managers first, then HIGH, NORMAL, LOW — respect frame-spread budget per tier — source: ADR-0001
- **SignalBus for all cross-system notifications**: Every notification between autoloads or distant systems must emit a typed SignalBus signal — source: ADR-0002
- **Typed signal naming**: SignalBus signals use snake_case past tense (e.g., `health_changed`, `card_equipped`) — source: ADR-0002
- **Queries via direct calls, notifications via signals**: Use `SomeManager.get_value()` for queries; use `SignalBus.value_changed.emit()` for notifications — source: ADR-0002
- **Static data pattern**: Game data tables use `extends RefCounted` classes with `const` dictionaries; never store mutable game state in static data — source: ADR-0003
- **Runtime data as Resource**: Instance-specific data (cards, save slots, equipped items) use Godot `Resource` objects — source: ADR-0003
- **Enemy data in JSON**: Enemy archetype data lives in `data/json/` and is parsed at game load — source: ADR-0003
- **Memento pattern for saves**: `SaveManager` collects state snapshots from managers, writes atomically (temp file → rename), schema versioned — source: ADR-0004
- **Critical vs non-critical save tiers**: Critical managers (inventory, progress) save synchronously; non-critical managers (settings, cache) save deferred with 10s batch — source: ADR-0004

### Forbidden Approaches
- **Never directly instantiate manager singletons** — use `ManagerLazyLoader` which handles `/root/Name` registration and priority ordering — source: ADR-0001
- **Never create circular autoload dependencies** — A depends on B depends on A is forbidden; refactor to use SignalBus or shared data — source: ADR-0001
- **Never use string-based signal connections** — use `signal.connect(callable)` with typed Callable, not `signal.connect("method_name")` — source: ADR-0002
- **Never use polling loops for cross-system state** — emit a SignalBus signal when state changes; consumers subscribe once — source: ADR-0002

### Performance Guardrails
- **ManagerLazyLoader frame budget**: Frame-spread instantiation must not exceed 16.6 ms per frame; limit lazy instantiations per frame — source: ADR-0001
- **Signal handler weight**: Signal dispatch is synchronous — handlers that exceed 1 ms must use `call_deferred()` to avoid blocking the emit call chain — source: ADR-0002
- **Save operation budget**: Full save must complete in < 100 ms; deferred saves are batched every 10 s — source: ADR-0004

---

## Core Layer Rules

*Applies to: core gameplay loop, main player systems, physics, collision*

### Required Patterns
- **4-color slot model**: Phase instrument slots use fixed color coding — red (active laws), blue (passive laws), green (platform + weapon pairs), yellow (energy cards) — source: ADR-0005
- **Card-to-color validation**: `equip_card()` must reject cards placed in incompatible color slots — source: ADR-0005
- **Dirty flag on slot change**: Always call `_mark_loadouts_dirty()` after any equip/unequip/slot modification — source: ADR-0005
- **PhaseLawManager sync before battle**: Call `sync_law_cards_to_phase_law_manager()` before battle starts to prevent law state desync — source: ADR-0005
- **Era-based wave scaling**: Wave count, spawn density, and intervals use `LevelEras` static utility with linear intra-era interpolation — source: ADR-0006
- **Symmetric unit cap**: Both player and enemy units hard-capped at 5 via `clampi(..., 1, 5)` — source: ADR-0006
- **Phase Master bypass**: `_is_phase_master_battle` flag checked at top of `BattleManager._process()` — when true, entire wave timer and spawn logic is skipped — source: ADR-0006, ADR-0007
- **Phase Master 3-layer architecture**: Trigger (GameManager.check_phase_master_encounter) → Enrichment (_enrich_master_config) → Execution (EnemyPhaseFieldDriver) — source: ADR-0007
- **Equipment-based enemy production**: Phase Master uses `_produce_unit_with_equipment()` (platform + weapon selection) with `_produce_unit_fallback()` when JSON data missing — source: ADR-0007
- **Faction-matching for master selection**: `_enrich_master_config` maps 7 player factions to 4 enemy factions — source: ADR-0007

### Forbidden Approaches
- **Never increase law auto-routing recursion beyond depth 2** — prevents infinite recursion; add new law types with caution — source: ADR-0005
- **Never cache loadouts across battle sessions** — invalidate cache between battles; loadout computation is session-scoped by design — source: ADR-0005
- **Never use per-level JSON wave definitions** — era-based interpolation with `LevelEras` is the design; per-level JSON rejected for 100-level maintenance burden — source: ADR-0006
- **Never exceed the 5-unit hard cap** for standard battles — `clampi(..., 1, 5)` is shared between player and enemy sides — source: ADR-0006
- **Never emit wave signals during Phase Master battles** — `wave_started`/`wave_completed` must not fire; the wave system is completely bypassed — source: ADR-0007
- **Never implement Phase Master as a selectable mode** — 15% random trigger + Level 49 forced is the design; selectable mode rejected for loss of surprise — source: ADR-0007

### Performance Guardrails
- **Loadout computation budget**: `get_loadouts()` uncached must complete in < 5 ms (target: 5 green slots x 4 weapons); cached lookup must be < 0.01 ms — source: ADR-0005
- **Wave timer budget**: Timer check in `BattleManager._process` costs ~0.1 ms/frame — source: ADR-0006
- **Phase Master driver budget**: `EnemyPhaseFieldDriver._process` timer costs ~0.05 ms/frame — source: ADR-0007
- **Active unit cap for performance**: Standard battles: max 10 units (5+5); Phase Master high-tier: may reach 15 — monitor via `PerformanceMetricsManager` — source: ADR-0006, ADR-0007

---

## Feature Layer Rules

*Applies to: secondary mechanics, AI systems, secondary features*

No rules yet — no Accepted ADRs govern Feature layer systems.

---

## Presentation Layer Rules

*Applies to: rendering, audio, UI, VFX, shaders, animations*

No rules yet — no Accepted ADRs govern Presentation layer systems.

---

## Global Rules (All Layers)

### Naming Conventions
| Element | Convention | Example |
|---------|-----------|---------|
| Classes | PascalCase | `PlayerController`, `PhaseInstrumentManager` |
| Variables / Functions | snake_case | `move_speed`, `get_loadouts()` |
| Signals / Events | snake_case past tense | `health_changed`, `card_equipped` |
| Files (.gd) | snake_case matching class | `player_controller.gd` |
| Scenes (.tscn) | PascalCase matching root | `PlayerController.tscn` |
| Constants | UPPER_SNAKE_CASE | `MAX_HEALTH`, `SLOT_COLOR_ORDER` |

### Performance Budgets
| Target | Value |
|--------|-------|
| Framerate | 60 FPS |
| Frame budget | 16.6 ms |
| Draw calls | < 200 per frame |
| Memory ceiling | 512 MB |

### Approved Libraries / Addons
- GdUnit4 — testing framework for unit and integration tests

### Forbidden APIs (Godot 4.5)
These APIs are deprecated or replaced in Godot 4.5:
- `TileMap` — replaced by `TileMapLayer` (deprecated since 4.3)
- `yield()` — replaced by `await` (deprecated since 4.0)
- `instance()` — replaced by `instantiate()` (deprecated since 4.0)
- String-based `connect("method_name")` — replaced by Callable-based `connect(callable)`
- `$NodePath` for frequent access — use `@onready var` (deprecated pattern)
- Untyped `Array` / `Dictionary` — use typed variants `Array[Type]` / `Dictionary`
- `duplicate()` for nested Resources — use `duplicate_deep()` (added 4.4)

Source: `docs/engine-reference/godot/deprecated-apis.md`

### Cross-Cutting Constraints
- All gameplay values must be data-driven (external config), never hardcoded in scripts — source: coding-standards.md
- All public methods must be unit-testable (dependency injection over singleton access where practical) — source: coding-standards.md
- Commits must reference the relevant design document or task ID — source: coding-standards.md
