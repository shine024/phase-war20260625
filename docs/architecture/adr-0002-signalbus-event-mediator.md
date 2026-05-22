# ADR-0002: SignalBus Event Mediator

## Status

Accepted

## Date

2026-04-23

## Last Verified

2026-04-23

## Decision Makers

Project lead (reverse-documented from implementation)

## Summary

Phase War uses a single centralized `SignalBus` autoload with 55+ typed signals as the sole event mediator across all systems. This decouples emitters from listeners and replaces direct method calls between managers for event-driven communication. All managers emit events to SignalBus; UI panels and other managers connect to receive them.

## Engine Compatibility

| Field | Value |
|-------|-------|
| **Engine** | Godot 4.5 |
| **Domain** | Core / Scripting |
| **Knowledge Risk** | LOW — Godot signals are stable since 3.x |
| **References Consulted** | `docs/engine-reference/godot/VERSION.md` |
| **Post-Cutoff APIs Used** | None |
| **Verification Required** | None |

## ADR Dependencies

| Field | Value |
|-------|-------|
| **Depends On** | ADR-0001 (Autoload Singleton Architecture) |
| **Enables** | ADR-0004 (Save System), ADR-0005 (Phase Instrument) |
| **Blocks** | None |
| **Ordering Note** | SignalBus itself is an autoload; depends on the autoload pattern |

## Context

### Problem Statement

With 35+ manager singletons, direct inter-manager method calls create tight coupling and make it impossible to add new listeners without modifying the emitter. UI panels need to react to gameplay events without managers knowing about specific UI components.

### Current State

`scripts/signal_bus.gd` defines 55 signals used across 42 files (228 total connection points). The heaviest consumers are `tower_climb_manager.gd` (24 refs), `battle_hud.gd` (20 refs), and `backpack_presenter.gd` (15 refs).

### Constraints

- GDScript has no compile-time signal connection validation
- Solo developer — traceability is more important than strict typing
- UI and gameplay must be fully decoupled (different scenes)

### Requirements

- Emitters must not know who listens
- Listeners must not know who emits
- Adding a new listener must not require modifying the emitter
- Signal parameters must be typed for IDE auto-completion

## Decision

Use a single `SignalBus` autoload with all game signals declared as typed `signal` declarations. All inter-system event communication goes through SignalBus. Direct method calls are reserved for synchronous request-response patterns (e.g., `BlueprintManager.get_blueprint_star(id)`).

### Architecture

```
┌──────────────┐    emit     ┌────────────┐    connect    ┌──────────────┐
│ BattleManager │────────────▶│ SignalBus  │◀────────────│ BattleHUD    │
└──────────────┘             │            │              └──────────────┘
                             │  55 signals│              ┌──────────────┐
┌──────────────┐    emit     │            │    connect    │ BackpackPanel│
│ DropManager   │────────────▶│            │◀────────────│              │
└──────────────┘             └────────────┘              └──────────────┘

Direct method calls (synchronous):
┌──────────────┐    call     ┌──────────────────┐
│ BattleManager │───────────▶│ BlueprintManager  │
└──────────────┘             └──────────────────┘
```

### Key Interfaces

```gdscript
# SignalBus defines typed signals:
signal energy_changed(current: float, max: float)
signal battle_started()
signal card_added_to_backpack(card: CardResource)

# Emitting:
SignalBus.battle_started.emit()

# Listening:
SignalBus.battle_started.connect(_on_battle_started)
```

### Implementation Guidelines

- Use signals for **notification** patterns (something happened, react if you care)
- Use direct method calls for **query** patterns (I need this data, give it to me now)
- New signals must have typed parameters (no untyped `signal foo(arg)`)
- UI toggle signals (`toggle_backpack`, `toggle_synthesis`) belong on SignalBus for UI decoupling
- Do not create per-domain signal buses — keep everything on SignalBus

## Alternatives Considered

### Alternative 1: Per-domain signal buses

