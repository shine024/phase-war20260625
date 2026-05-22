# ADR-0003: Data Layer Design

## Status

Accepted

## Date

2026-04-23

## Last Verified

2026-04-23

## Decision Makers

Project lead (reverse-documented from implementation)

## Summary

Phase War uses a two-tier data architecture: **static data** as `extends RefCounted` classes with `const` dictionaries and static lookup methods (accessible immediately via preload), and **runtime data** as Godot `Resource` objects (`CardResource`, `UnitStats`, `AffixResource`) created at runtime from static definitions. Enemy/archetype data additionally uses JSON files in `data/json/` for data-driven definitions.

## Engine Compatibility

| Field | Value |
|-------|-------|
| **Engine** | Godot 4.5 |
| **Domain** | Core / Scripting |
| **Knowledge Risk** | LOW — RefCounted and Resource are stable Godot features |
| **References Consulted** | `docs/engine-reference/godot/VERSION.md` |
| **Post-Cutoff APIs Used** | None |
| **Verification Required** | None |

## ADR Dependencies

| Field | Value |
|-------|-------|
| **Depends On** | ADR-0001 (Autoload Singleton Architecture) |
| **Enables** | ADR-0005 (Phase Instrument Loadout), ADR-0004 (Save System) |
| **Blocks** | None |
| **Ordering Note** | Data layer is accessed by all gameplay managers; must be stable before system ADRs |

## Context

### Problem Statement

Phase War needs to define 100+ levels, 68+ player cards, 4 law families, 5 eras, multiple enemy archetypes, and extensive configuration (drop tables, affix pools, quest definitions). This data must be loaded efficiently, support runtime modification (star levels, affixes), and be maintainable by a solo developer.

### Current State

- `data/` contains 36 `.gd` files (static data classes) and 12 JSON files
- `data/default_cards.gd` defines all 68+ player cards as `const` dictionaries
- JSON files used for enemy data (`enemy_archetypes.json`, `enemy_phase_equipment.json`, etc.)
- 6 custom Resource types in `resources/` for runtime data
- Static cache in `DefaultCards._all_cards_cache` avoids rebuilding on every lookup

### Constraints

- Solo developer — editing GDScript code is acceptable for card data (simpler tooling)
- Enemy data changes frequently during balancing — JSON files allow rapid iteration
- Memory ceiling: 512 MB (all static data must fit comfortably)
- No external database or server-side data storage

### Requirements

- All static data available immediately at game start (no async loading for gameplay data)
- Runtime modifications (star bonuses, affixes) do not modify static definitions
- Card/resource creation must be fast (< 1ms per card instantiation)
- Enemy data must support rapid balancing iteration without code changes

## Decision

Use `extends RefCounted` static classes with `const` data for core game definitions, supplemented by JSON files for frequently-balanced data (enemies). Runtime game objects use Godot `Resource` types created from static definitions.

### Architecture

```
Static Data Layer (always in memory, never modified)
├── data/default_cards.gd          (68+ card definitions)
├── data/phase_instruments.gd      (slot layouts, XP thresholds)
├── data/phase_laws.gd             (law definitions, families)
├── data/blueprint_star_config.gd  (star thresholds, affix pools)
├── data/basic_resources.gd        (resource type IDs)
├── data/level_eras.gd             (era boundaries)
├── data/affix_definitions.gd      (affix modifiers)
├── data/battle_environments.gd    (environment definitions)
├── data/quest_definitions.gd      (quest data)
├── data/achievement_definitions.gd (achievement data)
└── data/json/enemy_*.json         (enemy data, JSON-driven)

Runtime Data Layer (created from static definitions)
├── CardResource                   (a specific card instance)
├── UnitStats                       (combat stats for a unit)
├── AffixResource                   (an affix modifier instance)
├── GameConstants                   (enums and constants)
└── GameConfig                     (configuration Resource)

Access Pattern:
  DefaultCards.get_card_by_id("hound") → const dict
  BlueprintManager.create_card(id, star) → CardResource (runtime)
```

### Key Interfaces

```gdscript
# Static data access (RefCounted + preload):
var card_data: Dictionary = DefaultCards.get_card_by_id("hound")
var law_data: Dictionary = PhaseLaws.get_by_id("steel_quick_repair")

# Runtime data creation (from static definitions):
var card: CardResource = BlueprintManager.create_card("hound", star_level)
var stats: UnitStats = UnitStatsTable.build_multi_stats(platform, weapons, era)

# JSON data access (for enemy data):
var archetypes: Array = EnemyArchetypes.get_all()
# Loaded from data/json/enemy_archetypes.json
```

