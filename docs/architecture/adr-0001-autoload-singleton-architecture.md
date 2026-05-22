# ADR-0001: Autoload Singleton Architecture

## Status

Accepted

## Date

2026-04-23

## Last Verified

2026-04-23

## Decision Makers

Project lead (reverse-documented from implementation)

## Summary

Phase War uses Godot's built-in Autoload system with a two-tier strategy: 16 core managers registered as autoloads at startup, plus ~20 additional managers instantiated on-demand via `ManagerLazyLoader` with priority-based initialization tiers. This avoids the Godot 4.x single-scene tree limitation while keeping startup time manageable.

## Engine Compatibility

| Field | Value |
|-------|-------|
| **Engine** | Godot 4.5 |
| **Domain** | Core / Scripting |
| **Knowledge Risk** | LOW — Autoload is a stable Godot feature since 3.x |
| **References Consulted** | `docs/engine-reference/godot/VERSION.md` |
| **Post-Cutoff APIs Used** | None |
| **Verification Required** | None |

## ADR Dependencies

| Field | Value |
|-------|-------|
| **Depends On** | None (foundational) |
| **Enables** | ADR-0002 (SignalBus), ADR-0003 (Data Layer), ADR-0004 (Save System), ADR-0005 (Phase Instrument) |
| **Blocks** | All system-level ADRs |
| **Ordering Note** | Must be accepted before any system ADR references manager access patterns |

## Context

### Problem Statement

Phase War has 35+ manager classes that need global access from any scene or node. Godot does not support multi-scene singleton patterns natively — all shared state must be registered as autoloads or passed through scene trees. The challenge is balancing startup performance (loading 35 managers at boot) with code simplicity (direct global access).

### Current State

All 35 managers are accessible via `/root/ManagerName` pattern. 16 core managers load at startup; remaining ~20 are lazy-loaded by `ManagerLazyLoader`.

### Constraints

- Godot 4.x autoloads are registered at `/root/` in the SceneTree before `MainLoop` runs
- Solo developer project — simplicity is valued over enterprise patterns
- Target: PC (Steam/Epic) — startup time budget of < 3 seconds
- Memory ceiling: 512 MB

### Requirements

- All managers accessible from any script via global name
- Startup time under 3 seconds
- No uninitialized manager access crashes
- Lazy managers must behave identically to autoload managers for callers

## Decision

Use Godot's native Autoload pattern with a two-tier strategy:

1. **Core tier**: 16 managers registered in `project.godot` as autoloads (always available)
2. **Lazy tier**: ~20 managers instantiated on-demand by `ManagerLazyLoader` with priority groups

### Architecture

```
project.godot (16 autoloads)
├── SignalBus              (events)
├── BattleInputState       (input)
├── EnergyManager          (core resource)
├── PhaseInstrumentManager (loadout)
├── BattleManager          (core gameplay)
├── GameManager            (lifecycle)
├── BlueprintManager       (progression)
├── DropManager            (economy)
├── SaveManager            (persistence)
├── AudioManager           (audio)
├── PhaseLawManager        (laws)
├── BasicResourceManager  (resources)
├── ObjectPoolManager      (performance)
├── UILazyLoader           (UI optimization)
├── ManagerLazyLoader      (lazy loading)
└── PerformanceMetricsManager (profiling)

ManagerLazyLoader (priority tiers)
├── Priority 1:  AuraManager, BattleFeedbackManager, LevelProgressManager
├── Priority 2:  QuestManager, AchievementManager, DailyTaskManager, ChallengeModeManager
├── Priority 3:  FactionSystemManager, AffixManager
├── Priority 4:  CardCollectionManager, CardEnhancementManager, LawShardManager, StatBoostManager
├── Priority 5:  StatisticsManager, LeaderboardManager
├── Priority 6:  LoreManager, StoryManager, CharacterManager
├── Priority 7:  TutorialProgressionManager
├── Priority 8:  NewSystemsIntegration
├── Priority 9:  ToastManager, VersionManager
└── Priority 99: DebugLog
```

### Key Interfaces

```gdscript
# Lazy-loaded managers are accessed identically to autoloads:
BlueprintManager.get_blueprint_star(id)  # autoload
QuestManager.notify_battle_result(data)  # lazy-loaded

# The lazy loader mimics autoload behavior:
# _instantiate_manager() adds child to root tree at /root/ManagerName
```

### Implementation Guidelines