- **Description**: Separate buses for `BattleEvents`, `InventoryEvents`, `UIEvents`, etc.
- **Pros**: Smaller files, clearer ownership, less signal noise
- **Cons**: Cross-domain events (e.g., quest triggered by inventory change) become awkward
- **Estimated Effort**: 1-2 sessions to refactor
- **Rejection Reason**: Cross-domain events are common in Phase War; splitting adds complexity without clear benefit at current scale

### Alternative 2: Observer pattern via manager callbacks

- **Description**: Each manager registers listeners on other managers directly
- **Pros**: No central bus; each manager owns its event surface
- **Cons**: Circular dependencies; managers need to know about each other; harder to add listeners
- **Estimated Effort**: 3+ sessions to refactor
- **Rejection Reason**: Defeats the decoupling goal; managers already tightly coupled via method calls

### Alternative 3: Godot's built-in `group` notification

- **Description**: Use `add_to_group()` + `call_group()` for notifications
- **Pros**: Built-in engine feature; no custom code
- **Cons**: Untyped; no parameters; broadcast-only (no filtering)
- **Estimated Effort**: 1 session to refactor
- **Rejection Reason**: Cannot carry typed payloads; too limited for complex game events

## Consequences

### Positive

- Complete decoupling of emitters from listeners
- Simple to add new signals — one line in SignalBus, one connect in listener
- Typed parameters provide IDE auto-completion
- UI and gameplay fully decoupled

### Negative

- Single monolithic file growing toward maintainability concerns (55+ signals)
- No compile-time safety — typos in signal names fail silently at runtime
- Difficulty tracing signal flows without IDE tooling (who emits? who listens?)
- Mixing UI toggle signals with domain events on the same bus

### Neutral

- SignalBus is stateless — pure event passing, no logic
- All connections are made at runtime (typically in `_ready()`)

## Risks

| Risk | Probability | Impact | Mitigation |
|------|------------|--------|-----------|
| SignalBus grows to 200+ signals | Medium | Medium | Monitor signal count; split into domain buses if > 100 |
| Runtime errors from signal typos | High | Low | `has_signal()` checks for dynamic connections; IDE plugin support |
| Performance cost of signal fan-out | Low | Low | Godot signals are lightweight; 55 signals × ~5 listeners = trivial |
| Difficulty debugging signal chains | Medium | Medium | Add debug logging wrappers if tracing becomes necessary |

## Performance Implications

| Metric | Before | Expected After | Budget |
|--------|--------|---------------|--------|
| CPU (frame time) | N/A | ~0.01ms per signal emit | 16.6ms |
| Memory | ~1KB (signal objects) | ~2KB (55 signals × listeners) | 512MB |
| Load Time | Negligible | Negligible | 3s |

## Migration Plan

No migration needed — current architecture reverse-documented from implementation.

**Rollback plan**: N/A (foundational architecture)

## Validation Criteria

- [ ] All 55 signals have typed parameters
- [ ] No direct method calls between managers for event notification (only queries)
- [ ] New UI panel can react to gameplay events without modifying manager code

## GDD Requirements Addressed

Foundational — no GDD requirement. Enables:
- `design/gdd/battle-system.md` — Battle events (started, ended, wave_spawned, unit_died)
- `design/gdd/energy-system.md` — Energy state events (energy_changed, energy_insufficient)
- `design/gdd/blueprint-system.md` — Blueprint progression events (unlocked, star_upgraded, obtained)
- `design/gdd/drop-system.md` — Drop events (drops_ready_to_claim, card_added_to_backpack)
- `design/gdd/phase-law-system.md` — Law events (phase_law_cast, active_law_cast_at)
- `design/gdd/achievement-system.md` — Achievement events (unlocked, progress_updated)
- `design/gdd/quest-system.md` — Quest events (quest_completed, task_completed)

## Related

- `scripts/signal_bus.gd` (SignalBus implementation, 129 lines)
- ADR-0001: Autoload Singleton Architecture (SignalBus is an autoload)
- 42 consumer files across the codebase (228 total references)
