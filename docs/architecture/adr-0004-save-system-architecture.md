# ADR-0004: Save System Architecture

## Status

Accepted

## Date

2026-04-23

## Last Verified

2026-04-23

## Decision Makers

Project lead (reverse-documented from implementation)

## Summary

Phase War uses a central `SaveManager` autoload that coordinates per-manager serialization via Memento-style `save_state()` / `load_state()` contracts. Game state is persisted as a single JSON file per save slot with atomic writes, automatic backups, schema versioning with migration chains, and deferred saving for non-critical data. 23 managers participate in the save/load cycle.

## Engine Compatibility

| Field | Value |
|-------|-------|
| **Engine** | Godot 4.5 |
| **Domain** | Core / Scripting |
| **Knowledge Risk** | LOW — FileAccess JSON is stable Godot API |
| **References Consulted** | `docs/engine-reference/godot/VERSION.md` |
| **Post-Cutoff APIs Used** | None (FileAccess API is stable) |
| **Verification Required** | None |

## ADR Dependencies

| Field | Value |
|-------|-------|
| **Depends On** | ADR-0001 (Autoload Singleton Architecture) |
| **Enables** | None (infrastructure) |
| **Blocks** | None |
| **Ordering Note** | SaveManager is an autoload; all saving managers depend on it being available |

## Context

### Problem Statement

Phase War has 23 managers with persistent state (blueprint progress, quest status, inventory, settings). The save system must handle multi-slot saves, schema migration across versions, atomic writes to prevent corruption, and performance-conscious deferred saving during gameplay.

### Current State

`managers/save_manager.gd` (1184 lines) implements:
- 3 save slots as JSON files (`user://save_slot_N.json`)
- Schema version 3 with v1→v2→v3 migration chain
- Atomic writes via tmp/rename pattern
- Auto-backup every 15 seconds
- Battle-deferred saving
- 1.2-second throttle between saves
- JSON repair for `inf`/`-inf`/`nan` values
- Critical (sync) vs non-critical (deferred) manager tiers

### Constraints

- Target: PC — no cloud save requirement (local files only)
- Save files must survive app crashes (atomic writes)
- Save must not cause frame drops during battle (deferred)
- Solo developer — save corruption must be recoverable (backups)
- No encryption requirement (single-player PC game)

### Requirements

- 3 save slots with independent state
- Schema migration across versions without data loss
- Atomic writes to prevent corruption on crash
- Automatic backup for recovery
- Battle-safe saving (deferred until battle ends)
- Save complete game state in < 50ms

## Decision

Central SaveManager with Memento pattern: each manager owns its own serialization via `save_state() -> Dictionary` and `load_state(data: Dictionary)`. SaveManager orchestrates the collection, persistence, and distribution of save data.

### Architecture

```
SaveManager (Coordinator)
├── Critical Managers (synchronous save/load)
│   ├── BlueprintManager.save_state()
│   ├── PhaseInstrumentManager.save_state()
│   ├── PhaseLawManager.save_state()
│   ├── QuestManager.save_state()
│   ├── BasicResourceManager.save_state()
│   ├── FactionSystemManager.save_state()
│   ├── AffixManager.save_state()
│   ├── LevelProgressManager.save_state()
│   └── DropManager.save_state()
├── Non-Critical Managers (deferred, cached 10s)
│   ├── LoreManager, StatBoostManager, AchievementManager
│   ├── DailyTaskManager, StatisticsManager
│   ├── CardEnhancementManager, LawShardManager
│   ├── TutorialProgressionManager, StoryManager
│   ├── CharacterManager, ChallengeModeManager
│   ├── CardCollectionManager, LeaderboardManager
│   └── (12 managers total)
└── Top-Level Keys
    ├── __schema_version: 3
    ├── game.current_level
    ├── phase_slots (rbgy order)
    └── backpack_extra_ids

Write Pipeline:
  collect_state() → serialize to JSON → write to .tmp → rename old to .prior → rename .tmp to main

Migration Pipeline:
  load JSON → check __schema_version → while ver < 3: apply_migration(ver) → ver++
```

### Key Interfaces

```gdscript
# Manager contract (implement in each manager):
func save_state() -> Dictionary:
    return {"key": value, ...}

func load_state(data: Dictionary):
    self._some_var = data.get("key", default_value)

# SaveManager API:
SaveManager.save_game(slot_index: int)
SaveManager.load_game(slot_index: int)
SaveManager.delete_save(slot_index: int)
SaveManager.has_save(slot_index: int) -> bool
SaveManager.get_save_info(slot_index: int) -> Dictionary
```

### Implementation Guidelines