- Core autoloads should be managers needed within the first 3 seconds of gameplay
- New managers default to lazy tier unless they are needed at startup
- Use `has_method()` checks for cross-manager calls to lazy-loaded managers (they may not exist yet)
- All managers extend `Node` (not `RefCounted`) so they can be added to the tree

## Alternatives Considered

### Alternative 1: All 35 managers as autoloads

- **Description**: Register every manager in `project.godot`
- **Pros**: Maximum simplicity; all managers always available
- **Cons**: Slower startup (~5+ seconds estimated); higher memory baseline
- **Estimated Effort**: Less (current approach)
- **Rejection Reason**: Startup time budget exceeded; unnecessary managers loaded for modes the player may not visit

### Alternative 2: Service Locator pattern with interfaces

- **Description**: Custom `ServiceLocator` autoload with typed interfaces
- **Pros**: Compile-time type safety; testable with mocks
- **Cons**: More boilerplate; harder to learn; GDScript lacks interface enforcement
- **Estimated Effort**: 2-3 sessions to refactor
- **Rejection Reason**: Solo dev overhead not justified; GDScript lacks native interface support

### Alternative 3: Dependency Injection via scene tree

- **Description**: Pass manager references through scene tree (`owner.find_child()`)
- **Pros**: No global state; testable
- **Cons**: Extremely verbose for 35 managers; every node needs boilerplate
- **Estimated Effort**: 5+ sessions to refactor
- **Rejection Reason**: Anti-pattern in Godot; contradicts idiomatic engine usage

## Consequences

### Positive

- Simple, idiomatic Godot code; any GDScript developer understands the pattern
- Two-tier strategy keeps startup fast while providing transparent access
- Priority tiers prevent resource managers from blocking battle managers

### Negative

- Tight coupling: managers reference each other by hardcoded global names
- No interface contracts; `has_method()` guards are pervasive and fragile
- 16 autoloads is near the practical limit for startup performance
- Lazy-loaded managers may not be initialized when first accessed if priority is wrong

### Neutral

- All managers are effectively global mutable state
- No dependency graph enforcement — circular references possible

## Risks

| Risk | Probability | Impact | Mitigation |
|------|------------|--------|-----------|
| Startup time regression as more managers move to core tier | Medium | Medium | Keep core tier at 16 max; audit startup time on each addition |
| Circular dependency between managers | High | Medium | `has_method()` guards prevent crashes but hide design issues |
| Lazy manager accessed before initialization | Low | High | Priority tiers ordered by usage frequency; ManagerLazyLoader logs warnings |
| Godot 4.6+ changes autoload behavior | Low | High | Monitor migration guides; ADR re-validation on engine upgrade |

## Performance Implications

| Metric | Before | Expected After | Budget |
|--------|--------|---------------|--------|
| CPU (frame time) | N/A | N/A (no per-frame cost) | 16.6ms |
| Memory | ~20MB baseline | ~30-40MB with all managers loaded | 512MB |
| Load Time | ~1.5s (16 autoloads) | ~2.5s (with lazy tier loaded) | 3s |
| Network | N/A | N/A | N/A |

## Migration Plan

No migration needed — this is the current architecture, reverse-documented from implementation.

**Rollback plan**: N/A (foundational architecture)

## Validation Criteria

- [ ] Startup time under 3 seconds on target hardware
- [ ] No uninitialized manager access crashes in normal gameplay flow
- [ ] All 35 managers accessible via `/root/ManagerName` pattern
- [ ] Lazy-loaded managers available within 1 frame of first access

## GDD Requirements Addressed

Foundational — no GDD requirement. Enables:
- `design/gdd/battle-system.md` — BattleManager, EnergyManager, PhaseLawManager access
- `design/gdd/blueprint-system.md` — BlueprintManager singleton access
- `design/gdd/phase-law-system.md` — PhaseLawManager, BlueprintManager coordination
- `design/gdd/energy-system.md` — EnergyManager global state
- `design/gdd/drop-system.md` — DropManager, BlueprintManager, BasicResourceManager access
- `design/gdd/synthesis-system.md` — SynthesisManager (lazy-loaded) access
- `design/gdd/unit-stats-system.md` — UnitStats Resource creation from managers

## Related

- `project.godot` lines 19-36 (autoload definitions)
- `managers/manager_lazy_loader.gd` (lazy loading implementation)
- ADR-0002: SignalBus Event Mediator (depends on autoload pattern)
- ADR-0004: Save System Architecture (depends on autoload for coordinator access)
