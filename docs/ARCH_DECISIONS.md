# Architecture Decisions — Phase War

> **Locked**: 2026-05-18 (v3, 12 decisions)  
> **Status**: Active backlog reference

---

## ADR-001: Card progression data model (Scheme A)

**Context**: “蓝图/碎片”已从设计移除，但运行时仍用 `BlueprintManager.blueprint_copies` 作制造门槛，且 `law:` 前缀条目充当法则碎片。

**Decision**:

| Layer | Responsibility |
|--------|----------------|
| **Account progress** (`BlueprintManager` → future `CardDataManager`) | Per `card_id`: star 1–9, mods, evolution inherit, rank cache, `unlocked_blueprint_ids` |
| **Backpack instances** (`DropManager` / `BackpackData`) | Dropped/manufactured `CardResource` clones (star, rarity, affixes) |
| **Research points** (`BasicResourceManager`) | Star upgrade + modification costs only |
| **Knowledge** (`PhaseLawManager`) | Sole gate for law research/unlock |

**Removed / deprecated**:

- Separate “fragment” currency and `shard_req` on laws
- Manufacture requiring `blueprint_copies >= 1` (unlock flag only)
- `LawShardManager` as gameplay authority (compat shim only until references cleared)

**Save migration** (v3):

- `law:*` copies → grant knowledge by family (`5` per copy, min threshold from old `shard_req` if present)
- Unit `blueprint_copies` → optional backpack grants via `CardDropGrants` (one 1★ instance per copy above 0); stars kept on account record
- Existing `fragments` → `blueprint_copies` migration unchanged

**Consequences**: UI must not show “碎片进度” for stars; law panel shows four knowledge bars only.

---

## ADR-002: Law unlock — knowledge only

- `can_research_law`: all `research_req` knowledge thresholds must be met (AND).
- `research_law`: `try_consume_knowledge` for those costs, then append `unlocked_law_ids`.
- Battle: enemy kills grant knowledge by law **family** (no `law:` blueprint copies).

---

## ADR-003: Rank display — 13 levels

- `RankRules.RANK_ORDER`: 13 IDs (士 3 / 尉 3 / 校 3 / 将 3 / 元帅 1).
- UI bar already uses `RANK_LEVEL_MAX = 13`; power thresholds rescale for 13 tiers.
- Legacy 7-rank IDs map via `LEGACY_RANK_TO_LEVEL`.

---

## ADR-004: Systems already implemented (verify, don’t re-build)

| Feature | Location | Note |
|---------|----------|------|
| Energy regen ×5 when ≥4 energy slots | `energy_manager.gd` | Document in `energy-system.md` |
| Star upgrade via research points only | `blueprint_manager.gd`, `blueprint_star_config.gd` | Remove leftover “碎片” UI copy |
| Enhancement success 95%→40% | `card_enhancement_manager.gd` | Reverse-doc only |
| Card drop → backpack first | `card_drop_grants.gd` | Remove blueprint-copy fallback where safe |

---

## ADR-005: Removed modes / types

- Tower climb: delete `scenes/tower/`, `tower_climb_manager.gd` (orphan, not autoload).
- Synthesis: UI entry removed; `CardType.COMBINED` deprecated.
- `CardType` PLATFORM/WEAPON → `COMBAT_UNIT` (cleanup ongoing).

---

## ADR-006: Autoload layout

**16 core autoloads** in `project.godot` + **ManagerLazyLoader** for the rest.  
`systems-index.md` must not list managers that only exist in lazy config unless marked “lazy”.

---

## Phase 3 effort estimate (blueprint/fragment removal)

| Scope | Days |
|-------|------|
| CardDataManager rename + copy gate removal + save migration | 2–3 |
| Drop tables / `drops_inventory` / quest-achievement-daily cleanup | 1–2 |
| Law knowledge path + panel + battle grants | 1 |
| Challenge/faction shop fragment SKUs | 0.5 |
| grep acceptance + smoke tests | 0.5 |
| **Total** | **5–7** |

Parallel work (faction 5d, F01–F08) not included.

---

## Changelog

| Date | Change |
|------|--------|
| 2026-05-18 | Initial v3 ADR set from design lock + code review |