- New managers that need persistence must implement `save_state()` and `load_state()`
- Register in the appropriate tier (critical vs non-critical) in SaveManager
- Non-critical data is cached for 10 seconds to avoid redundant collection
- During battle, all saves are deferred until `battle_ended` signal
- Migration functions must handle all intermediate versions (chain migration)
- Always use `data.get("key", default)` in `load_state()` for forward compatibility

## Alternatives Considered

### Alternative 1: Per-manager save files

- **Description**: Each manager writes its own JSON file independently
- **Pros**: No single coordinator; managers are self-contained
- **Cons**: No atomic save across managers; partial saves on crash; complex backup
- **Estimated Effort**: 2 sessions per manager to implement
- **Rejection Reason**: Partial saves would corrupt game state; coordination is essential

### Alternative 2: Godot Resource.save() / Resource.load()

- **Description**: Use Godot's native .tres serialization for save data
- **Pros**: Native Godot support; type-safe
- **Cons**: Not designed for frequent saves; no atomic writes; harder migration
- **Estimated Effort**: 3-4 sessions to refactor
- **Rejection Reason**: .tres is for assets, not runtime game state; JSON is more appropriate

### Alternative 3: SQLite database

- **Description**: Store save data in a local SQLite database
- **Pros**: Query power; efficient partial updates; transaction support
- **Cons**: Overkill for single-player; adds dependency; harder backup/restore
- **Estimated Effort**: 3 sessions
- **Rejection Reason**: JSON files are human-readable, debuggable, and sufficient

## Consequences

### Positive

- Extremely robust: atomic writes, backups, JSON repair, multi-version migration
- Deferred loading for non-critical managers reduces load-time stutter
- 3 save slots give players flexibility
- Human-readable JSON makes debugging easy

### Negative

- SaveManager at 1184 lines is very large; migration logic mixed with core save logic
- No encryption — save tampering is possible (acceptable for single-player PC)
- `_sanitize_save_variant` traverses entire save tree on every save (potential perf concern)
- Backpack card ID coordination via `_pending_backpack_ids` is complex and fragile
- No integrity checksumming — corrupted files may load partially

### Neutral

- JSON format allows manual save editing (debugging feature, not a bug)
- Schema versioning enables forward-compatible saves

## Risks

| Risk | Probability | Impact | Mitigation |
|------|------------|--------|-----------|
| SaveManager grows too large (> 1500 lines) | Medium | Medium | Split into SaveCoordinator + SaveMigrator + SavePersistence |
| Migration breaks existing saves | Medium | High | Keep all migration functions forever; test migration from v1 |
| Save corruption undetected by JSON repair | Low | High | Add checksum validation (hash of top-level keys) |
| Save performance degrades with more data | Low | Medium | Profile save time; optimize serialization if > 50ms |
| Backpack card ID coordination bugs | Medium | Medium | Simplify to direct array storage without pending ID dance |

## Performance Implications

| Metric | Before | Expected After | Budget |
|--------|--------|---------------|--------|
| CPU (save) | ~20ms | ~30ms (23 managers) | 50ms (non-blocking) |
| CPU (load) | ~50ms | ~50ms (23 managers) | 200ms (startup) |
| Memory | ~1MB (save data) | ~2MB (with backup) | 512MB |
| Load Time | ~0.1s (no save) | ~0.5s (with save) | 3s |

## Migration Plan

No migration needed — current architecture reverse-documented from implementation.

**Rollback plan**: N/A (foundational architecture)

## Validation Criteria

- [ ] Save completes in < 50ms on target hardware
- [ ] Load completes in < 200ms from slot
- [ ] Atomic write survives simulated crash (process kill during save)
- [ ] Backup file is created within 15 seconds of save
- [ ] v1→v2→v3 migration produces correct state for old save files
- [ ] Battle-deferred save triggers correctly on `battle_ended`

## GDD Requirements Addressed

Foundational — no GDD requirement. Enables:
- `design/gdd/blueprint-system.md` — Blueprint fragment/star state persistence
- `design/gdd/phase-law-system.md` — Law unlock/equip state persistence
- `design/gdd/energy-system.md` — No direct save (derived from phase instrument)
- `design/gdd/drop-system.md` — Pending drops serialization
- `design/gdd/quest-system.md` — Quest/progress state persistence
- `design/gdd/achievement-system.md` — Achievement unlock state persistence

## Related

- `managers/save_manager.gd` (SaveManager implementation, 1184 lines)
- ADR-0001: Autoload Singleton Architecture (SaveManager is an autoload)
- ADR-0002: SignalBus Event Mediator (save events if needed)
- ADR-0003: Data Layer Design (static data not saved; only runtime state)