### Implementation Guidelines

- New card definitions go in `data/default_cards.gd` as `const` entries
- New enemy data goes in `data/json/enemy_archetypes.json` (not GDScript)
- Static cache should be used for any data accessed frequently per frame
- `DefaultCards.create_all()` builds the card cache — call once at startup
- JSON files are loaded by their respective `extends RefCounted` data classes

## Alternatives Considered

### Alternative 1: All data as JSON/CSV files

- **Description**: Move all data (including cards) to external JSON/CSV files
- **Pros**: Data-driven pipeline; non-programmers can edit values; diff-friendly
- **Cons**: More complex loading code; need to define schemas; harder to add new card properties
- **Estimated Effort**: 2-3 sessions to implement loader + migrate all data
- **Rejection Reason**: Over-engineering for solo dev; GDScript const data is simpler and type-safe

### Alternative 2: Godot .tres Resource files

- **Description**: Define all data as .tres Resource files in the filesystem
- **Pros**: Native Godot editor support; visual inspection; type-safe
- **Cons**: 100+ .tres files to manage; harder to batch-edit; no programmatic generation
- **Estimated Effort**: 3-5 sessions to create and wire all resources
- **Rejection Reason**: File management overhead; const data is more compact for 68+ cards

### Alternative 3: SQLite database

- **Description**: Embed SQLite for all game data
- **Pros**: Query power; relational data; easy filtering
- **Cons**: Overkill for static lookup; adds dependency; more complex save interaction
- **Estimated Effort**: 2-3 sessions
- **Rejection Reason**: Static data doesn't need queries; lookup by ID is sufficient

## Consequences

### Positive

- Zero load-time overhead for core game data (const values compiled into bytecode)
- Type-safe access through GDScript static methods with IDE auto-completion
- JSON for enemy data enables rapid balancing without code changes
- Static cache avoids redundant object creation

### Negative

- Adding new cards requires editing GDScript code (not designer-friendly)
- `DefaultCards.create_all()` is a ~200+ line factory method mixing data with code
- All static data lives in memory at all times (acceptable at current scale)
- No validation schema for JSON data files

### Neutral

- Two data formats (GDScript const + JSON) create slight inconsistency
- Static data is immutable — runtime modifications create new Resource objects

## Risks

| Risk | Probability | Impact | Mitigation |
|------|------------|--------|-----------|
| DefaultCards.gd grows too large (> 1000 lines) | Medium | Medium | Split into per-card-type files (platforms.gd, weapons.gd, etc.) |
| JSON schema drift (invalid data) | Medium | High | Add validation in JSON loader; document schema in data/README |
| Memory pressure from all static data | Low | Low | Monitor memory usage; lazy-load non-essential data if needed |
| Const data prevents mod support | Low | Low | Not a current requirement; can migrate to JSON later if needed |

## Performance Implications

| Metric | Before | Expected After | Budget |
|--------|--------|---------------|--------|
| CPU (frame time) | N/A | ~0.01ms per card lookup (cached) | 16.6ms |
| Memory | ~5MB (static data) | ~10MB (all data + caches) | 512MB |
| Load Time | ~0.5s (preload all) | ~0.5s (no async loading needed) | 3s |

## Migration Plan

No migration needed — current architecture reverse-documented from implementation.

**Rollback plan**: N/A (foundational architecture)

## Validation Criteria

- [ ] All 68+ cards accessible via `DefaultCards.get_card_by_id()` in < 0.1ms
- [ ] Enemy JSON data loads correctly from `data/json/`
- [ ] Runtime Resource creation does not modify static definitions
- [ ] Total static data memory < 20MB

## GDD Requirements Addressed

Foundational — no GDD requirement. Enables:
- `design/gdd/battle-system.md` — Enemy archetype data, unit stats, level config
- `design/gdd/blueprint-system.md` — Card definitions, star config, affix pools
- `design/gdd/phase-law-system.md` — Law definitions, family data
- `design/gdd/energy-system.md` — Energy card definitions
- `design/gdd/drop-system.md` — Drop table definitions, era-specific pools
- `design/gdd/unit-stats-system.md` — Unit stats composition from card data
- `design/gdd/synthesis-system.md` — Card lookup for synthesis validation

## Related

- `data/default_cards.gd` (primary card data)
- `data/json/enemy_archetypes.json` (enemy data example)
- `resources/card_resource.gd`, `resources/unit_stats.gd` (runtime Resource types)
- ADR-0001: Autoload Singleton Architecture (managers access data via preload)
- ADR-0005: Phase Instrument Loadout (uses phase_instruments.gd static data)
