# Knowledge Value System

> **Status**: Implemented (v3)
> **Source**: `managers/phase_law_manager.gd`
> **Last Updated**: 2026-05-18
> **Implements Pillar**: Phase Law Progression

## Overview

Four account-wide knowledge stats gate **all** phase law research. Law shards and `shard_req` are removed.

| Key | Family |
|-----|--------|
| `defense_knowledge` | STEEL |
| `energy_knowledge` | FLAME |
| `mobility_knowledge` | THUNDER |
| `mystic_knowledge` | VOID |

## Player Fantasy

Study the battlefield: kills and missions feed the knowledge type matching each law family until thresholds allow research.

## Detailed Rules

1. `can_research_law(id)` — every key in `research_req` must be ≥ required amount (AND).
2. `research_law(id)` — `try_consume_knowledge(research_req)` then append `unlocked_law_ids`.
3. Battle kills: `_roll_law_knowledge_drops` grants 3/5/8 base by tier to the matching family key.
4. Legacy `law:` blueprint copies migrate to knowledge on save load (5 per copy).

## Dependencies

- `data/phase_laws.gd` (`research_req` only)
- `PhaseLawManager` autoload
- `phase_law_panel.gd` (progress labels)

## Acceptance Criteria

- [x] No `shard_req` in law data
- [x] Research deducts knowledge
- [x] Battle result summary shows knowledge gain total
